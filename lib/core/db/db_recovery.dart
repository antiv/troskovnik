import 'dart:io';

import 'package:sqlite3/common.dart';

import 'database.dart';
import 'db_key.dart';

/// SQLITE_NOTADB — prvi bajtovi fajla nisu SQLite header posle dešifrovanja
/// zadatim ključem. Kod nas znači: ključ ne odgovara bazi, ili je fajl oštećen.
const int kSqliteNotADb = 26;

/// Da li je greška pri otvaranju baze ona nepovratna: baza postoji, ali se ne
/// može dešifrovati. Samo za takve greške nudimo brisanje podataka — obična
/// greška u upitu ne sme da vodi na destruktivnu akciju.
bool isUnreadableDatabase(Object error) {
  if (error is DbKeyMissingException) return true;
  if (error is SqliteException) return error.resultCode == kSqliteNotADb;
  // Baza se otvara na zasebnom izolatu, pa greška ume da stigne umotana
  // (npr. u DriftRemoteException) — tada ostaje samo tekst.
  final text = error.toString();
  return text.contains('SqliteException($kSqliteNotADb)') ||
      text.contains('file is not a database');
}

/// Napravi ključ baze pri prvom pokretanju — u glavnom izolatu, pre nego što se
/// zakaže background task.
///
/// Bez ovoga i glavni i background izolat rade „pročitaj pa upiši" nad istim
/// ključem: ako oba vide prazno, naprave dva različita ključa, baza ostane
/// šifrovana jednim a u skladištu ostane drugi — `SqliteException(26)` zauvek.
///
/// Greške se namerno gutaju: `appDatabaseProvider` ih prikazuje kroz UI, a
/// pokretanje aplikacije ne sme da zavisi od secure storage-a.
Future<void> ensureDatabaseKey([DbKeyManager? manager]) async {
  try {
    final file = await encryptedDbFile();
    await (manager ?? DbKeyManager())
        .keyForDatabase(databaseExists: file.existsSync());
  } catch (_) {
    // Namerno prazno — vidi doc komentar.
  }
}

/// Obriši nečitljivu bazu i njen ključ, da bi sledeće otvaranje napravilo
/// praznu bazu. Podaci se ne mogu spasti — ključa nema.
Future<void> resetEncryptedDatabase(DbKeyManager manager) async {
  final file = await encryptedDbFile();
  // Prvo prateći fajlovi: ako ostanu, otvaranje nove baze bi na njih naletelo.
  for (final suffix in const ['-wal', '-shm', '-journal']) {
    final sidecar = File('${file.path}$suffix');
    if (sidecar.existsSync()) {
      try {
        await sidecar.delete();
      } catch (_) {
        // Nije fatalno — SQLite ume da radi i bez njih.
      }
    }
  }
  if (file.existsSync()) {
    // Greška ovde se propagira: bez obrisanog fajla nov ključ opet zaključava.
    await file.delete();
  }
  await manager.deleteKey();
}
