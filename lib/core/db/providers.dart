import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'db_key.dart';

/// Bezbedno skladište ključa za enkripciju baze.
final dbKeyManagerProvider = Provider<DbKeyManager>((ref) => DbKeyManager());

/// Enkriptovana Drift baza. Otvara se asinhrono (čeka ključ iz secure storage).
///
/// Koristi se preko `ref.watch(appDatabaseProvider.future)` ili
/// `ref.watch(appDatabaseProvider).valueOrNull`.
///
/// Ako baza postoji a ključa nema, [DbKeyManager.keyForDatabase] baca
/// [DbKeyMissingException] umesto da napravi nov ključ; `DatabaseGate` tu
/// grešku prikazuje kao ekran za oporavak.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final keyManager = ref.watch(dbKeyManagerProvider);
  final file = await encryptedDbFile();
  final key =
      await keyManager.keyForDatabase(databaseExists: file.existsSync());
  final db = AppDatabase.encrypted(key);
  ref.onDispose(db.close);
  return db;
});
