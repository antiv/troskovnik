import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/features/categories/data/category_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });
  tearDown(() => db.close());

  Future<int> receipt() async {
    final m = await db.into(db.merchants).insert(
          MerchantsCompanion.insert(
              tin: 't${DateTime.now().microsecondsSinceEpoch}', name: 'Maxi'),
        );
    return db.into(db.receipts).insert(ReceiptsCompanion.insert(
          merchantId: m,
          verificationUrl: 'u${DateTime.now().microsecondsSinceEpoch}',
          totalAmount: const Value(1000),
        ));
  }

  Future<int> item(int receiptId, String name, {int? categoryId}) =>
      db.into(db.lineItems).insert(LineItemsCompanion.insert(
            receiptId: receiptId,
            name: name,
            total: const Value(1000),
            categoryId: Value(categoryId),
          ));

  test('assignToItemsByName updates all items with that name across receipts',
      () async {
    final cat = await repo.create('Namirnice');
    final r1 = await receipt();
    final r2 = await receipt();
    final a = await item(r1, 'Mleko');
    final b = await item(r2, 'Mleko');
    final c = await item(r1, 'Hleb');

    await repo.assignToItemsByName('Mleko', cat.id);

    final rows = await db.select(db.lineItems).get();
    final byId = {for (final it in rows) it.id: it.categoryId};
    expect(byId[a], cat.id);
    expect(byId[b], cat.id);
    expect(byId[c], isNull); // drugi artikal netaknut

    // Skidanje kategorije (null) važi za sve stavke sa tim nazivom.
    await repo.assignToItemsByName('Mleko', null);
    final cleared = await db.select(db.lineItems).get();
    expect(cleared.every((it) => it.categoryId == null), isTrue);
  });

  test('assignToReceipt accepts null to clear categories', () async {
    final cat = await repo.create('Namirnice');
    final r = await receipt();
    await item(r, 'Mleko', categoryId: cat.id);

    await repo.assignToReceipt(r, null);
    final rows = await db.select(db.lineItems).get();
    expect(rows.single.categoryId, isNull);
  });
}
