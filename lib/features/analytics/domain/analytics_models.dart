/// Modeli rezultata analitike potrošnje (agregacije nad postojećim podacima).
///
/// Svi iznosi su u minor jedinicama (para/fening, 1/100 osnovne valute).
/// Valute se NIKAD ne sabiraju — svaki model nosi svoju valutu.
library;

import '../../../core/domain/currency.dart';
import '../../categories/domain/category_models.dart';

/// Potrošnja u jednom kalendarskom mesecu (po valuti).
class MonthlySpending {
  const MonthlySpending({
    required this.year,
    required this.month,
    required this.totalMinor,
    required this.receiptCount,
    this.currency = Currency.rsd,
  });

  final int year;
  final int month; // 1..12
  final int totalMinor;
  final int receiptCount;
  final Currency currency;
}

/// Potrošnja kod jednog prodavca (po valuti).
class MerchantSpending {
  const MerchantSpending({
    required this.merchantId,
    required this.merchantName,
    required this.totalMinor,
    required this.receiptCount,
    this.currency = Currency.rsd,
  });

  final int merchantId;
  final String merchantName;
  final int totalMinor;
  final int receiptCount;
  final Currency currency;
}

/// Potrošnja po jednom načinu plaćanja (uklj. kombinovano — iznos je deo
/// pripisan baš tom načinu).
class PaymentMethodSpending {
  const PaymentMethodSpending({
    required this.method,
    required this.totalMinor,
    required this.receiptCount,
  });

  final String method;
  final int totalMinor;
  final int receiptCount;
}

/// Podela poslovno vs. lično.
class BusinessSplit {
  const BusinessSplit({
    required this.businessMinor,
    required this.personalMinor,
  });

  final int businessMinor;
  final int personalMinor;

  int get totalMinor => businessMinor + personalMinor;
}

/// Najčešći/najskuplji artikal (po kanonskom nazivu).
class TopItem {
  const TopItem({
    required this.name,
    required this.totalMinor,
    required this.count,
    this.canonicalItemId,
  });

  final String name;
  final int totalMinor;
  final int count;
  final int? canonicalItemId;
}

/// Zbirni pregled analitike za izabrani period.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalsByCurrency,
    required this.receiptCount,
    required this.estimatedVatMinor,
    required this.monthly,
    required this.byMerchant,
    required this.businessSplit,
    required this.byPaymentMethod,
    required this.topItems,
    required this.byCategory,
    this.totalUniqueItemsCount = 0,
  });

  /// Ukupan iznos po valuti — nikad se ne sabiraju različite valute.
  final Map<Currency, int> totalsByCurrency;
  final int receiptCount;

  /// Procenjen PDV iz stavki koje imaju poresku stopu (samo računi sa
  /// strukturiranim stavkama — prikazati kao procenu, ne kao tačan iznos).
  final int estimatedVatMinor;

  final List<MonthlySpending> monthly;
  final List<MerchantSpending> byMerchant;
  final BusinessSplit businessSplit;
  final List<PaymentMethodSpending> byPaymentMethod;
  final List<TopItem> topItems;
  final List<CategorySpending> byCategory;

  /// Ukupan broj jedinstvenih kanonskih artikala u izabranom periodu i valuti.
  final int totalUniqueItemsCount;

  bool get isEmpty => receiptCount == 0;
}

/// Detalji za jednog prodavca (drill-down iz analitike).
class MerchantDetail {
  const MerchantDetail({
    required this.merchantName,
    required this.totalMinor,
    required this.receiptCount,
    required this.monthly,
    required this.topItems,
  });

  final String merchantName;
  final int totalMinor;
  final int receiptCount;
  final List<MonthlySpending> monthly;
  final List<TopItem> topItems;

  /// Prosečan iznos po računu (u para).
  int get averageMinor =>
      receiptCount == 0 ? 0 : (totalMinor / receiptCount).round();
}

/// Jedna tačka u istoriji jedinične cene artikla.
class PricePoint {
  const PricePoint({required this.date, required this.unitPriceMinor});

  final DateTime date;
  final int unitPriceMinor;
}

/// Statistika cena jednog artikla kod konkretnog prodavca ("Gde je najjeftinije").
class ItemMerchantStats {
  const ItemMerchantStats({
    required this.merchantId,
    required this.merchantName,
    required this.totalMinor,
    required this.purchaseCount,
    required this.minUnitPriceMinor,
    required this.avgUnitPriceMinor,
    required this.maxUnitPriceMinor,
    required this.latestUnitPriceMinor,
    this.isCheapest = false,
  });

  final int merchantId;
  final String merchantName;
  final int totalMinor;
  final int purchaseCount;
  final int minUnitPriceMinor;
  final int avgUnitPriceMinor;
  final int maxUnitPriceMinor;
  final int latestUnitPriceMinor;
  final bool isCheapest;
}

/// Poređenje isplativosti različitih pakovanja istog artikla (cena po 1L ili 1kg).
class ItemMeasureComparison {
  const ItemMeasureComparison({
    required this.measureLabel,
    required this.baseUnitLabel,
    required this.avgUnitPriceMinor,
    required this.normalizedPricePerBaseMinor,
    required this.purchaseCount,
    this.isBestValue = false,
  });

  final String measureLabel;
  final String baseUnitLabel; // "1L" ili "1kg"
  final int avgUnitPriceMinor;
  final int normalizedPricePerBaseMinor;
  final int purchaseCount;
  final bool isBestValue;
}

/// Pojedinačna kupovina artikla (za prikaz poslednjih kupovina i otvaranje računa).
class ItemPurchaseRecord {
  const ItemPurchaseRecord({
    required this.receiptId,
    required this.date,
    required this.merchantName,
    required this.rawItemName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.totalMinor,
    this.extractedMeasure,
  });

  final int receiptId;
  final DateTime? date;
  final String merchantName;
  final String rawItemName;
  final double quantity;
  final int unitPriceMinor;
  final int totalMinor;
  final String? extractedMeasure;
}

/// Stavka u punom katalogu artikala (Modul 2: pretraga, sortiranje, kategorije).
class CatalogItemSummary {
  const CatalogItemSummary({
    required this.name,
    required this.totalMinor,
    required this.purchaseCount,
    required this.totalQuantity,
    this.canonicalItemId,
    this.rawVariants = const [],
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.latestUnitPriceMinor,
    this.priceChangePercent,
  });

  final String name;
  final int? canonicalItemId;
  final int totalMinor;
  final int purchaseCount;
  final double totalQuantity;
  final List<String> rawVariants;
  final int? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final int? latestUnitPriceMinor;
  final double? priceChangePercent;
}

/// Detalji za jedan artikal (po kanonskom nazivu) — drill-down iz analitike.
class ItemDetail {
  const ItemDetail({
    required this.name,
    required this.totalMinor,
    required this.purchaseCount,
    required this.totalQuantity,
    required this.priceHistory,
    required this.byMerchant,
    this.canonicalItemId,
    this.rawVariants = const [],
    this.priceHistoryByMeasure = const {},
    this.merchantStatsByMeasure = const {},
    this.overallMerchantStats = const [],
    this.measureComparisons = const [],
    this.recentPurchases = const [],
    this.averageDaysBetweenPurchases,
    this.estimatedMonthlyMinor,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
  });

  final String name;
  final int totalMinor;
  final int purchaseCount;
  final double totalQuantity;
  final List<PricePoint> priceHistory;
  final List<MerchantSpending> byMerchant;
  final int? canonicalItemId;

  /// Različiti sirovi nazivi sa fiskalnih računa koji su spojeni u ovaj kanonski artikal.
  final List<String> rawVariants;

  /// Istorija jedinične cene odvojena po pakovanju/jedinici mere (npr. "1L", "0.5L"),
  /// kako se ne bi mešale cene različitih gramaža istog proizvoda.
  final Map<String, List<PricePoint>> priceHistoryByMeasure;

  /// Statistika cena po prodavcima za svaku pojedinačnu veličinu pakovanja (ključ = mera).
  final Map<String, List<ItemMerchantStats>> merchantStatsByMeasure;

  /// Zbirna statistika cena po prodavcima (preko svih kupovina ili dominantne mere).
  final List<ItemMerchantStats> overallMerchantStats;

  /// Poređenje isplativosti pakovanja (cena svedena na 1L ili 1kg).
  final List<ItemMeasureComparison> measureComparisons;

  /// Poslednje kupovine ovog artikla (sortirano od najnovije).
  final List<ItemPurchaseRecord> recentPurchases;

  /// Prosečan broj dana između kupovina (ako postoje bar 2 kupovine u rasponu >= 3 dana).
  final int? averageDaysBetweenPurchases;

  /// Procenjena mesečna potrošnja na ovaj artikal (u minor jedinicama).
  final int? estimatedMonthlyMinor;

  final int? categoryId;
  final String? categoryName;
  final String? categoryColor;
}

/// Opseg perioda za filtriranje analitike.
enum AnalyticsRange {
  last3Months,
  last12Months,
  all,
}

