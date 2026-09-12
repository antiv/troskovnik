import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/advanced_analytics_models.dart';

/// Prikaz raspodele potrošnje po danima u nedelji i dobu dana.
class DayOfWeekChart extends StatelessWidget {
  const DayOfWeekChart({
    super.key,
    required this.dayOfWeek,
    required this.timeOfDay,
    required this.currency,
  });

  final List<DayOfWeekSpending> dayOfWeek;
  final List<TimeOfDaySpending> timeOfDay;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final maxVal = dayOfWeek.map((d) => d.totalMinor).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = maxVal > 0 ? (maxVal / 100.0) * 1.2 : 10.0;

    final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];

    final totalTimeSpend = timeOfDay.fold<int>(0, (sum, t) => sum + t.totalMinor);

    return Column(
      children: [
        // Dan u nedelji
        Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_view_week, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      l10n.advancedDayOfWeekTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => scheme.inverseSurface,
                          getTooltipItem: (group, _, rod, _) {
                            final d = dayOfWeek[group.x];
                            return BarTooltipItem(
                              '${dayNames[group.x]}: ${MoneyFormat.fromMinor(d.totalMinor, currency)}\n${l10n.analyticsReceiptCount(d.receiptCount)}',
                              TextStyle(
                                color: scheme.onInverseSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < dayOfWeek.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: dayOfWeek[i].totalMinor / 100.0,
                                color: i >= 5 ? scheme.secondary : scheme.primary,
                                width: 18,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < dayNames.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    dayNames[idx],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: idx >= 5 ? FontWeight.bold : FontWeight.normal,
                                      color: idx >= 5 ? scheme.secondary : null,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Doba dana
        Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      l10n.advancedTimeOfDayTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var s = 0; s < timeOfDay.length; s++) ...[
                      if (s > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _TimeSlotTile(
                          slot: s,
                          spending: timeOfDay[s],
                          totalSpend: totalTimeSpend,
                          currency: currency,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeSlotTile extends StatelessWidget {
  const _TimeSlotTile({
    required this.slot,
    required this.spending,
    required this.totalSpend,
    required this.currency,
  });

  final int slot;
  final TimeOfDaySpending spending;
  final int totalSpend;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (icon, title) = switch (slot) {
      0 => (
          Icons.wb_sunny_outlined,
          l10n.advancedTimeMorning.replaceAll(' (', '\n').replaceAll(')', ''),
        ),
      1 => (
          Icons.wb_sunny,
          l10n.advancedTimeAfternoon.replaceAll(' (', '\n').replaceAll(')', ''),
        ),
      2 => (
          Icons.nights_stay_outlined,
          l10n.advancedTimeEvening.replaceAll(' (', '\n').replaceAll(')', ''),
        ),
      _ => (
          Icons.bedtime_outlined,
          l10n.advancedTimeNight.replaceAll(' (', '\n').replaceAll(')', ''),
        ),
    };

    final pct = totalSpend > 0 ? (spending.totalMinor / totalSpend * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              MoneyFormat.fromMinor(spending.totalMinor, currency),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 10,
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
