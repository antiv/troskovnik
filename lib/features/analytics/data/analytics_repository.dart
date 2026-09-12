import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/domain/currency.dart';
import '../../categories/domain/category_models.dart';
import '../domain/advanced_analytics_models.dart';
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
    // Osiguraj da su sve valute iz baze prisutne u mapi kako picker ne bi nestao.
    final allDbCurrencies = await _distinctCurrencies();
    for (final c in allDbCurrencies) {
      totalsByCurrency.putIfAbsent(c, () => 0);
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

  Future<List<Currency>> _distinctCurrencies() async {
    final r = _db.receipts;
    final currencyExpr = r.currency.dartCast<int>();
    final q = _db.selectOnly(r, distinct: true)
      ..addColumns([currencyExpr])
      ..where(r.fetchStatus.equalsValue(FetchStatus.invalid).not());
    final rows = await q.get();
    final list = rows.map((row) {
      final idx = row.read(currencyExpr) ?? 0;
      return Currency.values[idx.clamp(0, Currency.values.length - 1)];
    }).toSet().toList();
    list.sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

  /// Pomoćni izraz za filtriranje po valuti koji tretira NULL kao RSD (pre-v7 računi).
  Expression<bool> _currencyFilter(Currency currency) {
    final r = _db.receipts;
    if (currency == Currency.rsd) {
      return r.currency.equalsValue(Currency.rsd) | r.currency.isNull();
    }
    return r.currency.equalsValue(currency);
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
      expr = expr & _currencyFilter(currency);
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

  // ==========================================
  // NAPREDNA ANALITIKA (ADVANCED ANALYTICS)
  // ==========================================

  /// Reaktivni stream za naprednu analitiku.
  Stream<AdvancedAnalyticsSummary> watchAdvancedSummary(
    AdvancedAnalyticsFilter filter, {
    DateTime? now,
  }) {
    final trigger = _db
        .customSelect(
          'SELECT (SELECT count(*) FROM receipts) AS r, '
          '(SELECT count(*) FROM line_items) AS i, '
          '(SELECT count(*) FROM categories) AS c',
          readsFrom: {_db.receipts, _db.lineItems, _db.merchants, _db.categories},
        )
        .watch();
    return trigger.asyncMap((_) => loadAdvancedSummary(filter, now: now));
  }

  /// Učitava sveobuhvatan izveštaj napredne analitike za zadati filter.
  Future<AdvancedAnalyticsSummary> loadAdvancedSummary(
    AdvancedAnalyticsFilter filter, {
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final (from, to) = _advancedRangeBounds(filter, ts);

    final r = _db.receipts;
    final baseFilter = _advancedFilterExpr(from, to, filter);

    // 1. Ukupan iznos i broj računa za zadati period i filter.
    final totalCol = r.totalAmount.sum();
    final countCol = r.id.count();
    final totalQuery = _db.selectOnly(r)
      ..addColumns([totalCol, countCol])
      ..where(baseFilter);
    final totalRow = await totalQuery.getSingleOrNull();
    final totalMinor = totalRow?.read(totalCol) ?? 0;
    final receiptCount = totalRow?.read(countCol) ?? 0;
    final avgReceiptMinor = receiptCount > 0 ? (totalMinor / receiptCount).round() : 0;

    // 2. Mesec-na-mesec (MoM) poređenje.
    final mom = await _loadMomComparison(filter, ts);

    // 3. Pacing / Kumulativna dnevna potrošnja za tekući i prethodni mesec.
    final pacing = await _loadSpendingPacing(filter, ts);

    // 4. Dan u nedelji i doba dana.
    final (dayOfWeek, timeOfDay, basketSizes) =
        await _loadTimeAndBasketPatterns(baseFilter, filter.currency);

    // 5. Kategorije i trendovi.
    final categorySpending = await _loadAdvancedCategorySpending(baseFilter, filter.categoryId);
    final categoryTrends = await _loadCategoryTrends(filter, ts);
    final categoryMovers = await _loadCategoryMovers(filter, ts);

    // 6. Prodavci i Pareto matrica.
    final (merchantMatrix, pareto) = await _loadMerchantMatrix(baseFilter, totalMinor);

    // 7. Inflacija i praćenje cena artikala.
    final priceInflation = await _loadPriceInflation(filter.currency);

    // 8. PDV / porezi.
    final taxBreakdown = await _loadTaxBreakdown(baseFilter);

    // 9. Poslovno vs Lično.
    final businessSplit = await _loadAdvancedBusinessSplit(from, to, filter.currency);

    return AdvancedAnalyticsSummary(
      totalMinor: totalMinor,
      receiptCount: receiptCount,
      averageReceiptMinor: avgReceiptMinor,
      momComparison: mom,
      pacing: pacing,
      dayOfWeek: dayOfWeek,
      timeOfDay: timeOfDay,
      basketSizes: basketSizes,
      categorySpending: categorySpending,
      categoryTrends: categoryTrends,
      categoryMovers: categoryMovers,
      merchantMatrix: merchantMatrix,
      pareto: pareto,
      priceInflation: priceInflation,
      taxBreakdown: taxBreakdown,
      businessSplit: businessSplit,
    );
  }

  (DateTime? from, DateTime? to) _advancedRangeBounds(
    AdvancedAnalyticsFilter filter,
    DateTime now,
  ) {
    switch (filter.preset) {
      case AdvancedAnalyticsDatePreset.thisMonth:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1),
        );
      case AdvancedAnalyticsDatePreset.lastMonth:
        return (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 1),
        );
      case AdvancedAnalyticsDatePreset.last30Days:
        return (
          now.subtract(const Duration(days: 30)),
          now,
        );
      case AdvancedAnalyticsDatePreset.last90Days:
        return (
          now.subtract(const Duration(days: 90)),
          now,
        );
      case AdvancedAnalyticsDatePreset.thisYear:
        return (
          DateTime(now.year, 1, 1),
          DateTime(now.year + 1, 1, 1),
        );
      case AdvancedAnalyticsDatePreset.lastYear:
        return (
          DateTime(now.year - 1, 1, 1),
          DateTime(now.year, 1, 1),
        );
      case AdvancedAnalyticsDatePreset.all:
        return (null, null);
      case AdvancedAnalyticsDatePreset.custom:
        final to = filter.customTo != null
            ? DateTime(
                filter.customTo!.year,
                filter.customTo!.month,
                filter.customTo!.day,
                23,
                59,
                59,
                999,
              )
            : null;
        return (filter.customFrom, to);
    }
  }

  Expression<bool> _advancedFilterExpr(
    DateTime? from,
    DateTime? to,
    AdvancedAnalyticsFilter filter,
  ) {
    final r = _db.receipts;
    var expr = r.fetchStatus.equalsValue(FetchStatus.invalid).not();
    expr = expr & _currencyFilter(filter.currency);

    switch (filter.businessFilter) {
      case AnalyticsBusinessFilter.all:
        break;
      case AnalyticsBusinessFilter.personalOnly:
        expr = expr & r.isBusiness.equals(false);
        break;
      case AnalyticsBusinessFilter.businessOnly:
        expr = expr & r.isBusiness.equals(true);
        break;
    }

    if (from != null) {
      expr = expr &
          (r.pfrTime.isBiggerOrEqualValue(from) |
              (r.pfrTime.isNull() & r.createdAt.isBiggerOrEqualValue(from)));
    }
    if (to != null) {
      expr = expr &
          (r.pfrTime.isSmallerOrEqualValue(to) |
              (r.pfrTime.isNull() & r.createdAt.isSmallerOrEqualValue(to)));
    }
    return expr;
  }

  Future<MonthOverMonthComparison?> _loadMomComparison(
    AdvancedAnalyticsFilter filter,
    DateTime now,
  ) async {
    final r = _db.receipts;

    // Tekući mesec i prethodni mesec.
    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 1);

    final prevStart = DateTime(now.year, now.month - 1, 1);
    final prevEnd = curStart;

    final curFilter = _advancedFilterExpr(curStart, curEnd, filter);
    final prevFilter = _advancedFilterExpr(prevStart, prevEnd, filter);

    final totalCol = r.totalAmount.sum();
    final countCol = r.id.count();

    final curRow = await (_db.selectOnly(r)
          ..addColumns([totalCol, countCol])
          ..where(curFilter))
        .getSingleOrNull();

    final prevRow = await (_db.selectOnly(r)
          ..addColumns([totalCol, countCol])
          ..where(prevFilter))
        .getSingleOrNull();

    final curTotal = curRow?.read(totalCol) ?? 0;
    final curCount = curRow?.read(countCol) ?? 0;
    final prevTotal = prevRow?.read(totalCol) ?? 0;
    final prevCount = prevRow?.read(countCol) ?? 0;

    if (curCount == 0 && prevCount == 0) return null;

    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    return MonthOverMonthComparison(
      currentYear: now.year,
      currentMonth: now.month,
      currentTotalMinor: curTotal,
      currentReceiptCount: curCount,
      previousYear: prevMonthDate.year,
      previousMonth: prevMonthDate.month,
      previousTotalMinor: prevTotal,
      previousReceiptCount: prevCount,
    );
  }

  Future<List<SpendingPacingPoint>> _loadSpendingPacing(
    AdvancedAnalyticsFilter filter,
    DateTime now,
  ) async {
    final r = _db.receipts;
    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 1);
    final prevStart = DateTime(now.year, now.month - 1, 1);
    final prevEnd = curStart;

    final curFilter = _advancedFilterExpr(curStart, curEnd, filter);
    final prevFilter = _advancedFilterExpr(prevStart, prevEnd, filter);

    final curRows = await (_db.select(r)
          ..where((tbl) => curFilter)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.pfrTime)]))
        .get();

    final prevRows = await (_db.select(r)
          ..where((tbl) => prevFilter)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.pfrTime)]))
        .get();

    final curDaily = <int, int>{};
    for (final row in curRows) {
      final date = row.pfrTime ?? row.createdAt;
      final day = date.day;
      curDaily[day] = (curDaily[day] ?? 0) + row.totalAmount;
    }

    final prevDaily = <int, int>{};
    for (final row in prevRows) {
      final date = row.pfrTime ?? row.createdAt;
      final day = date.day;
      prevDaily[day] = (prevDaily[day] ?? 0) + row.totalAmount;
    }

    final points = <SpendingPacingPoint>[];
    var curCum = 0;
    var prevCum = 0;
    final maxDay = DateTime(now.year, now.month + 1, 0).day;

    for (var day = 1; day <= maxDay; day++) {
      if (curDaily.containsKey(day)) {
        curCum += curDaily[day]!;
      }
      if (prevDaily.containsKey(day)) {
        prevCum += prevDaily[day]!;
      }

      // Ako je dan u budućnosti tekućeg meseca, zadrži poslednju kumulativnu vrednost
      final hasPassed = day <= now.day;
      points.add(
        SpendingPacingPoint(
          day: day,
          currentCumulativeMinor: hasPassed ? curCum : curCum,
          previousCumulativeMinor: prevCum,
        ),
      );
    }

    return points;
  }

  Future<(List<DayOfWeekSpending>, List<TimeOfDaySpending>, BasketSizeDistribution)>
      _loadTimeAndBasketPatterns(
    Expression<bool> baseFilter,
    Currency currency,
  ) async {
    final r = _db.receipts;
    final rows = await (_db.select(r)..where((tbl) => baseFilter)).get();

    final dowTotals = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    final dowCounts = <int, int>{for (var i = 1; i <= 7; i++) i: 0};

    final timeTotals = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    final timeCounts = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};

    // Skaliranje granica za veličinu računa po valuti.
    final (smallThreshold, mediumThreshold) = switch (currency) {
      Currency.rsd => (100000, 500000), // 1.000 RSD i 5.000 RSD
      Currency.eur => (1000, 5000), // 10 EUR i 50 EUR
      Currency.bam => (2000, 10000), // 20 BAM i 100 BAM
    };

    var smallCount = 0;
    var smallTotal = 0;
    var mediumCount = 0;
    var mediumTotal = 0;
    var largeCount = 0;
    var largeTotal = 0;

    for (final row in rows) {
      final date = row.pfrTime ?? row.createdAt;
      final dow = date.weekday; // 1 (Mon) - 7 (Sun)
      final amount = row.totalAmount;

      dowTotals[dow] = (dowTotals[dow] ?? 0) + amount;
      dowCounts[dow] = (dowCounts[dow] ?? 0) + 1;

      final hour = date.hour;
      final slot = (hour >= 6 && hour < 12)
          ? 0 // Jutro
          : (hour >= 12 && hour < 18)
              ? 1 // Popodne
              : (hour >= 18 && hour < 24)
                  ? 2 // Veče
                  : 3; // Noć

      timeTotals[slot] = (timeTotals[slot] ?? 0) + amount;
      timeCounts[slot] = (timeCounts[slot] ?? 0) + 1;

      if (amount < smallThreshold) {
        smallCount++;
        smallTotal += amount;
      } else if (amount <= mediumThreshold) {
        mediumCount++;
        mediumTotal += amount;
      } else {
        largeCount++;
        largeTotal += amount;
      }
    }

    final dowList = [
      for (var i = 1; i <= 7; i++)
        DayOfWeekSpending(
          dayOfWeek: i,
          totalMinor: dowTotals[i] ?? 0,
          receiptCount: dowCounts[i] ?? 0,
        ),
    ];

    final timeList = [
      for (var s = 0; s < 4; s++)
        TimeOfDaySpending(
          timeSlot: s,
          totalMinor: timeTotals[s] ?? 0,
          receiptCount: timeCounts[s] ?? 0,
        ),
    ];

    final basket = BasketSizeDistribution(
      smallCount: smallCount,
      smallTotalMinor: smallTotal,
      mediumCount: mediumCount,
      mediumTotalMinor: mediumTotal,
      largeCount: largeCount,
      largeTotalMinor: largeTotal,
    );

    return (dowList, timeList, basket);
  }

  Future<List<CategorySpending>> _loadAdvancedCategorySpending(
    Expression<bool> baseFilter,
    int? categoryIdFilter,
  ) async {
    final li = _db.lineItems;
    final c = _db.categories;
    final r = _db.receipts;
    final total = li.total.sum();
    final cnt = li.id.count();

    var filter = baseFilter & li.isUnparsed.equals(false);
    if (categoryIdFilter != null) {
      filter = filter &
          (categoryIdFilter == 0
              ? li.categoryId.isNull()
              : li.categoryId.equals(categoryIdFilter));
    }

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
      leftOuterJoin(c, c.id.equalsExp(li.categoryId)),
    ])
      ..addColumns([c.id, c.name, c.color, total, cnt])
      ..where(filter)
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

  Future<List<CategoryTrendPoint>> _loadCategoryTrends(
    AdvancedAnalyticsFilter filter,
    DateTime now,
  ) async {
    final li = _db.lineItems;
    final c = _db.categories;
    final r = _db.receipts;
    final ym = r.pfrTime.strftime('%Y-%m');
    final total = li.total.sum();

    // Poslednjih 6 meseci za prikaz kretanja.
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
    final trendFilter = _advancedFilterExpr(sixMonthsAgo, null, filter) &
        r.pfrTime.isNotNull() &
        li.isUnparsed.equals(false);

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
      leftOuterJoin(c, c.id.equalsExp(li.categoryId)),
    ])
      ..addColumns([c.id, c.name, c.color, ym, total])
      ..where(trendFilter)
      ..groupBy([c.id, ym])
      ..orderBy([OrderingTerm(expression: ym)]);

    final rows = await q.get();
    return rows.map((row) {
      final key = row.read(ym) ?? '0000-00';
      final parts = key.split('-');
      return CategoryTrendPoint(
        categoryId: row.read(c.id) ?? 0,
        categoryName: row.read(c.name) ?? 'Nepoznato',
        color: row.read(c.color),
        year: int.tryParse(parts[0]) ?? 0,
        month: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        totalMinor: row.read(total) ?? 0,
      );
    }).toList();
  }

  Future<List<CategoryMover>> _loadCategoryMovers(
    AdvancedAnalyticsFilter filter,
    DateTime now,
  ) async {
    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 1);
    final prevStart = DateTime(now.year, now.month - 1, 1);
    final prevEnd = curStart;

    final curFilter = _advancedFilterExpr(curStart, curEnd, filter);
    final prevFilter = _advancedFilterExpr(prevStart, prevEnd, filter);

    final curCats = await _loadAdvancedCategorySpending(curFilter, null);
    final prevCats = await _loadAdvancedCategorySpending(prevFilter, null);

    final prevMap = {for (final c in prevCats) c.categoryId: c.totalMinor};
    final allCatIds = {
      ...curCats.map((c) => c.categoryId),
      ...prevCats.map((c) => c.categoryId),
    };

    final movers = <CategoryMover>[];
    for (final id in allCatIds) {
      final cur = curCats.firstWhereOrNull((c) => c.categoryId == id);
      final prev = prevCats.firstWhereOrNull((c) => c.categoryId == id);
      final name = cur?.categoryName ?? prev?.categoryName ?? 'Nepoznato';
      final color = cur?.color ?? prev?.color;
      final curTotal = cur?.totalMinor ?? 0;
      final prevTotal = prevMap[id] ?? 0;

      if (curTotal > 0 || prevTotal > 0) {
        movers.add(
          CategoryMover(
            categoryId: id,
            categoryName: name,
            color: color,
            currentTotalMinor: curTotal,
            previousTotalMinor: prevTotal,
          ),
        );
      }
    }

    movers.sort((a, b) => b.deltaMinor.abs().compareTo(a.deltaMinor.abs()));
    return movers;
  }

  Future<(List<MerchantMatrixItem>, ParetoConcentration)> _loadMerchantMatrix(
    Expression<bool> baseFilter,
    int totalSpendMinor,
  ) async {
    final r = _db.receipts;
    final m = _db.merchants;
    final total = r.totalAmount.sum();
    final cnt = r.id.count();

    final q = _db.selectOnly(r).join([
      innerJoin(m, m.id.equalsExp(r.merchantId)),
    ])
      ..addColumns([m.id, m.name, m.tin, total, cnt])
      ..where(baseFilter)
      ..groupBy([m.id])
      ..orderBy([OrderingTerm(expression: total, mode: OrderingMode.desc)]);

    final rows = await q.get();
    final items = <MerchantMatrixItem>[];
    for (final row in rows) {
      final mTotal = row.read(total) ?? 0;
      final percent = totalSpendMinor > 0 ? (mTotal / totalSpendMinor) * 100.0 : 0.0;
      items.add(
        MerchantMatrixItem(
          merchantId: row.read(m.id) ?? 0,
          merchantName: row.read(m.name) ?? '',
          tin: row.read(m.tin) ?? '',
          receiptCount: row.read(cnt) ?? 0,
          totalMinor: mTotal,
          percentageOfTotal: percent,
        ),
      );
    }

    final top3Total = items.take(3).fold<int>(0, (sum, it) => sum + it.totalMinor);
    final top5Total = items.take(5).fold<int>(0, (sum, it) => sum + it.totalMinor);
    final top3Pct = totalSpendMinor > 0 ? (top3Total / totalSpendMinor) * 100.0 : 0.0;
    final top5Pct = totalSpendMinor > 0 ? (top5Total / totalSpendMinor) * 100.0 : 0.0;

    final pareto = ParetoConcentration(
      top3Percentage: top3Pct,
      top5Percentage: top5Pct,
      top3TotalMinor: top3Total,
      totalSpendMinor: totalSpendMinor,
    );

    return (items, pareto);
  }

  Future<List<ItemPriceInflation>> _loadPriceInflation(Currency currency) async {
    final r = _db.receipts;
    final li = _db.lineItems;

    final filter = r.fetchStatus.equalsValue(FetchStatus.invalid).not() &
        _currencyFilter(currency) &
        li.isUnparsed.equals(false) &
        li.unitPrice.isBiggerThanValue(0) &
        r.pfrTime.isNotNull();

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([li.name, r.pfrTime, li.unitPrice])
      ..where(filter)
      ..orderBy([
        OrderingTerm(expression: li.name),
        OrderingTerm(expression: r.pfrTime),
      ]);

    final rows = await q.get();
    final itemMap = <String, List<PricePoint>>{};
    for (final row in rows) {
      final name = row.read(li.name);
      final date = row.read(r.pfrTime);
      final price = row.read(li.unitPrice);
      if (name != null && date != null && price != null && price > 0) {
        itemMap.putIfAbsent(name, () => []).add(
              PricePoint(date: date, unitPriceMinor: price),
            );
      }
    }

    final results = <ItemPriceInflation>[];
    for (final entry in itemMap.entries) {
      final points = entry.value;
      if (points.length < 2) continue;

      final first = points.first;
      final latest = points.last;
      var min = points.first.unitPriceMinor;
      var max = points.first.unitPriceMinor;
      for (final p in points) {
        if (p.unitPriceMinor < min) min = p.unitPriceMinor;
        if (p.unitPriceMinor > max) max = p.unitPriceMinor;
      }

      results.add(
        ItemPriceInflation(
          name: entry.key,
          firstPriceMinor: first.unitPriceMinor,
          latestPriceMinor: latest.unitPriceMinor,
          minPriceMinor: min,
          maxPriceMinor: max,
          firstDate: first.date,
          latestDate: latest.date,
          purchaseCount: points.length,
        ),
      );
    }

    // Sortiraj po apsolutnoj procentualnoj promeni.
    results.sort((a, b) => b.percentChange.abs().compareTo(a.percentChange.abs()));
    return results;
  }

  Future<List<TaxRateBreakdown>> _loadTaxBreakdown(Expression<bool> baseFilter) async {
    final r = _db.receipts;
    final li = _db.lineItems;

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([li.taxRate, li.taxLabel, li.total])
      ..where(baseFilter & li.isUnparsed.equals(false) & li.taxRate.isNotNull());

    final rows = await q.get();
    final grouped = <double, (String?, int)>{};

    for (final row in rows) {
      final rate = row.read(li.taxRate);
      final label = row.read(li.taxLabel);
      final total = row.read(li.total) ?? 0;
      if (rate == null) continue;

      final existing = grouped[rate];
      grouped[rate] = (label ?? existing?.$1, (existing?.$2 ?? 0) + total);
    }

    final list = <TaxRateBreakdown>[];
    for (final entry in grouped.entries) {
      final rate = entry.key;
      final label = entry.value.$1;
      final total = entry.value.$2;
      final base = (total / (1 + rate / 100)).round();
      final vat = total - base;

      list.add(
        TaxRateBreakdown(
          taxRate: rate,
          taxLabel: label,
          taxableBaseMinor: base,
          vatMinor: vat,
          totalMinor: total,
        ),
      );
    }

    list.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return list;
  }

  Future<BusinessSplit> _loadAdvancedBusinessSplit(
    DateTime? from,
    DateTime? to,
    Currency currency,
  ) async {
    final r = _db.receipts;
    final total = r.totalAmount.sum();

    var filter = r.fetchStatus.equalsValue(FetchStatus.invalid).not() &
        _currencyFilter(currency);

    if (from != null) {
      filter = filter &
          (r.pfrTime.isBiggerOrEqualValue(from) |
              (r.pfrTime.isNull() & r.createdAt.isBiggerOrEqualValue(from)));
    }
    if (to != null) {
      filter = filter &
          (r.pfrTime.isSmallerOrEqualValue(to) |
              (r.pfrTime.isNull() & r.createdAt.isSmallerOrEqualValue(to)));
    }

    final q = _db.selectOnly(r)
      ..addColumns([r.isBusiness, total])
      ..where(filter)
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
}
