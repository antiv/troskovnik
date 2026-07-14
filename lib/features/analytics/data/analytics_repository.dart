import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/domain/currency.dart';
import '../../categories/domain/category_models.dart';
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
    Currency? currency,
  }) {
    // Bilo koja izmena receipts/line_items/merchants pokreće preračun.
    final trigger = _db
        .customSelect(
          'SELECT (SELECT count(*) FROM receipts) AS r, '
          '(SELECT count(*) FROM line_items) AS i',
          readsFrom: {_db.receipts, _db.lineItems, _db.merchants},
        )
        .watch();
    return trigger.asyncMap((_) => loadSummary(range, now: now, currency: currency));
  }

  Future<AnalyticsSummary> loadSummary(
    AnalyticsRange range, {
    DateTime? now,
    Currency? currency,
  }) async {
    final ts = now ?? DateTime.now();
    final since = _since(range, ts);

    // _monthly i _byMerchant su bez currency filtera — grupisani su po valuti
    // i screen ih filtrira u Dart-u da bi picker imao sve dostupne valute.
    final monthly = await _monthly(since);
    final byMerchant = await _byMerchant(since);
    final split = await _businessSplit(since, currency: currency);
    final byPayment = await _byPaymentMethod(since, currency: currency);
    final topItems = await _topItems(since, currency: currency);
    final vat = await _estimatedVat(since, currency: currency);
    final byCategory = await _byCategory(since, currency: currency);

    // Zbir po valuti — nikad ne sabiramo RSD + BAM.
    final totalsByCurrency = <Currency, int>{};
    for (final m in byMerchant) {
      totalsByCurrency[m.currency] =
          (totalsByCurrency[m.currency] ?? 0) + m.totalMinor;
    }
    final receiptCount =
        byMerchant.fold<int>(0, (a, m) => a + m.receiptCount);

    return AnalyticsSummary(
      totalsByCurrency: totalsByCurrency,
      receiptCount: receiptCount,
      estimatedVatMinor: vat,
      monthly: monthly,
      byMerchant: byMerchant,
      businessSplit: split,
      byPaymentMethod: byPayment,
      topItems: topItems,
      byCategory: byCategory,
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

  /// Zajednički filter: validni računi (+ opciono period i valuta).
  Expression<bool> _validAnd(DateTime? since, {Currency? currency}) {
    final r = _db.receipts;
    var expr = r.fetchStatus.equalsValue(FetchStatus.invalid).not();
    if (since != null) {
      final inPeriod = r.pfrTime.isBiggerOrEqualValue(since) |
          (r.pfrTime.isNull() & r.createdAt.isBiggerOrEqualValue(since));
      expr = expr & inPeriod;
    }
    if (currency != null) {
      expr = expr & r.currency.equalsValue(currency);
    }
    return expr;
  }

  Future<List<MonthlySpending>> _monthly(DateTime? since,
      {int? merchantId}) async {
    final r = _db.receipts;
    final ym = r.pfrTime.strftime('%Y-%m');
    final total = r.totalAmount.sum();
    final cnt = r.id.count();
    final currencyExpr = r.currency.dartCast<int>();

    var filter = _validAnd(since) & r.pfrTime.isNotNull();
    if (merchantId != null) filter = filter & r.merchantId.equals(merchantId);

    final q = _db.selectOnly(r)
      ..addColumns([ym, currencyExpr, total, cnt])
      ..where(filter)
      ..groupBy([ym, currencyExpr])
      ..orderBy([OrderingTerm(expression: ym)]);

    final rows = await q.get();
    return rows.map((row) {
      final key = row.read(ym) ?? '0000-00';
      final parts = key.split('-');
      final currencyInt = row.read(currencyExpr) ?? 0;
      return MonthlySpending(
        year: int.tryParse(parts[0]) ?? 0,
        month: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        totalMinor: row.read(total) ?? 0,
        receiptCount: row.read(cnt) ?? 0,
        currency: Currency.values[currencyInt],
      );
    }).toList();
  }

  Future<List<MerchantSpending>> _byMerchant(DateTime? since) async {
    final r = _db.receipts;
    final m = _db.merchants;
    final total = r.totalAmount.sum();
    final cnt = r.id.count();
    final currencyExpr = r.currency.dartCast<int>();

    final q = _db.selectOnly(r).join([
      innerJoin(m, m.id.equalsExp(r.merchantId)),
    ])
      ..addColumns([m.id, m.name, currencyExpr, total, cnt])
      ..where(_validAnd(since))
      ..groupBy([m.id, currencyExpr])
      ..orderBy([OrderingTerm(expression: total, mode: OrderingMode.desc)]);

    final rows = await q.get();
    return rows.map((row) {
      final currencyIdx = row.read(currencyExpr) ?? 0;
      return MerchantSpending(
        merchantId: row.read(m.id) ?? 0,
        merchantName: row.read(m.name) ?? '',
        totalMinor: row.read(total) ?? 0,
        receiptCount: row.read(cnt) ?? 0,
        currency: Currency.values[currencyIdx],
      );
    }).toList();
  }

  Future<BusinessSplit> _businessSplit(DateTime? since, {Currency? currency}) async {
    final r = _db.receipts;
    final total = r.totalAmount.sum();

    final q = _db.selectOnly(r)
      ..addColumns([r.isBusiness, total])
      ..where(_validAnd(since, currency: currency))
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

  /// Potrošnja po načinu plaćanja. Agregacija u Dart-u jer su iznosi u JSON-u
  /// (`payments_json`); kombinovano plaćanje se deli po načinima. Fallback:
  /// ako nema strukture, ceo iznos ide na `payment_method`, pa na „Nepoznato".
  Future<List<PaymentMethodSpending>> _byPaymentMethod(DateTime? since, {Currency? currency}) async {
    final r = _db.receipts;
    final q = _db.selectOnly(r)
      ..addColumns([r.paymentsJson, r.paymentMethod, r.totalAmount])
      ..where(_validAnd(since, currency: currency));

    final totals = <String, int>{};
    final counts = <String, int>{};
    void add(String method, int amount) {
      totals[method] = (totals[method] ?? 0) + amount;
      counts[method] = (counts[method] ?? 0) + 1;
    }

    for (final row in await q.get()) {
      final json = row.read(r.paymentsJson);
      final method = row.read(r.paymentMethod);
      final total = row.read(r.totalAmount) ?? 0;

      Map<String, dynamic>? map;
      if (json != null) {
        try {
          map = jsonDecode(json) as Map<String, dynamic>;
        } catch (_) {
          map = null;
        }
      }

      if (map != null && map.isNotEmpty) {
        map.forEach((k, v) => add(k, (v as num).toInt()));
      } else if (method != null && method.isNotEmpty) {
        add(method, total);
      } else {
        add(_paymentUnknownKey, total);
      }
    }

    final list = totals.entries
        .map((e) => PaymentMethodSpending(
              method: e.key,
              totalMinor: e.value,
              receiptCount: counts[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return list;
  }

  /// Sentinel za nepoznat način plaćanja; UI ga mapira na lokalizovan tekst.
  static const paymentUnknownKey = _paymentUnknownKey;
  static const _paymentUnknownKey = '__unknown__';

  /// Artikli jedne kategorije (grupisano po nazivu), za drill-down iz
  /// analitike. `categoryId = 0` znači „bez kategorije" (NULL u bazi) —
  /// isti sentinel kao u [_byCategory].
  Future<List<TopItem>> categoryItems(
    int categoryId,
    AnalyticsRange range, {
    DateTime? now,
    Currency? currency,
  }) {
    final since = _since(range, now ?? DateTime.now());
    return _topItems(since,
        categoryId: categoryId, currency: currency, limit: null);
  }

  Future<List<TopItem>> _topItems(DateTime? since,
      {int? limit = 10,
      int? merchantId,
      int? categoryId,
      Currency? currency}) async {
    final r = _db.receipts;
    final li = _db.lineItems;
    final total = li.total.sum();
    final cnt = li.id.count();

    var filter = _validAnd(since, currency: currency) & li.isUnparsed.equals(false);
    if (merchantId != null) filter = filter & r.merchantId.equals(merchantId);
    if (categoryId != null) {
      filter = filter &
          (categoryId == 0
              ? li.categoryId.isNull()
              : li.categoryId.equals(categoryId));
    }

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([li.name, total, cnt])
      ..where(filter)
      ..groupBy([li.name])
      ..orderBy([OrderingTerm(expression: total, mode: OrderingMode.desc)]);
    if (limit != null) q.limit(limit);

    final rows = await q.get();
    return rows
        .map((row) => TopItem(
              name: row.read(li.name) ?? '',
              totalMinor: row.read(total) ?? 0,
              count: row.read(cnt) ?? 0,
            ))
        .toList();
  }

  Future<List<CategorySpending>> _byCategory(DateTime? since, {Currency? currency}) async {
    final li = _db.lineItems;
    final c = _db.categories;
    final r = _db.receipts;
    final total = li.total.sum();
    final cnt = li.id.count();

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
      leftOuterJoin(c, c.id.equalsExp(li.categoryId)),
    ])
      ..addColumns([c.id, c.name, c.color, total, cnt])
      ..where(_validAnd(since, currency: currency) & li.isUnparsed.equals(false))
      ..groupBy([c.id]);

    final rows = await q.get();
    return rows
        .map((row) => CategorySpending(
              categoryId: row.read(c.id) ?? 0,
              categoryName: row.read(c.name) ?? 'Nepoznato',
              color: row.read(c.color),
              totalMinor: row.read(total) ?? 0,
              itemCount: row.read(cnt) ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  }

  /// Procenjen PDV iz stavki koje imaju poresku stopu:
  /// pdv = total - total / (1 + rate/100). Samo računi sa strukturiranim
  /// stavkama; vraća zaokružen zbir u para.
  Future<int> _estimatedVat(DateTime? since, {Currency? currency}) async {
    final r = _db.receipts;
    final li = _db.lineItems;

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([li.total, li.taxRate])
      ..where(_validAnd(since, currency: currency) &
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
