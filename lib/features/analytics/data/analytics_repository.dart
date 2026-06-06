import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../domain/analytics_models.dart';

/// Agregacije potrošnje nad postojećim podacima (bez kategorija — MVP).
///
/// Koristi `pfr_time` kao datum potrošnje; računi bez `pfr_time` (npr. još u
/// obradi) se izostavljaju iz vremenskih agregacija ali ne i iz ukupnog zbira.
/// Nevažeći računi (`fetch_status = invalid`) se isključuju.
class AnalyticsRepository {
  AnalyticsRepository(this._db);

  final AppDatabase _db;

  /// Donja granica perioda na osnovu opsega (null = sve).
  DateTime? _since(AnalyticsRange range, DateTime now) {
    switch (range) {
      case AnalyticsRange.last3Months:
        return DateTime(now.year, now.month - 3, now.day);
      case AnalyticsRange.last12Months:
        return DateTime(now.year - 1, now.month, now.day);
      case AnalyticsRange.all:
        return null;
    }
  }

  /// Reaktivni sažetak: re-emituje na svaku izmenu baze.
  Stream<AnalyticsSummary> watchSummary(
    AnalyticsRange range, {
    DateTime? now,
  }) {
    // Bilo koja izmena receipts/line_items/merchants pokreće preračun.
    final trigger = _db
        .customSelect(
          'SELECT (SELECT count(*) FROM receipts) AS r, '
          '(SELECT count(*) FROM line_items) AS i',
          readsFrom: {_db.receipts, _db.lineItems, _db.merchants},
        )
        .watch();
    return trigger.asyncMap((_) => loadSummary(range, now: now));
  }

  Future<AnalyticsSummary> loadSummary(
    AnalyticsRange range, {
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final since = _since(range, ts);

    final monthly = await _monthly(since);
    final byMerchant = await _byMerchant(since);
    final split = await _businessSplit(since);
    final topItems = await _topItems(since);
    final vat = await _estimatedVat(since);

    final total = byMerchant.fold<int>(0, (a, m) => a + m.totalMinor);
    final receiptCount =
        byMerchant.fold<int>(0, (a, m) => a + m.receiptCount);

    return AnalyticsSummary(
      totalMinor: total,
      receiptCount: receiptCount,
      estimatedVatMinor: vat,
      monthly: monthly,
      byMerchant: byMerchant,
      businessSplit: split,
      topItems: topItems,
    );
  }

  /// Detalji za jednog prodavca: zbir/broj računa, mesečni trend i top artikli.
  Future<MerchantDetail> merchantDetail(
    int merchantId,
    AnalyticsRange range, {
    DateTime? now,
  }) async {
    final since = _since(range, now ?? DateTime.now());
    final r = _db.receipts;
    final m = _db.merchants;
    final byMerchantFilter = _validAnd(since) & r.merchantId.equals(merchantId);

    // Naziv + zbir + broj računa.
    final total = r.totalAmount.sum();
    final cnt = r.id.count();
    final aggQ = _db.selectOnly(r).join([
      innerJoin(m, m.id.equalsExp(r.merchantId)),
    ])
      ..addColumns([m.name, total, cnt])
      ..where(byMerchantFilter)
      ..groupBy([m.id]);
    final aggRow = await aggQ.getSingleOrNull();

    return MerchantDetail(
      merchantName: aggRow?.read(m.name) ?? '',
      totalMinor: aggRow?.read(total) ?? 0,
      receiptCount: aggRow?.read(cnt) ?? 0,
      monthly: await _monthly(since, merchantId: merchantId),
      topItems: await _topItems(since, merchantId: merchantId),
    );
  }

  /// Detalji za jedan artikal (po nazivu): zbir/količina/broj, istorija cene i
  /// raspodela po prodavcima.
  Future<ItemDetail> itemDetail(
    String name,
    AnalyticsRange range, {
    DateTime? now,
  }) async {
    final since = _since(range, now ?? DateTime.now());
    final r = _db.receipts;
    final li = _db.lineItems;
    final m = _db.merchants;
    final itemFilter =
        _validAnd(since) & li.isUnparsed.equals(false) & li.name.equals(name);

    // Agregat: ukupan iznos, broj kupovina (stavki), ukupna količina.
    final total = li.total.sum();
    final cnt = li.id.count();
    final qty = li.quantity.sum();
    final aggQ = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([total, cnt, qty])
      ..where(itemFilter);
    final aggRow = await aggQ.getSingleOrNull();

    // Istorija jedinične cene po vremenu računa.
    final historyQ = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([r.pfrTime, li.unitPrice])
      ..where(itemFilter & r.pfrTime.isNotNull())
      ..orderBy([OrderingTerm(expression: r.pfrTime)]);
    final history = (await historyQ.get())
        .map((row) => PricePoint(
              date: row.read(r.pfrTime)!,
              unitPriceMinor: row.read(li.unitPrice) ?? 0,
            ))
        .toList();

    // Raspodela po prodavcima.
    final mTotal = li.total.sum();
    final mCnt = li.id.count();
    final byMerchantQ = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
      innerJoin(m, m.id.equalsExp(r.merchantId)),
    ])
      ..addColumns([m.id, m.name, mTotal, mCnt])
      ..where(itemFilter)
      ..groupBy([m.id])
      ..orderBy([OrderingTerm(expression: mTotal, mode: OrderingMode.desc)]);
    final byMerchant = (await byMerchantQ.get())
        .map((row) => MerchantSpending(
              merchantId: row.read(m.id) ?? 0,
              merchantName: row.read(m.name) ?? '',
              totalMinor: row.read(mTotal) ?? 0,
              receiptCount: row.read(mCnt) ?? 0,
            ))
        .toList();

    return ItemDetail(
      name: name,
      totalMinor: aggRow?.read(total) ?? 0,
      purchaseCount: aggRow?.read(cnt) ?? 0,
      totalQuantity: aggRow?.read(qty) ?? 0,
      priceHistory: history,
      byMerchant: byMerchant,
    );
  }

  /// Zajednički filter: validni računi (+ opciono period po pfr_time/created_at).
  Expression<bool> _validAnd(DateTime? since) {
    final r = _db.receipts;
    final notInvalid = r.fetchStatus.equalsValue(FetchStatus.invalid).not();
    if (since == null) return notInvalid;

    // U periodu: pfr_time >= since, ili (nema pfr_time) created_at >= since.
    final inPeriod = r.pfrTime.isBiggerOrEqualValue(since) |
        (r.pfrTime.isNull() & r.createdAt.isBiggerOrEqualValue(since));
    return notInvalid & inPeriod;
  }

  Future<List<MonthlySpending>> _monthly(DateTime? since,
      {int? merchantId}) async {
    final r = _db.receipts;
    final ym = r.pfrTime.strftime('%Y-%m');
    final total = r.totalAmount.sum();
    final cnt = r.id.count();

    var filter = _validAnd(since) & r.pfrTime.isNotNull();
    if (merchantId != null) filter = filter & r.merchantId.equals(merchantId);

    final q = _db.selectOnly(r)
      ..addColumns([ym, total, cnt])
      ..where(filter)
      ..groupBy([ym])
      ..orderBy([OrderingTerm(expression: ym)]);

    final rows = await q.get();
    return rows.map((row) {
      final key = row.read(ym) ?? '0000-00';
      final parts = key.split('-');
      return MonthlySpending(
        year: int.tryParse(parts[0]) ?? 0,
        month: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        totalMinor: row.read(total) ?? 0,
        receiptCount: row.read(cnt) ?? 0,
      );
    }).toList();
  }

  Future<List<MerchantSpending>> _byMerchant(DateTime? since) async {
    final r = _db.receipts;
    final m = _db.merchants;
    final total = r.totalAmount.sum();
    final cnt = r.id.count();

    final q = _db.selectOnly(r).join([
      innerJoin(m, m.id.equalsExp(r.merchantId)),
    ])
      ..addColumns([m.id, m.name, total, cnt])
      ..where(_validAnd(since))
      ..groupBy([m.id])
      ..orderBy([OrderingTerm(expression: total, mode: OrderingMode.desc)]);

    final rows = await q.get();
    return rows
        .map((row) => MerchantSpending(
              merchantId: row.read(m.id) ?? 0,
              merchantName: row.read(m.name) ?? '',
              totalMinor: row.read(total) ?? 0,
              receiptCount: row.read(cnt) ?? 0,
            ))
        .toList();
  }

  Future<BusinessSplit> _businessSplit(DateTime? since) async {
    final r = _db.receipts;
    final total = r.totalAmount.sum();

    final q = _db.selectOnly(r)
      ..addColumns([r.isBusiness, total])
      ..where(_validAnd(since))
      ..groupBy([r.isBusiness]);

    final rows = await q.get();
    var business = 0;
    var personal = 0;
    for (final row in rows) {
      final isB = row.read(r.isBusiness) ?? false;
      final sum = row.read(total) ?? 0;
      if (isB) {
        business += sum;
      } else {
        personal += sum;
      }
    }
    return BusinessSplit(businessMinor: business, personalMinor: personal);
  }

  Future<List<TopItem>> _topItems(DateTime? since,
      {int limit = 10, int? merchantId}) async {
    final r = _db.receipts;
    final li = _db.lineItems;
    final total = li.total.sum();
    final cnt = li.id.count();

    var filter = _validAnd(since) & li.isUnparsed.equals(false);
    if (merchantId != null) filter = filter & r.merchantId.equals(merchantId);

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([li.name, total, cnt])
      ..where(filter)
      ..groupBy([li.name])
      ..orderBy([OrderingTerm(expression: total, mode: OrderingMode.desc)])
      ..limit(limit);

    final rows = await q.get();
    return rows
        .map((row) => TopItem(
              name: row.read(li.name) ?? '',
              totalMinor: row.read(total) ?? 0,
              count: row.read(cnt) ?? 0,
            ))
        .toList();
  }

  /// Procenjen PDV iz stavki koje imaju poresku stopu:
  /// pdv = total - total / (1 + rate/100). Samo računi sa strukturiranim
  /// stavkama; vraća zaokružen zbir u para.
  Future<int> _estimatedVat(DateTime? since) async {
    final r = _db.receipts;
    final li = _db.lineItems;

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([li.total, li.taxRate])
      ..where(_validAnd(since) &
          li.isUnparsed.equals(false) &
          li.taxRate.isNotNull());

    final rows = await q.get();
    var vat = 0.0;
    for (final row in rows) {
      final total = row.read(li.total) ?? 0;
      final rate = row.read(li.taxRate);
      if (rate == null || rate <= 0) continue;
      vat += total - total / (1 + rate / 100);
    }
    return vat.round();
  }
}
