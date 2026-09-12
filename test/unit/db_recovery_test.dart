import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart';
import 'package:troskovnik/core/db/db_key.dart';
import 'package:troskovnik/core/db/db_recovery.dart';

void main() {
  test('SQLITE_NOTADB znači nečitljiva baza', () {
    // Ista greška kao iz prijave sa Play Store-a.
    final error = SqliteException(
      26,
      'file is not a database',
      'file is not a database (code 26)',
      'SELECT count(*) FROM sqlite_master;',
      null,
      'executing',
    );

    expect(isUnreadableDatabase(error), isTrue);
    expect(error.resultCode, kSqliteNotADb);
  });

  test('nedostajući ključ znači nečitljiva baza', () {
    expect(isUnreadableDatabase(const DbKeyMissingException()), isTrue);
  });

  test('greška umotana pri prenosu iz izolata se prepoznaje po tekstu', () {
    final error = Exception(
        'DriftRemoteException: SqliteException(26): while executing, '
        'file is not a database');

    expect(isUnreadableDatabase(error), isTrue);
  });

  test('druge greške ne vode na brisanje podataka', () {
    expect(
      isUnreadableDatabase(
          SqliteException(11, 'database disk image is malformed')),
      isFalse,
    );
    expect(
      isUnreadableDatabase(SqliteException(1, 'no such table: receipts')),
      isFalse,
    );
    expect(isUnreadableDatabase(Exception('timeout')), isFalse);
  });
}
