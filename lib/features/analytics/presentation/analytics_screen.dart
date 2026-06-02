import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/utils/money_format.dart';
import '../data/analytics_providers.dart';
import '../domain/analytics_models.dart';

/// Ekran analitike potrošnje (MVP, nad postojećim podacima — bez kategorija).
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(analyticsSummaryProvider);

    return Column(
      children: [
        _RangeSelector(),
        Expanded(
          child: summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${l10n.errGeneric}\n$e')),
            data: (s) {
              if (s.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child:
                        Text(l10n.analyticsEmpty, textAlign: TextAlign.center),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TotalCard(summary: s),
                  const SizedBox(height: 16),
                  _Section(
                    title: l10n.analyticsByMonth,
                    child: _MonthlyChart(monthly: s.monthly),
                  ),
                  _Section(
                    title: l10n.analyticsBusinessSplit,
                    child: _BusinessSplitBar(split: s.businessSplit),
                  ),
                  _Section(
                    title: l10n.analyticsByMerchant,
                    child: _MerchantList(merchants: s.byMerchant),
                  ),
                  _Section(
                    title: l10n.analyticsTopItems,
                    subtitle: l10n.analyticsItemsHint,
                    child: _TopItemsList(items: s.topItems),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RangeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final range = ref.watch(analyticsRangeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SegmentedButton<AnalyticsRange>(
        segments: [
          ButtonSegment(
              value: AnalyticsRange.last3Months,
              label: Text(l10n.analyticsRange3m)),
          ButtonSegment(
              value: AnalyticsRange.last12Months,
              label: Text(l10n.analyticsRange12m)),
          ButtonSegment(
              value: AnalyticsRange.all, label: Text(l10n.analyticsRangeAll)),
        ],
        selected: {range},
        onSelectionChanged: (s) =>
            ref.read(analyticsRangeProvider.notifier).set(s.first),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary});
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.analyticsTotalSpent,
                style: TextStyle(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(
              MoneyFormat.fromMinor(summary.totalMinor),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(l10n.analyticsReceiptCount(summary.receiptCount),
                style: TextStyle(color: scheme.onPrimaryContainer)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.analyticsEstimatedVat,
                    style: TextStyle(color: scheme.onPrimaryContainer)),
                Text(MoneyFormat.fromMinor(summary.estimatedVatMinor),
                    style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            Text(l10n.analyticsVatHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null)
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.monthly});
  final List<MonthlySpending> monthly;

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final maxY = monthly
            .map((m) => m.totalMinor)
            .fold<int>(0, (a, b) => a > b ? a : b)
            .toDouble() /
        100.0;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barGroups: [
            for (var i = 0; i < monthly.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: monthly[i].totalMinor / 100.0,
                  color: scheme.primary,
                  width: 14,
                  borderRadius: BorderRadius.circular(3),
                ),
              ]),
          ],
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= monthly.length) {
                    return const SizedBox.shrink();
                  }
                  final m = monthly[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${m.month}/${m.year % 100}',
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _BusinessSplitBar extends StatelessWidget {
  const _BusinessSplitBar({required this.split});
  final BusinessSplit split;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final total = split.totalMinor;
    final bizFraction = total == 0 ? 0.0 : split.businessMinor / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              if (bizFraction > 0)
                Expanded(
                  flex: (bizFraction * 1000).round(),
                  child:
                      Container(height: 20, color: scheme.tertiary),
                ),
              if (bizFraction < 1)
                Expanded(
                  flex: ((1 - bizFraction) * 1000).round(),
                  child:
                      Container(height: 20, color: scheme.primary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LegendDot(
                color: scheme.tertiary,
                label:
                    '${l10n.analyticsBusiness}: ${MoneyFormat.fromMinor(split.businessMinor)}'),
            _LegendDot(
                color: scheme.primary,
                label:
                    '${l10n.analyticsPersonal}: ${MoneyFormat.fromMinor(split.personalMinor)}'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _MerchantList extends StatelessWidget {
  const _MerchantList({required this.merchants});
  final List<MerchantSpending> merchants;

  @override
  Widget build(BuildContext context) {
    final top = merchants.take(8).toList();
    final maxV = top.isEmpty
        ? 1
        : top.map((m) => m.totalMinor).reduce((a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final m in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(m.merchantName)),
                    Text(MoneyFormat.fromMinor(m.totalMinor),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxV == 0 ? 0 : m.totalMinor / maxV,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopItemsList extends StatelessWidget {
  const _TopItemsList({required this.items});
  final List<TopItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final it in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(it.name),
            subtitle: Text('×${it.count}'),
            trailing: Text(MoneyFormat.fromMinor(it.totalMinor),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
