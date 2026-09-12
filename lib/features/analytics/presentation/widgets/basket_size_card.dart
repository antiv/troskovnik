import 'package:flutter/material.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/advanced_analytics_models.dart';

/// Kartica sa raspodelom veličina računa (mali, srednji, veliki).
class BasketSizeCard extends StatelessWidget {
  const BasketSizeCard({
    super.key,
    required this.basket,
    required this.currency,
  });

  final BasketSizeDistribution basket;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    if (basket.totalCount == 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (smallRange, medRange, largeRange) = switch (currency) {
      Currency.rsd => ('< 1.000 RSD', '1.000 - 5.000 RSD', '> 5.000 RSD'),
      Currency.eur => ('< 10 €', '10 - 50 €', '> 50 €'),
      Currency.bam => ('< 20 KM', '20 - 100 KM', '> 100 KM'),
    };

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
                Icon(Icons.shopping_bag_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.advancedBasketTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BasketRow(
              label: l10n.advancedBasketSmall,
              range: smallRange,
              count: basket.smallCount,
              totalMinor: basket.smallTotalMinor,
              totalCount: basket.totalCount,
              totalSpend: basket.totalMinor,
              color: Colors.blue.shade400,
              currency: currency,
            ),
            const SizedBox(height: 12),
            _BasketRow(
              label: l10n.advancedBasketMedium,
              range: medRange,
              count: basket.mediumCount,
              totalMinor: basket.mediumTotalMinor,
              totalCount: basket.totalCount,
              totalSpend: basket.totalMinor,
              color: scheme.primary,
              currency: currency,
            ),
            const SizedBox(height: 12),
            _BasketRow(
              label: l10n.advancedBasketLarge,
              range: largeRange,
              count: basket.largeCount,
              totalMinor: basket.largeTotalMinor,
              totalCount: basket.totalCount,
              totalSpend: basket.totalMinor,
              color: Colors.orange.shade600,
              currency: currency,
            ),
          ],
        ),
      ),
    );
  }
}

class _BasketRow extends StatelessWidget {
  const _BasketRow({
    required this.label,
    required this.range,
    required this.count,
    required this.totalMinor,
    required this.totalCount,
    required this.totalSpend,
    required this.color,
    required this.currency,
  });

  final String label;
  final String range;
  final int count;
  final int totalMinor;
  final int totalCount;
  final int totalSpend;
  final Color color;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final pctCount = totalCount > 0 ? (count / totalCount) : 0.0;
    final pctSpend = totalSpend > 0 ? (totalMinor / totalSpend * 100).round() : 0;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text('($range)', style: TextStyle(fontSize: 11, color: scheme.outline)),
              ],
            ),
            Text(
              MoneyFormat.fromMinor(totalMinor, currency),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pctCount.clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$count računa (${(pctCount * 100).round()}%)',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            Text('$pctSpend% potrošnje',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
