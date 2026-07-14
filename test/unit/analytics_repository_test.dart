import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/core/domain/country.dart';
import 'package:troskovnik/core/domain/currency.dart';
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
    expect(s.totalsByCurrency[Currency.rsd], 14000);
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
    expect(s.totalsByCurrency.isEmpty, isTrue);
    expect(s.isEmpty, isTrue);
  });

  test('range filter excludes older receipts', () async {
    final m = await merchant('1', 'Maxi');
    await receipt(merchantId: m, total: 1000, pfrTime: DateTime(2024, 1, 1));
    await receipt(merchantId: m, total: 2000, pfrTime: DateTime(2026, 5, 1));

    final s = await repo.loadSummary(AnalyticsRange.last3Months,
        now: DateTime(2026, 6, 1));
    expect(s.totalsByCurrency[Currency.rsd], 2000); // stari (2024) izbačen
  });

  Future<void> itemFull(int receiptId, String name,
          {required int unitPrice, required int total, double qty = 1.0}) =>
      db.into(db.lineItems).insert(
            LineItemsCompanion.insert(
              receiptId: receiptId,
              name: name,
              quantity: Value(qty),
              unitPrice: Value(unitPrice),
              total: Value(total),
            ),
          );

  test('merchantDetail aggregates total/count, monthly and top items',
      () async {
    final maxi = await merchant('1', 'Maxi');
    final idea = await merchant('2', 'Idea');
    final r1 = await receipt(
        merchantId: maxi, total: 10000, pfrTime: DateTime(2026, 1, 5));
    final r2 = await receipt(
        merchantId: maxi, total: 6000, pfrTime: DateTime(2026, 2, 5));
    final rOther = await receipt(
        merchantId: idea, total: 9000, pfrTime: DateTime(2026, 2, 7));
    await item(r1, 'Mleko', 4000);
    await item(r2, 'Mleko', 2000);
    await item(rOther, 'Mleko', 9000); // drugi prodavac — ne sme da uđe

    final d = await repo.merchantDetail(maxi, AnalyticsRange.all,
        now: DateTime(2026, 3, 1));
    expect(d.merchantName, 'Maxi');
    expect(d.totalMinor, 16000);
    expect(d.receiptCount, 2);
    expect(d.averageMinor, 8000);
    expect(d.monthly, hasLength(2));
    final mleko = d.topItems.firstWhere((t) => t.name == 'Mleko');
    expect(mleko.totalMinor, 6000); // samo kod Maxi-ja
  });

  test('itemDetail returns qty/count/total, price history and by merchant',
      () async {
    final maxi = await merchant('1', 'Maxi');
    final idea = await merchant('2', 'Idea');
    final r1 = await receipt(
        merchantId: maxi, total: 5000, pfrTime: DateTime(2026, 1, 10));
    final r2 = await receipt(
        merchantId: idea, total: 5500, pfrTime: DateTime(2026, 2, 10));
    await itemFull(r1, 'Hleb', unitPrice: 5000, total: 5000, qty: 1);
    await itemFull(r2, 'Hleb', unitPrice: 5500, total: 11000, qty: 2);
    await itemFull(r1, 'Mleko', unitPrice: 2000, total: 2000);

    final d = await repo.itemDetail('Hleb', AnalyticsRange.all,
        now: DateTime(2026, 3, 1));
    expect(d.totalMinor, 16000);
    expect(d.purchaseCount, 2);
    expect(d.totalQuantity, 3.0);
    // Istorija cene sortirana po vremenu: 50,00 → 55,00.
    expect(d.priceHistory.map((p) => p.unitPriceMinor).toList(),
        [5000, 5500]);
    expect(d.byMerchant, hasLength(2));
    expect(d.byMerchant.first.totalMinor, 11000); // Idea najviše, prva
  });

  Future<void> payReceipt({
    required int merchantId,
    required int total,
    required DateTime pfrTime,
    String? method,
    String? paymentsJson,
  }) =>
      db.into(db.receipts).insert(
            ReceiptsCompanion.insert(
              merchantId: merchantId,
              verificationUrl: 'u${DateTime.now().microsecondsSinceEpoch}p',
              pfrTime: Value(pfrTime),
              totalAmount: Value(total),
              paymentMethod: Value(method),
              paymentsJson: Value(paymentsJson),
            ),
          );

  test('byPaymentMethod splits combined payments and falls back', () async {
    final m = await merchant('1', 'Maxi');
    // Kombinovano: deo gotovina, deo kartica.
    await payReceipt(
        merchantId: m,
        total: 53000,
        pfrTime: DateTime(2026, 1, 5),
        method: 'Готовина',
        paymentsJson: '{"Готовина":20000,"Картица":33000}');
    // Fallback: samo naziv, bez strukture → ceo iznos na Картица.
    await payReceipt(
        merchantId: m,
        total: 10000,
        pfrTime: DateTime(2026, 1, 6),
        method: 'Картица');
    // Bez ičega → Nepoznato.
    await payReceipt(
        merchantId: m, total: 5000, pfrTime: DateTime(2026, 1, 7));

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    final by = {for (final p in s.byPaymentMethod) p.method: p.totalMinor};
    expect(by['Картица'], 43000); // 33.000 (kombinovano) + 10.000 (fallback)
    expect(by['Готовина'], 20000);
    expect(by[AnalyticsRepository.paymentUnknownKey], 5000);
    // Sortirano opadajuće po iznosu.
    expect(s.byPaymentMethod.first.method, 'Картица');
  });

  Future<int> receiptWithCurrency({
    required int merchantId,
    required int total,
    required DateTime pfrTime,
    required Country country,
  }) =>
      db.into(db.receipts).insert(
            ReceiptsCompanion.insert(
              merchantId: merchantId,
              verificationUrl: 'u${DateTime.now().microsecondsSinceEpoch}c',
              pfrTime: Value(pfrTime),
              totalAmount: Value(total),
              fetchStatus: Value(FetchStatus.complete),
              country: Value(country),
              currency: Value(country.currency),
            ),
          );

  test('mixed RSD + BAM — totalsByCurrency never sums different currencies',
      () async {
    final srb = await merchant('100', 'Prodavac RS');
    final bih = await merchant('200', 'Prodavac BiH');

    await receiptWithCurrency(
        merchantId: srb,
        total: 50000,
        pfrTime: DateTime.utc(2026, 3, 5),
        country: Country.serbia);
    await receiptWithCurrency(
        merchantId: bih,
        total: 10000,
        pfrTime: DateTime.utc(2026, 3, 10),
        country: Country.republikaSrpska);

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 4, 1));

    // Svaka valuta ima zaseban zbir.
    expect(s.totalsByCurrency[Currency.rsd], 50000);
    expect(s.totalsByCurrency[Currency.bam], 10000);
    // Ne sme da postoji jedan zajednički zbir koji miješa valute.
    expect(s.totalsByCurrency.length, 2);

    // Mesečna analitika: isti mesec, ali razdvojeni po valuti.
    final march = s.monthly.where((m) => m.month == 3).toList();
    expect(march, hasLength(2));
    final marchRsd = march.firstWhere((m) => m.currency == Currency.rsd);
    final marchBam = march.firstWhere((m) => m.currency == Currency.bam);
    expect(marchRsd.totalMinor, 50000);
    expect(marchBam.totalMinor, 10000);
  });

  test('categoryItems groups by name within category; 0 = bez kategorije',
      () async {
    final m = await merchant('1', 'Maxi');
    final r1 = await receipt(
        merchantId: m, total: 0, pfrTime: DateTime(2026, 1, 5), invoice: 'A');
    final r2 = await receipt(
        merchantId: m, total: 0, pfrTime: DateTime(2026, 1, 6), invoice: 'B');
    final cat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Namirnice'),
        );
    Future<void> catItem(int rid, String name, int total) =>
        db.into(db.lineItems).insert(LineItemsCompanion.insert(
              receiptId: rid,
              name: name,
              total: Value(total),
              categoryId: Value(cat),
            ));
    await catItem(r1, 'Mleko', 12000);
    await catItem(r2, 'Mleko', 6000);
    await catItem(r1, 'Hleb', 5000);
    await item(r2, 'Sijalica', 9000); // bez kategorije

    final inCat = await repo.categoryItems(cat, AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    expect(inCat, hasLength(2));
    expect(inCat.first.name, 'Mleko'); // najveći zbir prvi
    expect(inCat.first.totalMinor, 18000);
    expect(inCat.first.count, 2);
    expect(inCat.any((t) => t.name == 'Sijalica'), isFalse);

    // Sentinel 0 → stavke bez kategorije.
    final noCat = await repo.categoryItems(0, AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    expect(noCat, hasLength(1));
    expect(noCat.first.name, 'Sijalica');
  });

  test('existing serbia receipts default to Country.serbia / Currency.rsd',
      () async {
    // Računi bez eksplicitnog country/currency (stari, pre v7) trebaju
    // defaultovati na Srbiju i RSD zahvaljujući DEFAULT 0 u migraciji.
    final m = await merchant('300', 'Stari prodavac');
    await receipt(merchantId: m, total: 30000, pfrTime: DateTime(2026, 1, 1));

    final s = await repo.loadSummary(AnalyticsRange.all,
        now: DateTime(2026, 2, 1));
    expect(s.totalsByCurrency[Currency.rsd], 30000);
    expect(s.totalsByCurrency.containsKey(Currency.bam), isFalse);
  });
}
