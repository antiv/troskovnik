/// Modeli rezultata analitike potrošnje (agregacije nad postojećim podacima).
///
/// Svi iznosi su u para (1/100 RSD), kao i u ostatku baze.
library;

/// Potrošnja u jednom kalendarskom mesecu.
class MonthlySpending {
  const MonthlySpending({
    required this.year,
    required this.month,
    required this.totalMinor,
    required this.receiptCount,
  });

  final int year;
  final int month; // 1..12
  final int totalMinor;
  final int receiptCount;
}

/// Potrošnja kod jednog prodavca.
class MerchantSpending {
  const MerchantSpending({
    required this.merchantId,
    required this.merchantName,
    required this.totalMinor,
    required this.receiptCount,
  });

  final int merchantId;
  final String merchantName;
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

/// Najčešći/najskuplji artikal (po nazivu, bez kategorija — MVP).
class TopItem {
  const TopItem({
    required this.name,
    required this.totalMinor,
    required this.count,
  });

  final String name;
  final int totalMinor;
  final int count;
}

/// Zbirni pregled analitike za izabrani period.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalMinor,
    required this.receiptCount,
    required this.estimatedVatMinor,
    required this.monthly,
    required this.byMerchant,
    required this.businessSplit,
    required this.topItems,
  });

  final int totalMinor;
  final int receiptCount;

  /// Procenjen PDV iz stavki koje imaju poresku stopu (samo računi sa
  /// strukturiranim stavkama — prikazati kao procenu, ne kao tačan iznos).
  final int estimatedVatMinor;

  final List<MonthlySpending> monthly;
  final List<MerchantSpending> byMerchant;
  final BusinessSplit businessSplit;
  final List<TopItem> topItems;

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

/// Detalji za jedan artikal (po nazivu) — drill-down iz analitike.
class ItemDetail {
  const ItemDetail({
    required this.name,
    required this.totalMinor,
    required this.purchaseCount,
    required this.totalQuantity,
    required this.priceHistory,
    required this.byMerchant,
  });

  final String name;
  final int totalMinor;
  final int purchaseCount;
  final double totalQuantity;
  final List<PricePoint> priceHistory;
  final List<MerchantSpending> byMerchant;
}

/// Opseg perioda za filtriranje analitike.
enum AnalyticsRange {
  last3Months,
  last12Months,
  all,
}
