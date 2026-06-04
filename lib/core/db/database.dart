import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'enums.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Merchants, Receipts, LineItems, Warranties])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          // v2: tabela garancija (warranties).
          if (from < 2) {
            await m.createTable(warranties);
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_warranties_expiry ON warranties(expiry_date)');
          }
        },
      );

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
  }
}

LazyDatabase _openEncrypted(String key) {
  return LazyDatabase(() async {
    // Na Androidu treba ranija inicijalizacija da bi se učitao SQLCipher.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'troskovnik.db.enc'));

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
