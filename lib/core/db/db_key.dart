import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// Vrati postojeći ključ ili ga generiši i sačuvaj pri prvom pokretanju.
  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final key = _generateKey();
    await _storage.write(key: _keyName, value: key);
    return key;
  }

  static String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
