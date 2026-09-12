import '../../../core/domain/currency.dart';
import '../../categories/domain/category_models.dart';
import 'analytics_models.dart';

/// Predefinisani periodi za naprednu analitiku.
enum AdvancedAnalyticsDatePreset {
  thisMonth,
  lastMonth,
  last30Days,
  last90Days,
  thisYear,
  lastYear,
  all,
  custom,
}

/// Filter poslovnih/ličnih računa.
enum AnalyticsBusinessFilter {
  all,
  personalOnly,
  businessOnly,
}

/// Filter stanje za naprednu analitiku.
class AdvancedAnalyticsFilter {
  const AdvancedAnalyticsFilter({
    this.preset = AdvancedAnalyticsDatePreset.thisMonth,
    this.customFrom,
    this.customTo,
    this.businessFilter = AnalyticsBusinessFilter.all,
    this.currency = Currency.rsd,
    this.categoryId,
  });

  final AdvancedAnalyticsDatePreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final AnalyticsBusinessFilter businessFilter;
  final Currency currency;
  final int? categoryId;

  AdvancedAnalyticsFilter copyWith({
    AdvancedAnalyticsDatePreset? preset,
    DateTime? customFrom,
    DateTime? customTo,
    AnalyticsBusinessFilter? businessFilter,
    Currency? currency,
    int? categoryId,
    bool clearCategory = false,
  }) {
    return AdvancedAnalyticsFilter(
      preset: preset ?? this.preset,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
      businessFilter: businessFilter ?? this.businessFilter,
      currency: currency ?? this.currency,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }
}

/// Poređenje mesec-na-mesec (MoM).
class MonthOverMonthComparison {
  const MonthOverMonthComparison({
    required this.currentYear,
    required this.currentMonth,
    required this.currentTotalMinor,
    required this.currentReceiptCount,
    required this.previousYear,
    required this.previousMonth,
    required this.previousTotalMinor,
    required this.previousReceiptCount,
  });

  final int currentYear;
  final int currentMonth;
  final int currentTotalMinor;
  final int currentReceiptCount;

  final int previousYear;
  final int previousMonth;
  final int previousTotalMinor;
  final int previousReceiptCount;

  int get deltaMinor => currentTotalMinor - previousTotalMinor;
  int get receiptCountDelta => currentReceiptCount - previousReceiptCount;

  /// Procentualna promena potrošnje (npr. +12.5% ili -4.2%). Null ako je prethodni 0.
  double? get percentageChange {
    if (previousTotalMinor == 0) return null;
    return ((currentTotalMinor - previousTotalMinor) / previousTotalMinor) * 100.0;
  }
}

/// Tačka kumulativne dnevne potrošnje za poređenje tempa (pacing).
class SpendingPacingPoint {
  const SpendingPacingPoint({
    required this.day,
    required this.currentCumulativeMinor,
    this.previousCumulativeMinor,
  });

  final int day; // 1..31
  final int currentCumulativeMinor;
  final int? previousCumulativeMinor;
}

/// Potrošnja po danu u nedelji.
class DayOfWeekSpending {
  const DayOfWeekSpending({
    required this.dayOfWeek, // 1 = Ponedeljak, 7 = Nedelja
    required this.totalMinor,
    required this.receiptCount,
  });

  final int dayOfWeek;
  final int totalMinor;
  final int receiptCount;

  int get averageMinor =>
      receiptCount == 0 ? 0 : (totalMinor / receiptCount).round();
}

/// Potrošnja po dobu dana.
class TimeOfDaySpending {
  const TimeOfDaySpending({
    required this.timeSlot, // 0 = Jutro (06-12), 1 = Popodne (12-18), 2 = Veče (18-24), 3 = Noć (00-06)
    required this.totalMinor,
    required this.receiptCount,
  });

  final int timeSlot;
  final int totalMinor;
  final int receiptCount;
}

/// Distribucija veličine računa (mali, srednji, veliki).
class BasketSizeDistribution {
  const BasketSizeDistribution({
    required this.smallCount,
    required this.smallTotalMinor,
    required this.mediumCount,
    required this.mediumTotalMinor,
    required this.largeCount,
    required this.largeTotalMinor,
  });

  final int smallCount; // < 1.000 RSD
  final int smallTotalMinor;

  final int mediumCount; // 1.000 - 5.000 RSD
  final int mediumTotalMinor;

  final int largeCount; // > 5.000 RSD
  final int largeTotalMinor;

  int get totalCount => smallCount + mediumCount + largeCount;
  int get totalMinor => smallTotalMinor + mediumTotalMinor + largeTotalMinor;
}

/// Mesečni trend potrošnje po kategoriji.
class CategoryTrendPoint {
  const CategoryTrendPoint({
    required this.categoryId,
    required this.categoryName,
    this.color,
    required this.year,
    required this.month,
    required this.totalMinor,
  });

  final int categoryId;
  final String categoryName;
  final String? color;
  final int year;
  final int month;
  final int totalMinor;
}

/// Kategorija sa najvećom promenom u odnosu na prethodni mesec.
class CategoryMover {
  const CategoryMover({
    required this.categoryId,
    required this.categoryName,
    this.color,
    required this.currentTotalMinor,
    required this.previousTotalMinor,
  });

  final int categoryId;
  final String categoryName;
  final String? color;
  final int currentTotalMinor;
  final int previousTotalMinor;

  int get deltaMinor => currentTotalMinor - previousTotalMinor;

  double? get percentageChange {
    if (previousTotalMinor == 0) return null;
    return ((currentTotalMinor - previousTotalMinor) / previousTotalMinor) * 100.0;
  }
}

/// Stavka matrice prodavaca (učestalost vs prosečna korpa).
class MerchantMatrixItem {
  const MerchantMatrixItem({
    required this.merchantId,
    required this.merchantName,
    required this.tin,
    required this.receiptCount,
    required this.totalMinor,
    required this.percentageOfTotal,
  });

  final int merchantId;
  final String merchantName;
  final String tin;
  final int receiptCount;
  final int totalMinor;
  final double percentageOfTotal;

  int get averageBasketMinor =>
      receiptCount == 0 ? 0 : (totalMinor / receiptCount).round();
}

/// Pareto analiza koncentracije prodavaca (npr. Top 3 čine X% budžeta).
class ParetoConcentration {
  const ParetoConcentration({
    required this.top3Percentage,
    required this.top5Percentage,
    required this.top3TotalMinor,
    required this.totalSpendMinor,
  });

  final double top3Percentage;
  final double top5Percentage;
  final int top3TotalMinor;
  final int totalSpendMinor;
}

/// Praćenje kretanja cene pojedinačnog artikla (inflacija / poskupljenje).
class ItemPriceInflation {
  const ItemPriceInflation({
    required this.name,
    required this.firstPriceMinor,
    required this.latestPriceMinor,
    required this.minPriceMinor,
    required this.maxPriceMinor,
    required this.firstDate,
    required this.latestDate,
    required this.purchaseCount,
  });

  final String name;
  final int firstPriceMinor;
  final int latestPriceMinor;
  final int minPriceMinor;
  final int maxPriceMinor;
  final DateTime firstDate;
  final DateTime latestDate;
  final int purchaseCount;

  int get deltaMinor => latestPriceMinor - firstPriceMinor;

  double get percentChange {
    if (firstPriceMinor == 0) return 0.0;
    return ((latestPriceMinor - firstPriceMinor) / firstPriceMinor) * 100.0;
  }
}

/// Obračun poreza / PDV po poreskoj stopi.
class TaxRateBreakdown {
  const TaxRateBreakdown({
    required this.taxRate,
    this.taxLabel,
    required this.taxableBaseMinor,
    required this.vatMinor,
    required this.totalMinor,
  });

  final double taxRate;
  final String? taxLabel;
  final int taxableBaseMinor;
  final int vatMinor;
  final int totalMinor;
}

/// Zbirni model napredne analitike.
class AdvancedAnalyticsSummary {
  const AdvancedAnalyticsSummary({
    required this.totalMinor,
    required this.receiptCount,
    required this.averageReceiptMinor,
    this.momComparison,
    required this.pacing,
    required this.dayOfWeek,
    required this.timeOfDay,
    required this.basketSizes,
    required this.categorySpending,
    required this.categoryTrends,
    required this.categoryMovers,
    required this.merchantMatrix,
    required this.pareto,
    required this.priceInflation,
    required this.taxBreakdown,
    required this.businessSplit,
  });

  final int totalMinor;
  final int receiptCount;
  final int averageReceiptMinor;
  final MonthOverMonthComparison? momComparison;
  final List<SpendingPacingPoint> pacing;
  final List<DayOfWeekSpending> dayOfWeek;
  final List<TimeOfDaySpending> timeOfDay;
  final BasketSizeDistribution basketSizes;
  final List<CategorySpending> categorySpending;
  final List<CategoryTrendPoint> categoryTrends;
  final List<CategoryMover> categoryMovers;
  final List<MerchantMatrixItem> merchantMatrix;
  final ParetoConcentration pareto;
  final List<ItemPriceInflation> priceInflation;
  final List<TaxRateBreakdown> taxBreakdown;
  final BusinessSplit businessSplit;

  bool get isEmpty => receiptCount == 0;
}
