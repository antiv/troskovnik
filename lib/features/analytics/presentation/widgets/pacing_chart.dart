import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/advanced_analytics_models.dart';

/// Grafikon kumulativnog tempa potrošnje (pacing) tokom meseca.
class PacingChart extends StatelessWidget {
  const PacingChart({
    super.key,
    required this.points,
    required this.currency,
  });

  final List<SpendingPacingPoint> points;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final curMax = points.map((p) => p.currentCumulativeMinor).fold<int>(0, (a, b) => a > b ? a : b);
    final prevMax = points
        .map((p) => p.previousCumulativeMinor ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final overallMax = curMax > prevMax ? curMax : prevMax;
    final maxY = overallMax > 0 ? (overallMax / 100.0) * 1.15 : 100.0;

    final currentSpots = <FlSpot>[];
    final prevSpots = <FlSpot>[];

    for (final p in points) {
      currentSpots.add(FlSpot(p.day.toDouble(), p.currentCumulativeMinor / 100.0));
      if (p.previousCumulativeMinor != null) {
        prevSpots.add(FlSpot(p.day.toDouble(), p.previousCumulativeMinor! / 100.0));
      }
    }

    return Card(
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
                Icon(Icons.show_chart, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.advancedPacingTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LegendItem(
                  color: scheme.primary,
                  label: l10n.advancedPacingCurrent,
                  isSolid: true,
                ),
                const SizedBox(width: 16),
                _LegendItem(
                  color: scheme.outline,
                  label: l10n.advancedPacingPrevious,
                  isSolid: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: points.length.toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            'Dan ${s.x.toInt()}: ${MoneyFormat.fromDouble(s.y, currency)}',
                            TextStyle(
                              color: scheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    // Prethodni mesec (isprekidano).
                    if (prevSpots.isNotEmpty)
                      LineChartBarData(
                        spots: prevSpots,
                        isCurved: true,
                        color: scheme.outline.withValues(alpha: 0.6),
                        barWidth: 2,
                        dashArray: [5, 5],
                        dotData: const FlDotData(show: false),
                      ),
                    // Tekući mesec (puna linija).
                    LineChartBarData(
                      spots: currentSpots,
                      isCurved: true,
                      color: scheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (val, _) {
                          final day = val.toInt();
                          if (day == 1 || day == 5 || day == 10 || day == 15 || day == 20 || day == 25 || day == 30) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('$day.', style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.isSolid,
  });

  final Color color;
  final String label;
  final bool isSolid;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
