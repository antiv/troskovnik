import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/providers.dart';
import 'package:troskovnik/features/receipts/presentation/receipt_list_controller.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);

    final m = await db.into(db.merchants).insert(
          MerchantsCompanion.insert(tin: '1', name: 'Maxi'),
        );
    Future<void> add(String inv, bool business) =>
        db.into(db.receipts).insert(ReceiptsCompanion.insert(
              merchantId: m,
              verificationUrl: 'u$inv',
              invoiceNumber: Value(inv),
              pfrNumber: Value(inv),
              pfrTime: Value(DateTime(2026, 1, 1)),
              totalAmount: const Value(1000),
              isBusiness: Value(business),
            ));
    await add('B1', true);
    await add('B2', true);
    await add('P1', false);
  });
  tearDown(() => db.close());

  Future<List<ReceiptListItem>> listFor(ReceiptKindFilter kind) async {
    container.read(receiptQueryProvider.notifier).setKind(kind);
    // Drži provider živim i sačekaj da pređe u podatke za izabrani filter.
    final sub = container.listen(receiptListProvider, (_, _) {});
    addTearDown(sub.close);
    while (true) {
      final v = container.read(receiptListProvider);
      if (v.hasValue && !v.isLoading) return v.value!;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('all shows every receipt', () async {
    expect(await listFor(ReceiptKindFilter.all), hasLength(3));
  });

  test('business filter shows only business', () async {
    final list = await listFor(ReceiptKindFilter.business);
    expect(list, hasLength(2));
    expect(list.every((i) => i.receipt.isBusiness), isTrue);
  });

  test('personal filter shows only personal', () async {
    final list = await listFor(ReceiptKindFilter.personal);
    expect(list, hasLength(1));
    expect(list.single.receipt.isBusiness, isFalse);
  });
}
