import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/currency.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/currency_picker.dart';
import '../data/advanced_analytics_providers.dart';
import '../data/analytics_providers.dart';
import '../domain/advanced_analytics_models.dart';
import 'widgets/advanced_filter_bar.dart';
import 'widgets/basket_size_card.dart';
import 'widgets/category_donut_chart.dart';
import 'widgets/category_trend_chart.dart';
import 'widgets/day_of_week_chart.dart';
import 'widgets/merchant_matrix_view.dart';
import 'widgets/mom_comparison_card.dart';
import 'widgets/pacing_chart.dart';
import 'widgets/price_inflation_list.dart';
import 'widgets/tax_breakdown_card.dart';

/// Ekran napredne / detaljne analitike potrošnje.
class AdvancedAnalyticsScreen extends ConsumerWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(advancedAnalyticsFilterProvider);
    final summaryAsync = ref.watch(advancedAnalyticsSummaryProvider);
    final basicSummaryAsync = ref.watch(analyticsSummaryProvider);

    // Dostupne valute iz baze
    final availableCurrencies = basicSummaryAsync
            .whenData((s) => s.totalsByCurrency.keys.toList())
            .value ??
        const <Currency>[];

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.advancedAnalyticsTitle),
          actions: [
            if (availableCurrencies.length > 1)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CurrencyPicker(
                  currencies: availableCurrencies,
                  selected: filter.currency,
                  labelBuilder: (c) => c.symbol,
                  onSelected: (c) {
                    if (c != null) {
                      ref.read(advancedAnalyticsFilterProvider.notifier).setCurrency(c);
                    }
                  },
                ),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: const Icon(Icons.show_chart, size: 18),
                text: l10n.advancedTabOverview,
              ),
              Tab(
                icon: const Icon(Icons.pie_chart_outline, size: 18),
                text: l10n.advancedTabCategories,
              ),
              Tab(
                icon: const Icon(Icons.storefront_outlined, size: 18),
                text: l10n.advancedTabMerchants,
              ),
              Tab(
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                text: l10n.advancedTabTax,
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const AdvancedFilterBar(),
            Expanded(
              child: summaryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${l10n.errGeneric}\n$e')),
                data: (s) {
                  if (s.isEmpty) {
                    final scheme = Theme.of(context).colorScheme;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 48, color: scheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              l10n.analyticsEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            if (filter.preset != AdvancedAnalyticsDatePreset.all) ...[
                              const SizedBox(height: 16),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.all_inclusive, size: 18),
                                onPressed: () => ref
                                    .read(advancedAnalyticsFilterProvider.notifier)
                                    .setPreset(AdvancedAnalyticsDatePreset.all),
                                label: Text(l10n.analyticsRangeAll),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return TabBarView(
                    children: [
                      // TAB 1: Trendovi i obrasci
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _QuickSummaryHeader(
                            totalMinor: s.totalMinor,
                            receiptCount: s.receiptCount,
                            avgReceiptMinor: s.averageReceiptMinor,
                            currency: filter.currency,
                          ),
                          const SizedBox(height: 16),
                          if (s.momComparison != null) ...[
                            MomComparisonCard(
                              mom: s.momComparison!,
                              currency: filter.currency,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (s.pacing.isNotEmpty) ...[
                            PacingChart(
                              points: s.pacing,
                              currency: filter.currency,
                            ),
                            const SizedBox(height: 16),
                          ],
                          DayOfWeekChart(
                            dayOfWeek: s.dayOfWeek,
                            timeOfDay: s.timeOfDay,
                            currency: filter.currency,
                          ),
                          const SizedBox(height: 16),
                          BasketSizeCard(
                            basket: s.basketSizes,
                            currency: filter.currency,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),

                      // TAB 2: Kategorije
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          CategoryDonutChart(
                            categories: s.categorySpending,
                            currency: filter.currency,
                            onCategoryTap: (cat) {
                              ref
                                  .read(advancedAnalyticsFilterProvider.notifier)
                                  .setCategory(cat.categoryId == 0 ? null : cat.categoryId);
                            },
                          ),
                          const SizedBox(height: 16),
                          CategoryTrendChart(
                            movers: s.categoryMovers,
                            trends: s.categoryTrends,
                            currency: filter.currency,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),

                      // TAB 3: Prodavci i cene
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          MerchantMatrixView(
                            merchants: s.merchantMatrix,
                            pareto: s.pareto,
                            currency: filter.currency,
                          ),
                          const SizedBox(height: 16),
                          PriceInflationList(
                            items: s.priceInflation,
                            currency: filter.currency,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),

                      // TAB 4: PDV i poslovno
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TaxBreakdownCard(
                            taxBreakdown: s.taxBreakdown,
                            businessSplit: s.businessSplit,
                            currency: filter.currency,
                            businessFilter: filter.businessFilter,
                            onFilterChanged: (bf) => ref
                                .read(advancedAnalyticsFilterProvider.notifier)
                                .setBusinessFilter(bf),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSummaryHeader extends StatelessWidget {
  const _QuickSummaryHeader({
    required this.totalMinor,
    required this.receiptCount,
    required this.avgReceiptMinor,
    required this.currency,
  });

  final int totalMinor;
  final int receiptCount;
  final int avgReceiptMinor;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.analyticsTotalSpent,
            style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            MoneyFormat.fromMinor(totalMinor, currency),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.analyticsReceiptCount(receiptCount),
                style: TextStyle(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              Text(
                '${l10n.analyticsAverage}: ${MoneyFormat.fromMinor(avgReceiptMinor, currency)}',
                style: TextStyle(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
