import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Baza postoji na disku, ali ključa kojim je šifrovana više nema u secure
/// storage-u — podaci se ne mogu dešifrovati.
///
/// Dešava se posle prenosa na novi uređaj ili vraćanja iz sistemske rezervne
/// kopije: fajl baze se vrati, a ključ iz Android Keystore-a / iOS Keychain-a
/// ne. Ranije je kod u tom slučaju tiho pravio nov ključ, čime je baza trajno
/// postajala nečitljiva (`SqliteException(26)`, „file is not a database").
class DbKeyMissingException implements Exception {
  const DbKeyMissingException();

  @override
  String toString() =>
      'DbKeyMissingException: database file exists but its encryption key is '
      'not in secure storage';
}

/// Upravlja ključem za SQLCipher enkripciju baze.
///
/// Ključ se generiše jednom (256-bitni, base64) i čuva u platformskom
/// bezbednom skladištu (Keychain / Android Keystore-backed). Nikad ne ide u
/// bazu niti u logove.
class DbKeyManager {
  DbKeyManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'troskovnik_db_key_v1';

  final FlutterSecureStorage _storage;

  /// Vrati postojeći ključ ili `null` ako ga nema. Nikad ne pravi novi.
  Future<String?> readKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing == null || existing.isEmpty) return null;
    return existing;
  }

  /// Ključ za otvaranje baze.
  ///
  /// Nov ključ se pravi ISKLJUČIVO kad baze još nema ([databaseExists] je
  /// `false`). Ako baza postoji a ključa nema, baca [DbKeyMissingException] —
  /// stanje je nepovratno i mora ga rešiti korisnik (brisanjem podataka), a ne
  /// tihi nov ključ koji bi postojeću bazu zaključao zauvek.
  Future<String> keyForDatabase({required bool databaseExists}) async {
    final existing = await readKey();
    if (existing != null) return existing;
    if (databaseExists) throw const DbKeyMissingException();
    return _createKey();
  }

  /// Obriši ključ — deo oporavka kad se baza više ne može otvoriti.
  Future<void> deleteKey() => _storage.delete(key: _keyName);

  Future<String> _createKey() async {
    final key = _generateKey();
    await _storage.write(key: _keyName, value: key);
    // Na Androidu upis ide preko SharedPreferences.apply() (asinhrono, bez
    // fsync-a). Pročitaj nazad pre nego što se ključem napravi baza: bolje je
    // pasti sada nego napraviti bazu ključem koji nije sačuvan.
    if (await readKey() != key) {
      throw StateError('Database encryption key could not be persisted');
    }
    return key;
  }

  static String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
