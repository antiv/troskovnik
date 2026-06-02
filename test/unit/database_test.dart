import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('insert merchant + receipt + line item round-trips with enums', () async {
    final merchantId = await db.into(db.merchants).insert(
          MerchantsCompanion.insert(tin: '123456789', name: 'Maxi'),
        );

    final receiptId = await db.into(db.receipts).insert(
          ReceiptsCompanion.insert(
            merchantId: merchantId,
            verificationUrl: 'https://suf.purs.gov.rs/v/?vl=ABC',
            invoiceNumber: const Value('AB-1'),
            pfrNumber: const Value('PFR-1'),
            totalAmount: const Value(123456), // 1.234,56 RSD
            fetchStatus: const Value(FetchStatus.headerOnly),
            itemsStatus: const Value(ItemsStatus.pendingServer),
          ),
        );

    await db.into(db.lineItems).insert(
          LineItemsCompanion.insert(
            receiptId: receiptId,
            name: 'Mleko 1l',
            quantity: const Value(2.0),
            unitPrice: const Value(9900),
            total: const Value(19800),
            taxLabel: const Value('Ђ'),
            taxRate: const Value(10),
            source: const Value(ItemsSource.journal),
          ),
        );

    final receipt = await (db.select(db.receipts)
          ..where((r) => r.id.equals(receiptId)))
        .getSingle();
    expect(receipt.fetchStatus, FetchStatus.headerOnly);
    expect(receipt.itemsStatus, ItemsStatus.pendingServer);
    expect(receipt.totalAmount, 123456);

    final items = await db.select(db.lineItems).get();
    expect(items, hasLength(1));
    expect(items.first.name, 'Mleko 1l');
    expect(items.first.taxLabel, 'Ђ');
  });

  test('duplicate (invoice_number + pfr_number) is rejected', () async {
    final merchantId = await db.into(db.merchants).insert(
          MerchantsCompanion.insert(tin: '111', name: 'Idea'),
        );

    Future<void> insertReceipt() => db.into(db.receipts).insert(
          ReceiptsCompanion.insert(
            merchantId: merchantId,
            verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
            invoiceNumber: const Value('DUP-1'),
            pfrNumber: const Value('PFR-DUP'),
          ),
        );

    await insertReceipt();
    expect(
      insertReceipt,
      throwsA(predicate(
        (e) => e.toString().toLowerCase().contains('unique'),
        'is a UNIQUE constraint violation',
      )),
    );
  });
}
