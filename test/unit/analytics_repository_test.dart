import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/features/analytics/data/analytics_repository.dart';
import 'package:troskovnik/features/analytics/domain/analytics_models.dart';

void main() {
  late AppDatabase db;
  late AnalyticsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AnalyticsRepository(db);
  });
  tearDown(() => db.close());

  Future<int> merchant(String tin, String name) =>
      db.into(db.merchants).insert(
            MerchantsCompanion.insert(tin: tin, name: name),
          );

  Future<int> receipt({
    required int merchantId,
    required int total,
    required DateTime pfrTime,
    bool business = false,
    FetchStatus status = FetchStatus.complete,
    String? invoice,
    String? pfr,
  }) =>
      db.into(db.receipts).insert(
            ReceiptsCompanion.insert(
              merchantId: merchantId,
              verificationUrl: 'u${DateTime.now().microsecondsSinceEpoch}',
              invoiceNumber: Value(invoice),
              pfrNumber: Value(pfr),
              pfrTime: Value(pfrTime),
              totalAmount: Value(total),
              isBusiness: Value(business),
              fetchStatus: Value(status),
            ),
          );

  Future<void> item(int receiptId, String name, int total,
          {double? rate}) =>
      db.into(db.lineItems).insert(
            LineItemsCompanion.insert(
              receiptId: receiptId,
              name: name,
              total: Value(total),
              taxRate: Value(rate),
            ),
          );

  test('monthly groups by pfr_time month and sums totals', () async {
    final m = await merchant('1', 'Maxi');
    await receipt(merchantId: m, total: 10000, pfrTime: DateTime(2026, 1, 5));
    await receipt(merchantId: m, total: 5000, pfrTime: DateTime(2026, 1, 20));
    await receipt(merchantId: m, total: 7000, pfrTime: DateTime(2026, 2, 2));

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 3, 1));
    expect(s.monthly, hasLength(2));
    final jan = s.monthly.firstWhere((x) => x.month == 1);
    expect(jan.totalMinor, 15000);
    expect(jan.receiptCount, 2);
    final feb = s.monthly.firstWhere((x) => x.month == 2);
    expect(feb.totalMinor, 7000);
  });

  test('byMerchant aggregates and sorts desc', () async {
    final maxi = await merchant('1', 'Maxi');
    final idea = await merchant('2', 'Idea');
    await receipt(merchantId: maxi, total: 3000, pfrTime: DateTime(2026, 1, 1));
    await receipt(merchantId: idea, total: 9000, pfrTime: DateTime(2026, 1, 1));
    await receipt(merchantId: maxi, total: 2000, pfrTime: DateTime(2026, 1, 2));

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    expect(s.byMerchant.first.merchantName, 'Idea'); // 9000 najviše
    expect(s.byMerchant.first.totalMinor, 9000);
    final maxiAgg = s.byMerchant.firstWhere((x) => x.merchantName == 'Maxi');
    expect(maxiAgg.totalMinor, 5000);
    expect(maxiAgg.receiptCount, 2);
    expect(s.totalMinor, 14000);
    expect(s.receiptCount, 3);
  });

  test('business vs personal split', () async {
    final m = await merchant('1', 'Maxi');
    await receipt(
        merchantId: m, total: 8000, pfrTime: DateTime(2026, 1, 1), business: true);
    await receipt(merchantId: m, total: 2000, pfrTime: DateTime(2026, 1, 1));

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    expect(s.businessSplit.businessMinor, 8000);
    expect(s.businessSplit.personalMinor, 2000);
    expect(s.businessSplit.totalMinor, 10000);
  });

  test('top items sums by name', () async {
    final m = await merchant('1', 'Maxi');
    final r1 = await receipt(
        merchantId: m, total: 0, pfrTime: DateTime(2026, 1, 1), invoice: 'A', pfr: 'A');
    final r2 = await receipt(
        merchantId: m, total: 0, pfrTime: DateTime(2026, 1, 2), invoice: 'B', pfr: 'B');
    await item(r1, 'Mleko', 12000);
    await item(r2, 'Mleko', 6000);
    await item(r1, 'Hleb', 5000);

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    final mleko = s.topItems.firstWhere((x) => x.name == 'Mleko');
    expect(mleko.totalMinor, 18000);
    expect(mleko.count, 2);
    expect(s.topItems.first.name, 'Mleko'); // najveći zbir
  });

  test('estimated VAT from item rates', () async {
    final m = await merchant('1', 'Maxi');
    final r = await receipt(
        merchantId: m, total: 12000, pfrTime: DateTime(2026, 1, 1));
    // 120,00 sa 20% PDV: osnovica 100, PDV 20,00 => 2000 para.
    await item(r, 'Artikal', 12000, rate: 20);

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    expect(s.estimatedVatMinor, 2000);
  });

  test('invalid receipts excluded', () async {
    final m = await merchant('1', 'Maxi');
    await receipt(
        merchantId: m,
        total: 9999,
        pfrTime: DateTime(2026, 1, 1),
        status: FetchStatus.invalid);

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    expect(s.totalMinor, 0);
    expect(s.isEmpty, isTrue);
  });

  test('range filter excludes older receipts', () async {
    final m = await merchant('1', 'Maxi');
    await receipt(merchantId: m, total: 1000, pfrTime: DateTime(2024, 1, 1));
    await receipt(merchantId: m, total: 2000, pfrTime: DateTime(2026, 5, 1));

    final s = await repo.loadSummary(AnalyticsRange.last3Months,
        now: DateTime(2026, 6, 1));
    expect(s.totalMinor, 2000); // stari (2024) izbačen
  });
}
