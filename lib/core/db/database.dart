import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import '../domain/country.dart';
import '../domain/currency.dart';
import '../normalization/seed_items_data.dart';
import 'enums.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Merchants,
  Receipts,
  LineItems,
  Warranties,
  Categories,
  CanonicalItems,
  ItemAliases,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  bool _dictionarySeeded = false;
  Future<void>? _normalizationLock;

  /// Otvara enkriptovanu bazu sa datim ključem (iz secure storage).
  factory AppDatabase.encrypted(String encryptionKey) =>
      AppDatabase(_openEncrypted(encryptionKey));

  /// In-memory baza za testove, sa uključenim FK kaskadama (#7).
  factory AppDatabase.forTesting() => AppDatabase(
        NativeDatabase.memory(
          setup: (db) => db.execute('PRAGMA foreign_keys = ON;'),
        ),
      );

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
          await _seedDefaultCategories();
          await _seedCanonicalDictionary();
          _dictionarySeeded = true;
        },
        onUpgrade: (m, from, to) async {
          // v2: tabela garancija (warranties).
          if (from < 2) {
            await m.createTable(warranties);
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_warranties_expiry ON warranties(expiry_date)');
          }
          // v3: PIB/ID kupca na računu (auto-„poslovni").
          if (from < 3) {
            await _addColumnIfMissing('receipts', 'buyer_id', 'TEXT');
          }
          // v4: strukturirani načini plaćanja sa iznosima (kombinovano).
          if (from < 4) {
            await _addColumnIfMissing('receipts', 'payments_json', 'TEXT');
          }
          // v5: kategorije stavki.
          if (from < 5) {
            await m.createTable(categories);
            await _seedDefaultCategories();
          }
          // v6: ručni unos troška (isManual flag).
          if (from < 6) {
            await _addColumnIfMissing(
                'receipts', 'is_manual', 'INTEGER NOT NULL DEFAULT 0');
          }
          // v7: zemlja i valuta po računu (Republika Srpska / BAM).
          // DEFAULT 0 = Country.serbia / Currency.rsd (index 0).
          if (from < 7) {
            await _addColumnIfMissing(
                'receipts', 'country', 'INTEGER NOT NULL DEFAULT 0');
            await _addColumnIfMissing(
                'receipts', 'currency', 'INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                "UPDATE receipts SET country = 1, currency = 1 WHERE verification_url LIKE '%poreskaupravars.org%'");
            await customStatement(
                "UPDATE receipts SET country = 2, currency = 2 WHERE verification_url LIKE '%tax.gov.me%'");
          }
          // v8: flag za nepodudaranje parsiranih podataka sa invoiceResult.
          if (from < 8) {
            await _addColumnIfMissing(
                'receipts', 'has_discrepancy', 'INTEGER NOT NULL DEFAULT 0');
          }
          // v9: kanonski artikli i keš alijasa za normalizaciju stavki u analitici.
          // U onUpgrade izvršavamo isključivo brze i idempotentne DDL naredbe (< 2 ms)
          // kako konkurentni izolati (npr. WorkManager) nikada ne bi čekali ili
          // zaključali bazu tokom migracije. Punjenje rečnika i normalizacija
          // postojećih stavki izvršavaju se lenjo pri prvom čitanju/upisu.
          if (from < 9) {
            await m.createTable(canonicalItems);
            await m.createTable(itemAliases);
            await _addColumnIfMissing(
              'line_items',
              'canonical_item_id',
              'INTEGER REFERENCES canonical_items(id) ON DELETE SET NULL',
            );
            await _addColumnIfMissing(
              'line_items',
              'extracted_measure',
              'TEXT',
            );
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_item_aliases_cleaned ON item_aliases(cleaned_raw_name)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_line_items_canonical ON line_items(canonical_item_id)');
          }
        },
      );

  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String definition,
  ) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    final exists = rows.any((r) => r.read<String>('name') == column);
    if (!exists) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  /// Serijalizuje operacije punjenja rečnika i normalizacije nad istom
  /// [AppDatabase] instancom kako se ne bi izvršavale paralelno.
  Future<T> runSerializedNormalization<T>(Future<T> Function() action) async {
    while (_normalizationLock != null) {
      try {
        await _normalizationLock;
      } catch (_) {}
    }
    final completer = Completer<void>();
    _normalizationLock = completer.future;
    try {
      return await action();
    } finally {
      _normalizationLock = null;
      completer.complete();
    }
  }

  /// Osigurava da je početni (seed) rečnik kanonskih artikala učitan u bazu.
  Future<void> ensureCanonicalDictionarySeeded() async {
    if (_dictionarySeeded) return;
    final existing = await customSelect(
      'SELECT 1 FROM item_aliases WHERE is_user_merged = 0 LIMIT 1',
    ).getSingleOrNull();
    if (existing == null) {
      await _seedCanonicalDictionary();
    }
    _dictionarySeeded = true;
  }

  Future<void> _createIndexes() async {
    // Indeksi za pretragu i sortiranje (instrukcije.md, sekcija 4).
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_merchants_name ON merchants(name)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_line_items_name ON line_items(name)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_receipts_pfr_time ON receipts(pfr_time)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_warranties_expiry ON warranties(expiry_date)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_item_aliases_cleaned ON item_aliases(cleaned_raw_name)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_line_items_canonical ON line_items(canonical_item_id)');
  }

  Future<void> _seedCanonicalDictionary() async {
    final entries = await SeedItemsLoader.load();
    if (entries.isEmpty) return;

    final prepared = <({String key, String displayName, Set<String> aliases})>[];
    for (final entry in entries) {
      final canonicalKey = entry.canonicalKey.trim();
      if (canonicalKey.isEmpty) continue;
      final aliasKeys = <String>{
        canonicalKey,
        for (final a in entry.aliases)
          if (a.trim().isNotEmpty) a.trim(),
      };
      prepared.add((
        key: canonicalKey,
        displayName: entry.displayName,
        aliases: aliasKeys,
      ));
    }

    await batch((b) {
      for (final p in prepared) {
        b.insert(
          canonicalItems,
          CanonicalItemsCompanion.insert(
            canonicalKey: p.key,
            displayName: p.displayName,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });

    final allCanonical = await select(canonicalItems).get();
    final idByKey = <String, int>{
      for (final row in allCanonical) row.canonicalKey: row.id,
    };

    await batch((b) {
      for (final p in prepared) {
        final cid = idByKey[p.key];
        if (cid == null) continue;
        for (final alias in p.aliases) {
          b.insert(
            itemAliases,
            ItemAliasesCompanion.insert(
              cleanedRawName: alias,
              canonicalItemId: cid,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }

  Future<void> _seedDefaultCategories() async {
    final defaults = [
      (name: 'Hrana', color: '#4CAF50', sort: 0),
      (name: 'Piće', color: '#2196F3', sort: 1),
      (name: 'Transport', color: '#FF9800', sort: 2),
      (name: 'Stanovanje', color: '#9C27B0', sort: 3),
      (name: 'Zdravlje', color: '#E91E63', sort: 4),
      (name: 'Odeća', color: '#00BCD4', sort: 5),
      (name: 'Elektronika', color: '#607D8B', sort: 6),
      (name: 'Ostalo', color: '#795548', sort: 7),
    ];
    await batch((b) {
      for (final d in defaults) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            name: d.name,
            color: Value(d.color),
            sortOrder: Value(d.sort),
            isDefault: const Value(true),
          ),
        );
      }
    });
  }
}

/// Ime fajla šifrovane baze u aplikacionom „documents" direktorijumu.
const _dbFileName = 'troskovnik.db.enc';

/// Fajl šifrovane baze. Deli ga otvaranje baze i provera da li ključ sme da se
/// generiše (`DbKeyManager.keyForDatabase`).
Future<File> encryptedDbFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, _dbFileName));
}

LazyDatabase _openEncrypted(String key) {
  return LazyDatabase(() async {
    // Na Androidu treba ranija inicijalizacija da bi se učitao SQLCipher.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    }

    final file = await encryptedDbFile();

    return NativeDatabase.createInBackground(
      file,
      // VAŽNO: baza se otvara na zasebnom izolatu, pa override mora da se
      // primeni TAMO (override sa glavnog izolata se ne propagira).
      isolateSetup: _useSqlCipher,
      setup: (db) {
        // Postavi ključ pre bilo kakvog pristupa.
        final escaped = key.replaceAll("'", "''");
        db.execute("PRAGMA key = '$escaped';");
        // Provera da je ključ ispravan / baza dešifrovana.
        db.execute('PRAGMA cipher_memory_security = ON;');
        // Sačekaj do 30s ako drugi izolat (npr. WorkManager) trenutno drži lock.
        db.execute('PRAGMA busy_timeout = 30000;');
        // WAL režim omogućava konkurentno čitanje i pisanje između izolata.
        db.execute('PRAGMA journal_mode = WAL;');
        // FK kaskade (van transakcije, ovde u setup-u — ne radi u beforeOpen).
        db.execute('PRAGMA foreign_keys = ON;');
        db.execute('SELECT count(*) FROM sqlite_master;');
      },
    );
  });
}

/// Usmeri `package:sqlite3` na SQLCipher build (libsqlcipher.so) umesto na
/// sistemski sqlite. Mora biti top-level da bi se mogao poslati izolatu.
Future<void> _useSqlCipher() async {
  if (Platform.isAndroid) {
    open.overrideForAll(openCipherOnAndroid);
  }
}
