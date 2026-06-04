import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/features/receipts/data/receipt_repository.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';
import 'package:troskovnik/features/warranties/data/warranty_notifier.dart';
import 'package:troskovnik/features/warranties/data/warranty_repository.dart';

class _FakeNotifier implements WarrantyNotifier {
  final scheduled = <int>[];
  final cancelled = <int>[];
  @override
  Future<void> scheduleReminders({
    required int warrantyId,
    required String title,
    required DateTime expiryDate,
    DateTime? now,
  }) async =>
      scheduled.add(warrantyId);
  @override
  Future<void> cancelReminders(int warrantyId) async =>
      cancelled.add(warrantyId);
}

void main() {
  late AppDatabase db;
  late WarrantyRepository repo;
  late ReceiptRepository receipts;
  late _FakeNotifier notifier;
  late int receiptId;
  late int itemId;

  setUp(() async {
    db = AppDatabase.forTesting();
    notifier = _FakeNotifier();
    repo = WarrantyRepository(db, notifier);
    receipts = ReceiptRepository(db);

    final saved = await receipts.saveParsed(
      verificationUrl: 'https://suf.purs.gov.rs/v/?vl=A',
      token: 'A',
      parsed: const ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: ReceiptHeader(
            merchantName: 'TehnoMaxi',
            merchantTin: '1',
            invoiceNumber: 'I',
            pfrNumber: 'P',
            totalAmount: 5000000),
        items: [
          ParsedLineItem(
              name: 'TV',
              quantity: 1,
              unitPrice: 5000000,
              total: 5000000,
              source: ItemsSource.journal),
        ],
      ),
    );
    receiptId = saved.receiptId;
    itemId = (await db.select(db.lineItems).getSingle()).id;
  });
  tearDown(() => db.close());

  Future<int> count() async => (await db.select(db.warranties).get()).length;

  test('#1 saving twice for same item updates, does not duplicate', () async {
    final id1 = await repo.save(
      receiptId: receiptId,
      lineItemId: itemId,
      title: 'TV',
      purchaseDate: DateTime(2026, 1, 1),
    );
    final id2 = await repo.save(
      receiptId: receiptId,
      lineItemId: itemId,
      title: 'TV (izmenjeno)',
      purchaseDate: DateTime(2026, 1, 1),
      durationMonths: 36,
    );
    expect(id2, id1);
    expect(await count(), 1);
    final row = await repo.findById(id1);
    expect(row!.title, 'TV (izmenjeno)');
    expect(row.durationMonths, 36);
  });

  test('#1 only one whole-receipt warranty (lineItem null)', () async {
    await repo.save(
        receiptId: receiptId,
        title: 'Ceo račun',
        purchaseDate: DateTime(2026, 1, 1));
    await repo.save(
        receiptId: receiptId,
        title: 'Ceo račun opet',
        purchaseDate: DateTime(2026, 1, 1));
    expect(await count(), 1);
  });

  test('#1 item and whole-receipt are distinct', () async {
    await repo.save(
        receiptId: receiptId,
        lineItemId: itemId,
        title: 'Stavka',
        purchaseDate: DateTime(2026, 1, 1));
    await repo.save(
        receiptId: receiptId,
        title: 'Ceo račun',
        purchaseDate: DateTime(2026, 1, 1));
    expect(await count(), 2);
  });

  test('#4 edit by id updates and re-schedules reminder', () async {
    final id = await repo.save(
      receiptId: receiptId,
      lineItemId: itemId,
      title: 'TV',
      purchaseDate: DateTime(2026, 1, 1),
    );
    notifier.scheduled.clear();
    await repo.save(
      id: id,
      receiptId: receiptId,
      lineItemId: itemId,
      title: 'TV novo',
      purchaseDate: DateTime(2026, 1, 1),
      durationMonths: 12,
    );
    expect(await count(), 1);
    expect((await repo.findById(id))!.title, 'TV novo');
    expect(notifier.scheduled, contains(id)); // re-zakazано
  });

  test('#7 deleting receipt cascades warranties + items and reports ids',
      () async {
    final wId = await repo.save(
      receiptId: receiptId,
      lineItemId: itemId,
      title: 'TV',
      purchaseDate: DateTime(2026, 1, 1),
    );
    final deletedWarrantyIds = await receipts.delete(receiptId);

    expect(deletedWarrantyIds, contains(wId));
    expect(await count(), 0); // garancije kaskadno obrisane
    expect(await db.select(db.lineItems).get(), isEmpty); // stavke obrisane
    expect(await receipts.findById(receiptId), isNull);
  });
}
