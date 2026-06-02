import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../domain/analytics_models.dart';
import 'analytics_repository.dart';

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
