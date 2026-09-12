import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/currency.dart';
import '../domain/advanced_analytics_models.dart';
import '../domain/analytics_models.dart';
import 'analytics_providers.dart';

/// Notifier za filter napredne analitike.
class AdvancedAnalyticsFilterNotifier extends Notifier<AdvancedAnalyticsFilter> {
  @override
  AdvancedAnalyticsFilter build() {
    final currency = ref.watch(analyticsCurrencyProvider).value ?? Currency.rsd;
    final range = ref.watch(analyticsRangeProvider);
    final preset = switch (range) {
      AnalyticsRange.all => AdvancedAnalyticsDatePreset.all,
      AnalyticsRange.last12Months => AdvancedAnalyticsDatePreset.all,
      AnalyticsRange.last3Months => AdvancedAnalyticsDatePreset.last90Days,
    };
    return AdvancedAnalyticsFilter(
      preset: preset,
      currency: currency,
    );
  }

  void setPreset(AdvancedAnalyticsDatePreset preset) {
    state = state.copyWith(preset: preset);
  }

  void setCustomRange(DateTime from, DateTime to) {
    state = state.copyWith(
      preset: AdvancedAnalyticsDatePreset.custom,
      customFrom: from,
      customTo: to,
    );
  }

  void setBusinessFilter(AnalyticsBusinessFilter bf) {
    state = state.copyWith(businessFilter: bf);
  }

  void setCurrency(Currency c) {
    state = state.copyWith(currency: c);
    // Sinhronizuj i sa glavnim pickerom valute.
    ref.read(analyticsCurrencyProvider.notifier).set(c);
  }

  void setCategory(int? categoryId) {
    if (categoryId == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(categoryId: categoryId);
    }
  }
}

final advancedAnalyticsFilterProvider =
    NotifierProvider<AdvancedAnalyticsFilterNotifier, AdvancedAnalyticsFilter>(
        AdvancedAnalyticsFilterNotifier.new);

/// Reaktivni provider napredne analitike.
final advancedAnalyticsSummaryProvider =
    StreamProvider<AdvancedAnalyticsSummary>((ref) async* {
  final repo = await ref.watch(analyticsRepositoryProvider.future);
  final filter = ref.watch(advancedAnalyticsFilterProvider);
  yield* repo.watchAdvancedSummary(filter);
});
