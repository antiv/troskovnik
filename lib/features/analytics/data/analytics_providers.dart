import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/domain/currency.dart';
import '../domain/analytics_models.dart';
import 'analytics_repository.dart';

/// Izabrana valuta za prikaz analitike. `null` = prikazuje prvu dostupnu.
class AnalyticsCurrencyNotifier extends Notifier<Currency?> {
  @override
  Currency? build() => null;

  void set(Currency? c) => state = c;
}

final analyticsCurrencyProvider =
    NotifierProvider<AnalyticsCurrencyNotifier, Currency?>(
        AnalyticsCurrencyNotifier.new);

/// Izabrani period analitike.
class AnalyticsRangeNotifier extends Notifier<AnalyticsRange> {
  @override
  AnalyticsRange build() => AnalyticsRange.last12Months;

  void set(AnalyticsRange range) => state = range;
}

final analyticsRangeProvider =
    NotifierProvider<AnalyticsRangeNotifier, AnalyticsRange>(
        AnalyticsRangeNotifier.new);

final analyticsRepositoryProvider =
    FutureProvider<AnalyticsRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return AnalyticsRepository(db);
});

/// Reaktivni sažetak analitike za izabrani period.
final analyticsSummaryProvider =
    StreamProvider<AnalyticsSummary>((ref) async* {
  final repo = await ref.watch(analyticsRepositoryProvider.future);
  final range = ref.watch(analyticsRangeProvider);
  yield* repo.watchSummary(range);
});

/// Detalji za jednog prodavca (drill-down), za trenutno izabrani period.
final merchantDetailProvider =
    FutureProvider.family<MerchantDetail, int>((ref, merchantId) async {
  final repo = await ref.watch(analyticsRepositoryProvider.future);
  final range = ref.watch(analyticsRangeProvider);
  return repo.merchantDetail(merchantId, range);
});

/// Detalji za jedan artikal (po nazivu) (drill-down), za izabrani period.
final itemDetailProvider =
    FutureProvider.family<ItemDetail, String>((ref, name) async {
  final repo = await ref.watch(analyticsRepositoryProvider.future);
  final range = ref.watch(analyticsRangeProvider);
  return repo.itemDetail(name, range);
});
