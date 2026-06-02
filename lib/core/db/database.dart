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

@DriftDatabase(tables: [Merchants, Receipts, LineItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Otvara enkriptovanu bazu sa datim ključem (iz secure storage).
  factory AppDatabase.encrypted(String encryptionKey) =>
      AppDatabase(_openEncrypted(encryptionKey));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Indeksi za pretragu i sortiranje (instrukcije.md, sekcija 4).
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_merchants_name ON merchants(name)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_line_items_name ON line_items(name)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_receipts_pfr_time ON receipts(pfr_time)');
        },
      );
}

LazyDatabase _openEncrypted(String key) {
  return LazyDatabase(() async {
    // Na Androidu treba ranija inicijalizacija da bi se učitao SQLCipher.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    }
    // Osiguraj da se koristi SQLCipher build (ne sistemski sqlite).
    open.overrideForAll(openCipherOnAndroid);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'troskovnik.db.enc'));

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Postavi ključ pre bilo kakvog pristupa.
        final escaped = key.replaceAll("'", "''");
        db.execute("PRAGMA key = '$escaped';");
        // Provera da je ključ ispravan / baza dešifrovana.
        db.execute('PRAGMA cipher_memory_security = ON;');
        db.execute('SELECT count(*) FROM sqlite_master;');
      },
    );
  });
}
