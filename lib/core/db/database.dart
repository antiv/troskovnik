import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' show Database, SqliteException;

import '../domain/buyer_identity.dart';
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
  Companies,
  CanonicalItems,
  ItemAliases,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  bool _dictionarySeeded = false;
  Future<void>? _normalizationLock;

  /// Trenutna verzija šeme (vidi [schemaVersion]).
  static const int currentSchemaVersion = 10;

  /// Otvara enkriptovanu bazu sa datim ključem (iz secure storage).
  ///
  /// [allowMigration] = false za pozadinski izolat (WorkManager): ako baza još
  /// nije na [currentSchemaVersion], otvaranje baca
  /// [DatabaseMigrationPendingException] umesto da migrira — migraciju radi
  /// isključivo aplikacija, pa se dva izolata nikad ne sudare u njoj.
  factory AppDatabase.encrypted(String encryptionKey,
          {bool allowMigration = true}) =>
      AppDatabase(
          _openEncrypted(encryptionKey, allowMigration: allowMigration));

  /// In-memory baza za testove, sa uključenim FK kaskadama (#7).
  factory AppDatabase.forTesting() => AppDatabase(
        NativeDatabase.memory(
          setup: (db) => db.execute('PRAGMA foreign_keys = ON;'),
        ),
      );

  @override
  int get schemaVersion => currentSchemaVersion;

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
          // v9 je postojao u DVE varijante (dve grane su paralelno uzele isti
          // broj): (a) normalizacija artikala — canonical_items/item_aliases,
          // (b) firme kupca — companies/buyer_tax_id. Baza na v9 ima samo
          // jednu od njih, pa v10 idempotentno dodaje SVE što fali iz obe.
          // Svi koraci su bezbedni za ponavljanje (IF NOT EXISTS / PRAGMA
          // table_info), pa i prekinuta migracija može ponovo da se izvrši.
          if (from < 10) {
            // (a) Kanonski artikli i keš alijasa za normalizaciju stavki.
            // Samo brze DDL naredbe: punjenje rečnika i normalizacija
            // postojećih stavki izvršavaju se lenjo pri prvom čitanju/upisu,
            // da konkurentni izolati (WorkManager) ne čekaju na migraciju.
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

            // (b) Firme kupca (analitika po PIB-u). Postojećim računima se
            // popunjava buyer_tax_id; is_business se NE dira (ručni izbor).
            await _addColumnIfMissing('receipts', 'buyer_tax_id', 'TEXT');
            await m.createTable(companies);
            await _backfillBuyerTaxIds();
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

  /// Popuni `buyer_tax_id` i tabelu firmi iz postojećih `buyer_id` (v10).
  /// Sirov SQL da migracija ne zavisi od budućih kolona tabele `receipts`.
  /// Idempotentno: dira samo račune kojima buyer_tax_id još nije popunjen.
  Future<void> _backfillBuyerTaxIds() async {
    final rows = await customSelect(
            'SELECT id, buyer_id, country FROM receipts '
            'WHERE buyer_id IS NOT NULL AND buyer_tax_id IS NULL')
        .get();
    for (final row in rows) {
      final countryIdx = row.read<int>('country');
      if (countryIdx < 0 || countryIdx >= Country.values.length) continue;
      final country = Country.values[countryIdx];
      final taxId =
          BuyerIdentity.parse(row.read<String>('buyer_id'), country)?.taxId;
      if (taxId == null) continue;
      await customStatement(
          'UPDATE receipts SET buyer_tax_id = ? WHERE id = ?',
          [taxId, row.read<int>('id')]);
      await customStatement(
          'INSERT OR IGNORE INTO companies (country, tax_id) VALUES (?, ?)',
          [country.index, taxId]);
    }
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

/// Baza još nije migrirana na [AppDatabase.currentSchemaVersion], a konekcija
/// je otvorena bez prava na migraciju (pozadinski izolat).
class DatabaseMigrationPendingException implements Exception {
  const DatabaseMigrationPendingException();

  @override
  String toString() => 'DatabaseMigrationPendingException: database schema is '
      'older than ${AppDatabase.currentSchemaVersion}; migration is left to '
      'the app';
}

/// Da li je greška [DatabaseMigrationPendingException] (i kad stigne umotana
/// sa izolata baze, npr. kao DriftRemoteException — tada ostaje samo tekst).
bool isMigrationPendingError(Object error) =>
    error is DatabaseMigrationPendingException ||
    error.toString().contains('DatabaseMigrationPendingException');

/// `setup` korak za konekciju bez prava na migraciju: baci ako je šema
/// starija od trenutne (0 = baza još nije ni napravljena).
void throwIfMigrationPending(Database db) {
  final version = db.select('PRAGMA user_version').first.values.first as int;
  if (version < AppDatabase.currentSchemaVersion) {
    throw const DatabaseMigrationPendingException();
  }
}

/// Prolazna greška pri otvaranju: drugi izolat istovremeno migrira istu bazu
/// (zaključana baza ili kolonu je upravo dodao drugi izolat). Ponovni pokušaj
/// je bezbedan jer su koraci migracije idempotentni.
bool isTransientOpenError(Object error) {
  if (error is SqliteException) {
    return error.resultCode == 5 || // SQLITE_BUSY
        error.resultCode == 6 || // SQLITE_LOCKED
        error.message.contains('duplicate column name');
  }
  final text = error.toString();
  return text.contains('SqliteException(5)') ||
      text.contains('SqliteException(6)') ||
      text.contains('database is locked') ||
      text.contains('duplicate column name');
}

/// Da li pozadinski krug treba tiho preskočiti: baza čeka migraciju (radi je
/// aplikacija) ili ju je drugi izolat baš tada zaključao (npr. prvi prelazak
/// na WAL ili migracija u toku). Sledeći periodični krug pokušava ponovo.
bool shouldSkipBackgroundRun(Object error) =>
    isMigrationPendingError(error) || isTransientOpenError(error);

/// Otvori bazu (i odradi migraciju) odmah, uz do [attempts] pokušaja kad
/// otvaranje padne zbog [isTransientOpenError].
///
/// Za svaku drugu grešku (i kad se pokušaji potroše) vraća novu, još
/// neotvorenu instancu — greška se tada pojavi na prvom upitu, isto kao bez
/// ovog omotača, pa se ponašanje `DatabaseGate`-a ne menja.
Future<AppDatabase> openAppDatabaseWithRetry(
  AppDatabase Function() open, {
  int attempts = 3,
  Duration delay = const Duration(milliseconds: 300),
}) async {
  for (var attempt = 1;; attempt++) {
    final db = open();
    try {
      await db.customSelect('SELECT 1').get();
      return db;
    } catch (e) {
      try {
        await db.close();
      } catch (_) {
        // Neuspelo otvaranje — nema šta da se zatvori.
      }
      if (!isTransientOpenError(e) || attempt >= attempts) return open();
      await Future<void>.delayed(delay * attempt);
    }
  }
}

LazyDatabase _openEncrypted(String key, {bool allowMigration = true}) {
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
        // Pozadinski izolat ne migrira — prepušta to aplikaciji.
        if (!allowMigration) throwIfMigrationPending(db);
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
