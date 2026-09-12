import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:troskovnik/core/db/db_key.dart';

class _Storage extends Mock implements FlutterSecureStorage {}

/// Storage koji se stvarno ponaša kao mapa (upiši → pročitaj → obriši).
_Storage _storageBackedBy(Map<String, String> store) {
  final storage = _Storage();
  when(() => storage.read(key: any(named: 'key')))
      .thenAnswer((i) async => store[i.namedArguments[#key] as String]);
  when(() => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      )).thenAnswer((i) async {
    store[i.namedArguments[#key] as String] =
        i.namedArguments[#value] as String;
  });
  when(() => storage.delete(key: any(named: 'key'))).thenAnswer((i) async {
    store.remove(i.namedArguments[#key] as String);
  });
  return storage;
}

void main() {
  test('prvo pokretanje (nema baze) pravi ključ i pamti ga', () async {
    final store = <String, String>{};
    final manager = DbKeyManager(storage: _storageBackedBy(store));

    final key = await manager.keyForDatabase(databaseExists: false);

    expect(key, isNotEmpty);
    expect(store.values.single, key);
    expect(await manager.readKey(), key);
  });

  test('postojeći ključ se vraća nepromenjen, i sa bazom i bez nje', () async {
    final store = <String, String>{};
    final manager = DbKeyManager(storage: _storageBackedBy(store));
    final first = await manager.keyForDatabase(databaseExists: false);

    expect(await manager.keyForDatabase(databaseExists: true), first);
    expect(await manager.keyForDatabase(databaseExists: false), first);
  });

  // Srž popravke: bez ovoga se pravio nov ključ i postojeća baza je zauvek
  // ostajala nečitljiva (SqliteException(26), „file is not a database").
  test('baza postoji a ključa nema → greška, nov ključ se NE pravi', () async {
    final store = <String, String>{};
    final manager = DbKeyManager(storage: _storageBackedBy(store));

    await expectLater(
      manager.keyForDatabase(databaseExists: true),
      throwsA(isA<DbKeyMissingException>()),
    );
    expect(store, isEmpty);
  });

  test('prazan zapis se tretira kao da ključa nema', () async {
    final store = <String, String>{'troskovnik_db_key_v1': ''};
    final manager = DbKeyManager(storage: _storageBackedBy(store));

    expect(await manager.readKey(), isNull);
    await expectLater(
      manager.keyForDatabase(databaseExists: true),
      throwsA(isA<DbKeyMissingException>()),
    );
  });

  test('ako upis ne prođe, ključ se ne vraća (baza se ne pravi)', () async {
    final storage = _Storage();
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    // Upis tiho ne sačuva ništa — kao SharedPreferences.apply() koji ne slegne.
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});

    await expectLater(
      DbKeyManager(storage: storage).keyForDatabase(databaseExists: false),
      throwsA(isA<StateError>()),
    );
  });

  test('deleteKey uklanja ključ', () async {
    final store = <String, String>{};
    final manager = DbKeyManager(storage: _storageBackedBy(store));
    await manager.keyForDatabase(databaseExists: false);

    await manager.deleteKey();

    expect(store, isEmpty);
    expect(await manager.readKey(), isNull);
  });
}
