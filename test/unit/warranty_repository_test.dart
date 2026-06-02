import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/features/receipts/data/receipt_repository.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';
import 'package:troskovnik/features/warranties/data/warranty_notifier.dart';
import 'package:troskovnik/features/warranties/data/warranty_repository.dart';

/// Beleži pozive umesto pravih notifikacija.
class _FakeNotifier implements WarrantyNotifier {
  final scheduled = <int>[];
  final cancelled = <int>[];
  DateTime? lastExpiry;

  @override
  Future<void> scheduleReminders({
    required int warrantyId,
    required String title,
    required DateTime expiryDate,
    DateTime? now,
  }) async {
    scheduled.add(warrantyId);
    lastExpiry = expiryDate;
  }

  @override
  Future<void> cancelReminders(int warrantyId) async =>
      cancelled.add(warrantyId);
}

void main() {
  late AppDatabase db;
  late WarrantyRepository repo;
  late _FakeNotifier notifier;
  late int receiptId;
  late int lineItemId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    notifier = _FakeNotifier();
    repo = WarrantyRepository(db, notifier);

    final rr = ReceiptRepository(db);
    final saved = await rr.saveParsed(
      verificationUrl: 'https://suf.purs.gov.rs/v/?vl=A',
      token: 'A',
      parsed: const ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: ReceiptHeader(
            merchantName: 'TehnoMaxi',
            merchantTin: '111',
            invoiceNumber: 'I1',
            pfrNumber: 'P1',
            totalAmount: 5000000),
        items: [
          ParsedLineItem(
              name: 'Televizor',
              quantity: 1,
              unitPrice: 5000000,
              total: 5000000,
              source: ItemsSource.journal),
        ],
      ),
    );
    receiptId = saved.receiptId;
    lineItemId = (await db.select(db.lineItems).getSingle()).id;
  });
  tearDown(() => db.close());

  test('create computes expiry, schedules reminder', () async {
    final id = await repo.create(
      receiptId: receiptId,
      lineItemId: lineItemId,
      title: 'Televizor',
      purchaseDate: DateTime(2026, 6, 2),
    );
    final row = await repo.findById(id);
    expect(row, isNotNull);
    expect(row!.durationMonths, 24);
    expect(row.expiryDate, DateTime(2028, 6, 2));
    expect(notifier.scheduled, contains(id));
    expect(notifier.lastExpiry, DateTime(2028, 6, 2));
  });

  test('custom duration respected', () async {
    final id = await repo.create(
      receiptId: receiptId,
      title: 'Obuća (ceo račun)',
      purchaseDate: DateTime(2026, 6, 2),
      durationMonths: 6,
    );
    final row = await repo.findById(id);
    expect(row!.expiryDate, DateTime(2026, 12, 2));
  });

  test('warranty without lineItem is receipt-level', () async {
    final id = await repo.create(
      receiptId: receiptId,
      title: 'Ceo račun',
      purchaseDate: DateTime(2026, 6, 2),
    );
    final row = await repo.findById(id);
    expect(row!.lineItemId, isNull);
  });

  test('delete cancels reminders and removes row', () async {
    final id = await repo.create(
      receiptId: receiptId,
      title: 'X',
      purchaseDate: DateTime(2026, 6, 2),
    );
    await repo.delete(id);
    expect(notifier.cancelled, contains(id));
    expect(await repo.findById(id), isNull);
  });

  test('watchAll joins merchant + item and sorts by expiry', () async {
    await repo.create(
        receiptId: receiptId,
        title: 'Pozno',
        purchaseDate: DateTime(2026, 6, 2),
        durationMonths: 36);
    await repo.create(
        receiptId: receiptId,
        lineItemId: lineItemId,
        title: 'Rano',
        purchaseDate: DateTime(2026, 6, 2),
        durationMonths: 6);

    final list = await repo.watchAll().first;
    expect(list, hasLength(2));
    // Sortirano po isteku: "Rano" (6m) pre "Pozno" (36m).
    expect(list.first.warranty.title, 'Rano');
    expect(list.first.merchantName, 'TehnoMaxi');
    expect(list.first.lineItemName, 'Televizor');
    expect(list.last.lineItemName, isNull);
  });

  group('ReminderSchedule.compute', () {
    test('schedules 30d and 7d before, future only', () {
      final expiry = DateTime(2026, 12, 1);
      final s = ReminderSchedule.compute(expiry, now: DateTime(2026, 1, 1));
      expect(s.map((e) => e.daysBefore), [30, 7]);
      expect(s.first.fireAt, DateTime(2026, 11, 1));
    });

    test('drops reminders already in the past', () {
      final expiry = DateTime(2026, 12, 1);
      // 20 dana pre isteka: 30d termin je prošao, 7d je budući.
      final s = ReminderSchedule.compute(expiry, now: DateTime(2026, 11, 11));
      expect(s.map((e) => e.daysBefore), [7]);
    });

    test('empty when expiry too close', () {
      final expiry = DateTime(2026, 12, 1);
      final s = ReminderSchedule.compute(expiry, now: DateTime(2026, 11, 30));
      expect(s, isEmpty);
    });
  });

  test('notification id is deterministic and distinct per offset', () {
    expect(warrantyNotificationId(5, 30), warrantyNotificationId(5, 30));
    expect(warrantyNotificationId(5, 30),
        isNot(warrantyNotificationId(5, 7)));
    expect(warrantyNotificationId(5, 30),
        isNot(warrantyNotificationId(6, 30)));
  });
}
