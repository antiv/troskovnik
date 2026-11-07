import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/domain/country.dart';
import '../../../core/domain/currency.dart';
import '../../../core/normalization/item_normalization_service.dart';
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
  late final ItemNormalizationService _normalizer =
      ItemNormalizationService(_db);

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
    // Bilo koja izmena receipts/line_items/merchants/canonical_items pokreće preračun.
    final trigger = _db
        .customSelect(
          'SELECT (SELECT count(*) FROM receipts) AS r, '
          '(SELECT count(*) FROM line_items) AS i, '
          '(SELECT count(*) FROM canonical_items) AS ci',
          readsFrom: {
            _db.receipts,
            _db.lineItems,
            _db.merchants,
            _db.companies,
            _db.canonicalItems,
            _db.itemAliases,
          },
        )
        .watch();
    return trigger.asyncMap((_) => loadSummary(range, now: now, currency: currency));
  }

  Future<AnalyticsSummary> loadSummary(
    AnalyticsRange range, {
    DateTime? now,
    Currency? currency,
  }) async {
    await _normalizer.ensureNormalized();
    final ts = now ?? DateTime.now();
    final since = _since(range, ts);

    // _monthly i _byMerchant su bez currency filtera — grupisani su po valuti
    // i screen ih filtrira u Dart-u da bi picker imao sve dostupne valute.
    final monthly = await _monthly(since);
    final byMerchant = await _byMerchant(since);
    final split = await _businessSplit(since, currency: currency);
    final byPayment = await _byPaymentMethod(since, currency: currency);
    final allTopItems = await _topItems(since, currency: currency, limit: null);
    final topItems = allTopItems.take(10).toList();
    final totalUniqueItemsCount =
        allTopItems.where((it) => it.totalMinor > 0).length;
    final vat = await _estimatedVat(since, currency: currency);
    final byCategory = await _byCategory(since, currency: currency);
    final byCompany = await _byCompany(_validAnd(since, currency: currency));

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
      totalUniqueItemsCount: totalUniqueItemsCount,
      byCompany: byCompany,
    );
  }

  /// Detalji za jednog prodavca: zbir/broj računa, mesečni trend i top artikli.
  Future<MerchantDetail> merchantDetail(
    int merchantId,
    AnalyticsRange range, {
    DateTime? now,
  }) async {
    await _normalizer.ensureNormalized();
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

  /// Detalji za jedan artikal (po kanonskom ili sirovom nazivu): zbir/količina/broj,
  /// istorija cene (razdvojena po jedinici mere), poređenje cena po prodavcima,
  /// isplativost pakovanja (1L / 1kg), ritam kupovine i poslednje kupovine.
  Future<ItemDetail> itemDetail(
    String name,
    AnalyticsRange range, {
    DateTime? now,
  }) async {
    await _normalizer.ensureNormalized();
    final since = _since(range, now ?? DateTime.now());
    final r = _db.receipts;
    final li = _db.lineItems;
    final m = _db.merchants;
    final ci = _db.canonicalItems;
    final cat = _db.categories;

    // Pokušaj pronalaska kanonskog artikla po displayName ili preko postojećeg line_item-a.
    var canonicalRow = await (_db.select(ci)
          ..where((t) => t.displayName.equals(name))
          ..limit(1))
        .getSingleOrNull();
    if (canonicalRow == null) {
      final sampleLi = await (_db.select(li)
            ..where((t) => t.name.equals(name) & t.canonicalItemId.isNotNull())
            ..limit(1))
          .getSingleOrNull();
      if (sampleLi?.canonicalItemId != null) {
        canonicalRow = await (_db.select(ci)
              ..where((t) => t.id.equals(sampleLi!.canonicalItemId!))
              ..limit(1))
            .getSingleOrNull();
      }
    }

    final canonicalId = canonicalRow?.id;
    final resolvedDisplayName = canonicalRow?.displayName ?? name;
    final nameOrCanonicalMatch = canonicalId != null
        ? (li.canonicalItemId.equals(canonicalId) | li.name.equals(name))
        : li.name.equals(name);
    final itemFilter =
        _validAnd(since) & li.isUnparsed.equals(false) & nameOrCanonicalMatch;

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
    final totalMinorVal = aggRow?.read(total) ?? 0;
    final purchaseCountVal = aggRow?.read(cnt) ?? 0;
    final totalQtyVal = aggRow?.read(qty) ?? 0;

    // Sve pojedinačne kupovine ovog artikla (sa prodavcem i kategorijom),
    // sortirane hronološki.
    final detailQ = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
      leftOuterJoin(m, m.id.equalsExp(r.merchantId)),
      leftOuterJoin(cat, cat.id.equalsExp(li.categoryId)),
    ])
      ..addColumns([
        r.id,
        r.pfrTime,
        r.createdAt,
        m.id,
        m.name,
        li.name,
        li.quantity,
        li.unitPrice,
        li.total,
        li.extractedMeasure,
        cat.id,
        cat.name,
        cat.color,
      ])
      ..where(itemFilter)
      ..orderBy([
        OrderingTerm(expression: r.pfrTime),
        OrderingTerm(expression: r.createdAt),
      ]);
    final detailRows = await detailQ.get();

    final rawVariantsSet = <String>{};
    final priceHistoryByMeasure = <String, List<PricePoint>>{};
    final allHistory = <PricePoint>[];
    final purchaseDates = <DateTime>[];
    final allPurchasesChronological = <ItemPurchaseRecord>[];

    // Sakupljanje statistike po prodavcima (ukupno i po meri).
    final merchantAccOverall = <int, _MerchantPriceAcc>{};
    final merchantAccByMeasure = <String, Map<int, _MerchantPriceAcc>>{};

    int? resolvedCategoryId = canonicalRow?.defaultCategoryId;
    String? resolvedCategoryName;
    String? resolvedCategoryColor;

    for (final row in detailRows) {
      final rawName = row.read(li.name) ?? '';
      if (rawName.isNotEmpty) rawVariantsSet.add(rawName);

      final pfrTime = row.read(r.pfrTime);
      final effectiveDate = pfrTime ?? row.read(r.createdAt);
      final unitPrice = row.read(li.unitPrice) ?? 0;
      final lineTotal = row.read(li.total) ?? 0;
      final lineQty = row.read(li.quantity) ?? 1.0;
      final measureRaw = row.read(li.extractedMeasure);
      final measureKey = (measureRaw ?? '').trim().toUpperCase();
      final mId = row.read(m.id);
      final mName = row.read(m.name) ?? '';
      final receiptId = row.read(r.id) ?? 0;

      final rowCatId = row.read(cat.id);
      if (rowCatId != null) {
        resolvedCategoryId = rowCatId;
        resolvedCategoryName = row.read(cat.name);
        resolvedCategoryColor = row.read(cat.color);
      }

      if (pfrTime != null) {
        final pt = PricePoint(date: pfrTime, unitPriceMinor: unitPrice);
        allHistory.add(pt);
        priceHistoryByMeasure.putIfAbsent(measureKey, () => []).add(pt);
        purchaseDates.add(pfrTime);
      } else if (effectiveDate != null) {
        purchaseDates.add(effectiveDate);
      }

      if (mId != null && unitPrice > 0) {
        merchantAccOverall
            .putIfAbsent(mId, () => _MerchantPriceAcc(mId, mName))
            .add(unitPrice: unitPrice, lineTotal: lineTotal);
        final byM = merchantAccByMeasure.putIfAbsent(measureKey, () => {});
        byM
            .putIfAbsent(mId, () => _MerchantPriceAcc(mId, mName))
            .add(unitPrice: unitPrice, lineTotal: lineTotal);
      }

      allPurchasesChronological.add(
        ItemPurchaseRecord(
          receiptId: receiptId,
          date: effectiveDate,
          merchantName: mName,
          rawItemName: rawName,
          quantity: lineQty,
          unitPriceMinor: unitPrice,
          totalMinor: lineTotal,
          extractedMeasure: measureKey.isEmpty ? null : measureKey,
        ),
      );
    }

    // Ako kanonski artikal ima defaultCategoryId a nismo našli naziv iz stavki,
    // pročitaj iz tabele categories.
    if (resolvedCategoryId != null && resolvedCategoryName == null) {
      final catRow = await (_db.select(cat)
            ..where((t) => t.id.equals(resolvedCategoryId!))
            ..limit(1))
          .getSingleOrNull();
      if (catRow != null) {
        resolvedCategoryName = catRow.name;
        resolvedCategoryColor = catRow.color;
      }
    }

    final rawVariants = rawVariantsSet.toList()..sort();

    // Sortiraj mere po zastupljenosti (najčešća prva, ne-prazna pre prazne).
    final sortedMeasureKeys = priceHistoryByMeasure.keys.toList()
      ..sort((a, b) {
        final lenA = priceHistoryByMeasure[a]?.length ?? 0;
        final lenB = priceHistoryByMeasure[b]?.length ?? 0;
        final byLen = lenB.compareTo(lenA);
        if (byLen != 0) return byLen;
        if (a.isNotEmpty && b.isEmpty) return -1;
        if (a.isEmpty && b.isNotEmpty) return 1;
        return a.compareTo(b);
      });

    // Rekonstruiši mapu u redosledu zastupljenosti kako bi UI čipovi imali
    // najčešću meru na prvom mestu.
    final orderedHistoryByMeasure = <String, List<PricePoint>>{
      for (final k in sortedMeasureKeys) k: priceHistoryByMeasure[k]!,
    };

    final List<PricePoint> primaryHistory = sortedMeasureKeys.isNotEmpty
        ? orderedHistoryByMeasure[sortedMeasureKeys.first]!
        : allHistory;

    // Izgradi statistiku po prodavcima za svaku meru i ukupno.
    final merchantStatsByMeasure = <String, List<ItemMerchantStats>>{};
    for (final entry in merchantAccByMeasure.entries) {
      merchantStatsByMeasure[entry.key] =
          _finalizeMerchantStats(entry.value.values);
    }
    final primaryMeasureKey =
        sortedMeasureKeys.isNotEmpty ? sortedMeasureKeys.first : null;
    final overallMerchantStats = (primaryMeasureKey != null &&
            merchantStatsByMeasure.containsKey(primaryMeasureKey))
        ? merchantStatsByMeasure[primaryMeasureKey]!
        : _finalizeMerchantStats(merchantAccOverall.values);

    // Poređenje isplativosti pakovanja (cena po 1L / 1kg).
    final measureComparisons =
        _buildMeasureComparisons(orderedHistoryByMeasure);

    // Ritam kupovine (prosečan broj dana između kupovina i mesečna procena).
    int? averageDaysBetweenPurchases;
    int? estimatedMonthlyMinor;
    if (purchaseDates.length >= 2) {
      purchaseDates.sort();
      final spanDays =
          purchaseDates.last.difference(purchaseDates.first).inDays;
      if (spanDays >= 3) {
        averageDaysBetweenPurchases =
            (spanDays / (purchaseDates.length - 1)).round().clamp(1, 365);
        estimatedMonthlyMinor = ((totalMinorVal / spanDays) * 30).round();
      }
    }

    // Poslednje kupovine (najnovije prve, do 15 stavki).
    final recentPurchases =
        allPurchasesChronological.reversed.take(15).toList();

    // Raspodela po prodavcima (za postojeće polje byMerchant).
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
      name: resolvedDisplayName,
      totalMinor: totalMinorVal,
      purchaseCount: purchaseCountVal,
      totalQuantity: totalQtyVal,
      priceHistory: primaryHistory,
      byMerchant: byMerchant,
      canonicalItemId: canonicalId,
      rawVariants: rawVariants,
      priceHistoryByMeasure: orderedHistoryByMeasure,
      merchantStatsByMeasure: merchantStatsByMeasure,
      overallMerchantStats: overallMerchantStats,
      measureComparisons: measureComparisons,
      recentPurchases: recentPurchases,
      averageDaysBetweenPurchases: averageDaysBetweenPurchases,
      estimatedMonthlyMinor: estimatedMonthlyMinor,
      categoryId: resolvedCategoryId,
      categoryName: resolvedCategoryName,
      categoryColor: resolvedCategoryColor,
    );
  }

  static List<ItemMerchantStats> _finalizeMerchantStats(
    Iterable<_MerchantPriceAcc> accs,
  ) {
    final list = accs.toList();
    if (list.isEmpty) return const [];
    // Sortiraj po prosečnoj jediničnoj ceni rastuće (najpovoljniji prvi).
    list.sort((a, b) {
      final byAvg = a.avgUnitPriceMinor.compareTo(b.avgUnitPriceMinor);
      if (byAvg != 0) return byAvg;
      return b.totalMinor.compareTo(a.totalMinor);
    });
    final cheapestAvg = list.first.avgUnitPriceMinor;
    final markCheapest = list.length >= 2 && cheapestAvg > 0;
    return [
      for (final a in list)
        ItemMerchantStats(
          merchantId: a.merchantId,
          merchantName: a.merchantName,
          totalMinor: a.totalMinor,
          purchaseCount: a.purchaseCount,
          minUnitPriceMinor: a.minUnitPriceMinor,
          avgUnitPriceMinor: a.avgUnitPriceMinor,
          maxUnitPriceMinor: a.maxUnitPriceMinor,
          latestUnitPriceMinor: a.latestUnitPriceMinor,
          isCheapest: markCheapest && a.avgUnitPriceMinor == cheapestAvg,
        ),
    ];
  }

  static final RegExp _measureRegex =
      RegExp(r'^(\d+(?:\.\d+)?)\s*(L|ML|KG|G)$', caseSensitive: false);

  /// Parsira oznaku mere (npr. "0.5L", "1.5L", "200G", "1KG") u osnovnu
  /// jedinicu ("1L" ili "1kg") i koeficijent.
  static (double amountInBase, String baseUnitLabel)? _parseMeasureToBaseUnit(
    String measureKey,
  ) {
    final match = _measureRegex.firstMatch(measureKey.trim());
    if (match == null) return null;
    final val = double.tryParse(match.group(1)!);
    if (val == null || val <= 0) return null;
    final unit = match.group(2)!.toUpperCase();
    switch (unit) {
      case 'L':
        return (val, '1L');
      case 'ML':
        return (val / 1000.0, '1L');
      case 'KG':
        return (val, '1kg');
      case 'G':
        return (val / 1000.0, '1kg');
      default:
        return null;
    }
  }

  static List<ItemMeasureComparison> _buildMeasureComparisons(
    Map<String, List<PricePoint>> priceHistoryByMeasure,
  ) {
    final raw = <ItemMeasureComparison>[];
    for (final entry in priceHistoryByMeasure.entries) {
      final mKey = entry.key;
      final points = entry.value;
      if (mKey.isEmpty || points.isEmpty) continue;
      final parsed = _parseMeasureToBaseUnit(mKey);
      if (parsed == null) continue;
      final (baseAmount, baseUnitLabel) = parsed;
      final sumUnit =
          points.fold<int>(0, (acc, p) => acc + p.unitPriceMinor);
      final avgUnit = (sumUnit / points.length).round();
      if (avgUnit <= 0) continue;
      final normalized = (avgUnit / baseAmount).round();
      raw.add(
        ItemMeasureComparison(
          measureLabel: mKey,
          baseUnitLabel: baseUnitLabel,
          avgUnitPriceMinor: avgUnit,
          normalizedPricePerBaseMinor: normalized,
          purchaseCount: points.length,
        ),
      );
    }
    if (raw.isEmpty) return const [];

    // Pronađi najnižu normalizovanu cenu po svakoj osnovnoj jedinici ("1L" / "1kg").
    final minByBase = <String, int>{};
    final countByBase = <String, int>{};
    for (final item in raw) {
      countByBase[item.baseUnitLabel] =
          (countByBase[item.baseUnitLabel] ?? 0) + 1;
      final currentMin = minByBase[item.baseUnitLabel];
      if (currentMin == null || item.normalizedPricePerBaseMinor < currentMin) {
        minByBase[item.baseUnitLabel] = item.normalizedPricePerBaseMinor;
      }
    }

    raw.sort((a, b) => a.normalizedPricePerBaseMinor
        .compareTo(b.normalizedPricePerBaseMinor));

    return [
      for (final item in raw)
        ItemMeasureComparison(
          measureLabel: item.measureLabel,
          baseUnitLabel: item.baseUnitLabel,
          avgUnitPriceMinor: item.avgUnitPriceMinor,
          normalizedPricePerBaseMinor: item.normalizedPricePerBaseMinor,
          purchaseCount: item.purchaseCount,
          isBestValue: (countByBase[item.baseUnitLabel] ?? 0) >= 2 &&
              item.normalizedPricePerBaseMinor ==
                  minByBase[item.baseUnitLabel],
        ),
    ];
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

  /// Artikli jedne kategorije (grupisano po kanonskom nazivu), za drill-down iz
  /// analitike. `categoryId = 0` znači „bez kategorije" (NULL u bazi) —
  /// isti sentinel kao u [_byCategory].
  Future<List<TopItem>> categoryItems(
    int categoryId,
    AnalyticsRange range, {
    DateTime? now,
    Currency? currency,
  }) async {
    await _normalizer.ensureNormalized();
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
    final ci = _db.canonicalItems;
    final total = li.total.sum();
    final cnt = li.id.count();
    final canonicalNameExpr = coalesce<String>([ci.displayName, li.name]);

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
      leftOuterJoin(ci, ci.id.equalsExp(li.canonicalItemId)),
    ])
      ..addColumns([canonicalNameExpr, ci.id, total, cnt])
      ..where(filter)
      ..groupBy([canonicalNameExpr])
      ..orderBy([OrderingTerm(expression: total, mode: OrderingMode.desc)]);
    if (limit != null) q.limit(limit);

    final rows = await q.get();
    return rows
        .map((row) => TopItem(
              name: row.read(canonicalNameExpr) ?? '',
              totalMinor: row.read(total) ?? 0,
              count: row.read(cnt) ?? 0,
              canonicalItemId: row.read(ci.id),
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
          '(SELECT count(*) FROM categories) AS c, '
          '(SELECT count(*) FROM canonical_items) AS ci',
          readsFrom: {
            _db.receipts,
            _db.lineItems,
            _db.merchants,
            _db.categories,
            _db.companies,
            _db.canonicalItems,
            _db.itemAliases,
          },
        )
        .watch();
    return trigger.asyncMap((_) => loadAdvancedSummary(filter, now: now));
  }

  /// Učitava sveobuhvatan izveštaj napredne analitike za zadati filter.
  Future<AdvancedAnalyticsSummary> loadAdvancedSummary(
    AdvancedAnalyticsFilter filter, {
    DateTime? now,
  }) async {
    await _normalizer.ensureNormalized();
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

    // 10. Po firmama kupca (PIB) — nezavisno od filtera poslovno/lično.
    final companySpending = await _byCompany(_advancedFilterExpr(
        from, to, filter.copyWith(businessFilter: AnalyticsBusinessFilter.all)));

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
      companySpending: companySpending,
    );
  }

  /// Poslovni računi grupisani po firmi kupca (zemlja + PIB), sa procenjenim
  /// PDV-om iz stavki. Poslovni računi bez PIB-a idu u jedan red (taxId null).
  Future<List<CompanySpending>> _byCompany(Expression<bool> filter) async {
    final r = _db.receipts;
    final li = _db.lineItems;
    final where = filter & r.isBusiness.equals(true);
    final countryExpr = r.country.dartCast<int>();

    final total = r.totalAmount.sum();
    final cnt = r.id.count();
    final q = _db.selectOnly(r)
      ..addColumns([countryExpr, r.buyerTaxId, total, cnt])
      ..where(where)
      ..groupBy([countryExpr, r.buyerTaxId])
      ..orderBy([OrderingTerm(expression: total, mode: OrderingMode.desc)]);
    final rows = await q.get();
    if (rows.isEmpty) return const [];

    // PDV po firmi: isti obračun kao _loadTaxBreakdown (bruto → osnovica).
    final vatQ = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
    ])
      ..addColumns([countryExpr, r.buyerTaxId, li.total, li.taxRate])
      ..where(where & li.isUnparsed.equals(false) & li.taxRate.isNotNull());
    final vatByKey = <(int, String?), int>{};
    for (final row in await vatQ.get()) {
      final rate = row.read(li.taxRate)!;
      final itemTotal = row.read(li.total) ?? 0;
      final key = (row.read(countryExpr) ?? 0, row.read(r.buyerTaxId));
      final vat = itemTotal - (itemTotal / (1 + rate / 100)).round();
      vatByKey[key] = (vatByKey[key] ?? 0) + vat;
    }

    final names = <(int, String), String>{};
    for (final c in await _db.select(_db.companies).get()) {
      if (c.name != null) names[(c.country.index, c.taxId)] = c.name!;
    }

    return rows.map((row) {
      final countryIdx = row.read(countryExpr) ?? 0;
      final taxId = row.read(r.buyerTaxId);
      return CompanySpending(
        country: Country.values[countryIdx],
        taxId: taxId,
        name: taxId == null ? null : names[(countryIdx, taxId)],
        totalMinor: row.read(total) ?? 0,
        receiptCount: row.read(cnt) ?? 0,
        vatMinor: vatByKey[(countryIdx, taxId)] ?? 0,
      );
    }).toList();
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
    final ci = _db.canonicalItems;
    final canonicalNameExpr = coalesce<String>([ci.displayName, li.name]);

    final filter = r.fetchStatus.equalsValue(FetchStatus.invalid).not() &
        _currencyFilter(currency) &
        li.isUnparsed.equals(false) &
        li.unitPrice.isBiggerThanValue(0) &
        r.pfrTime.isNotNull();

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
      leftOuterJoin(ci, ci.id.equalsExp(li.canonicalItemId)),
    ])
      ..addColumns([canonicalNameExpr, li.extractedMeasure, r.pfrTime, li.unitPrice])
      ..where(filter)
      ..orderBy([
        OrderingTerm(expression: canonicalNameExpr),
        OrderingTerm(expression: r.pfrTime),
      ]);

    final rows = await q.get();
    // Grupisanje po (kanonskiNaziv, ekstrahovanaMera) kako ne bismo poredili
    // jediničnu cenu pakovanja od 0.5L i 1L kao lažnu inflaciju.
    final itemMap = <String, List<PricePoint>>{};
    for (final row in rows) {
      final baseName = row.read(canonicalNameExpr);
      final measure = (row.read(li.extractedMeasure) ?? '').trim().toUpperCase();
      final date = row.read(r.pfrTime);
      final price = row.read(li.unitPrice);
      if (baseName != null && date != null && price != null && price > 0) {
        final key = measure.isNotEmpty &&
                !baseName.toUpperCase().contains(measure)
            ? '$baseName ($measure)'
            : baseName;
        itemMap.putIfAbsent(key, () => []).add(
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

  // ==========================================
  // RUČNO SPAJANJE ARTIKALA (HUMAN-IN-THE-LOOP)
  // ==========================================

  /// Vraća sve kanonske artikle koji imaju makar jednu stavku na računima
  /// (osim [excludeCanonicalId]), sortirane po broju kupovina ili nazivu.
  Future<List<CanonicalItemRow>> canonicalItemsForMerge({
    int? excludeCanonicalId,
  }) async {
    await _normalizer.ensureNormalized();
    final ci = _db.canonicalItems;
    final li = _db.lineItems;

    final cnt = li.id.count();
    final q = _db.select(ci).join([
      innerJoin(li, li.canonicalItemId.equalsExp(ci.id)),
    ])
      ..addColumns([cnt])
      ..where(
        excludeCanonicalId != null
            ? ci.id.equals(excludeCanonicalId).not()
            : const Constant(true),
      )
      ..groupBy([ci.id])
      ..orderBy([
        OrderingTerm(expression: cnt, mode: OrderingMode.desc),
        OrderingTerm(expression: ci.displayName),
      ]);

    final rows = await q.get();
    return rows.map((r) => r.readTable(ci)).toList();
  }

  /// Ručno spaja [sourceCanonicalIds] u [targetCanonicalId] (opciono uz promenu
  /// prikaza kanonskog naziva [customDisplayName]) i trajno pamti alijase.
  Future<void> mergeCanonicalItems({
    required int targetCanonicalId,
    required List<int> sourceCanonicalIds,
    String? customDisplayName,
  }) {
    return _normalizer.mergeCanonicalItems(
      targetCanonicalId: targetCanonicalId,
      sourceCanonicalIds: sourceCanonicalIds,
      customDisplayName: customDisplayName,
    );
  }

  /// Izdvaja jednu sirovu varijantu ([rawName]) iz kanonskog artikla
  /// [canonicalItemId] u novi zaseban kanonski artikal.
  Future<String> unmergeRawVariant({
    required int canonicalItemId,
    required String rawName,
  }) {
    return _normalizer.unmergeRawVariant(
      canonicalItemId: canonicalItemId,
      rawName: rawName,
    );
  }

  // ==========================================
  // KATALOG ARTIKALA (MODUL 2)
  // ==========================================

  /// Vraća kompletan katalog svih kanonskih artikala u zadatom periodu i valuti,
  /// sa spojenim sirovim varijantama, kategorijama i procentom promene cene.
  Future<List<CatalogItemSummary>> catalogItems(
    AnalyticsRange range, {
    DateTime? now,
    Currency? currency,
  }) async {
    await _normalizer.ensureNormalized();
    final since = _since(range, now ?? DateTime.now());
    final r = _db.receipts;
    final li = _db.lineItems;
    final ci = _db.canonicalItems;
    final cat = _db.categories;

    final filter =
        _validAnd(since, currency: currency) & li.isUnparsed.equals(false);

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
      leftOuterJoin(ci, ci.id.equalsExp(li.canonicalItemId)),
      leftOuterJoin(cat, cat.id.equalsExp(li.categoryId)),
    ])
      ..addColumns([
        ci.id,
        ci.displayName,
        li.name,
        li.quantity,
        li.unitPrice,
        li.total,
        li.extractedMeasure,
        r.pfrTime,
        r.createdAt,
        cat.id,
        cat.name,
        cat.color,
      ])
      ..where(filter)
      ..orderBy([
        OrderingTerm(expression: r.pfrTime),
        OrderingTerm(expression: r.createdAt),
      ]);

    final rows = await q.get();
    final byCanonicalName = <String, _CatalogItemAcc>{};

    for (final row in rows) {
      final rawName = row.read(li.name) ?? '';
      final canonicalName = row.read(ci.displayName) ?? rawName;
      if (canonicalName.isEmpty) continue;

      final acc = byCanonicalName.putIfAbsent(
        canonicalName,
        () => _CatalogItemAcc(
          name: canonicalName,
          canonicalItemId: row.read(ci.id),
        ),
      );
      acc.canonicalItemId ??= row.read(ci.id);

      final lineTotal = row.read(li.total) ?? 0;
      final lineQty = row.read(li.quantity) ?? 1.0;
      final unitPrice = row.read(li.unitPrice) ?? 0;
      final measureKey =
          (row.read(li.extractedMeasure) ?? '').trim().toUpperCase();

      acc.totalMinor += lineTotal;
      acc.purchaseCount += 1;
      acc.totalQuantity += lineQty;
      if (rawName.isNotEmpty) acc.rawVariants.add(rawName);

      final catId = row.read(cat.id);
      if (catId != null) {
        acc.categoryId = catId;
        acc.categoryName = row.read(cat.name);
        acc.categoryColor = row.read(cat.color);
      }

      if (unitPrice > 0) {
        acc.pricesByMeasure.putIfAbsent(measureKey, () => []).add(unitPrice);
        acc.latestUnitPriceMinor = unitPrice;
      }
    }

    final result = <CatalogItemSummary>[];
    for (final acc in byCanonicalName.values) {
      if (acc.totalMinor <= 0) continue;

      // Izračunaj promenu cene unutar najzastupljenije jedinice mere (kako ne
      // bismo poredili 0.5L i 1.5L kao poskupljenje).
      double? priceChangePct;
      int? latestUnitPrice = acc.latestUnitPriceMinor;
      if (acc.pricesByMeasure.isNotEmpty) {
        final sortedMeasures = acc.pricesByMeasure.entries.toList()
          ..sort((a, b) {
            final byLen = b.value.length.compareTo(a.value.length);
            if (byLen != 0) return byLen;
            if (a.key.isNotEmpty && b.key.isEmpty) return -1;
            if (a.key.isEmpty && b.key.isNotEmpty) return 1;
            return a.key.compareTo(b.key);
          });
        final dominantPrices = sortedMeasures.first.value;
        if (dominantPrices.isNotEmpty) {
          latestUnitPrice = dominantPrices.last;
          if (dominantPrices.length >= 2 && dominantPrices.first > 0) {
            final firstP = dominantPrices.first;
            final lastP = dominantPrices.last;
            priceChangePct = ((lastP - firstP) / firstP) * 100.0;
          }
        }
      }

      final sortedVariants = acc.rawVariants.toList()..sort();
      result.add(
        CatalogItemSummary(
          name: acc.name,
          canonicalItemId: acc.canonicalItemId,
          totalMinor: acc.totalMinor,
          purchaseCount: acc.purchaseCount,
          totalQuantity: acc.totalQuantity,
          rawVariants: sortedVariants,
          categoryId: acc.categoryId,
          categoryName: acc.categoryName,
          categoryColor: acc.categoryColor,
          latestUnitPriceMinor: latestUnitPrice,
          priceChangePercent: priceChangePct,
        ),
      );
    }

    result.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return result;
  }
}

class _MerchantPriceAcc {
  _MerchantPriceAcc(this.merchantId, this.merchantName);

  final int merchantId;
  final String merchantName;
  int totalMinor = 0;
  int purchaseCount = 0;
  int minUnitPriceMinor = 0;
  int maxUnitPriceMinor = 0;
  int latestUnitPriceMinor = 0;
  int _sumUnitPrices = 0;

  void add({required int unitPrice, required int lineTotal}) {
    totalMinor += lineTotal;
    purchaseCount += 1;
    _sumUnitPrices += unitPrice;
    if (minUnitPriceMinor == 0 || unitPrice < minUnitPriceMinor) {
      minUnitPriceMinor = unitPrice;
    }
    if (unitPrice > maxUnitPriceMinor) {
      maxUnitPriceMinor = unitPrice;
    }
    latestUnitPriceMinor = unitPrice;
  }

  int get avgUnitPriceMinor =>
      purchaseCount == 0 ? 0 : (_sumUnitPrices / purchaseCount).round();
}

class _CatalogItemAcc {
  _CatalogItemAcc({required this.name, this.canonicalItemId});

  final String name;
  int? canonicalItemId;
  int totalMinor = 0;
  int purchaseCount = 0;
  double totalQuantity = 0;
  final Set<String> rawVariants = <String>{};
  int? categoryId;
  String? categoryName;
  String? categoryColor;
  int? latestUnitPriceMinor;
  final Map<String, List<int>> pricesByMeasure = <String, List<int>>{};
}

