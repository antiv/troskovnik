import 'package:flutter/material.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../../categories/presentation/category_tag.dart';
import '../../domain/advanced_analytics_models.dart';

/// Prikaz najvećih promena potrošnje po kategorijama i mesečnih trendova.
class CategoryTrendChart extends StatelessWidget {
  const CategoryTrendChart({
    super.key,
    required this.movers,
    required this.trends,
    required this.currency,
  });

  final List<CategoryMover> movers;
  final List<CategoryTrendPoint> trends;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final topMovers = movers.where((m) => m.deltaMinor != 0).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Najveće promene kategorija (Category Movers)
        if (topMovers.isNotEmpty) ...[
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
                      Icon(Icons.trending_up, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.advancedCategoryMoversTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final mover in topMovers) ...[
                    _MoverTile(mover: mover, currency: currency),
                    if (mover != topMovers.last) const Divider(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _MoverTile extends StatelessWidget {
  const _MoverTile({
    required this.mover,
    required this.currency,
  });

  final CategoryMover mover;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final isIncrease = mover.deltaMinor > 0;
    final pct = mover.percentageChange;
    final color = isIncrease ? Colors.orange.shade800 : Colors.green;
    final icon = isIncrease ? Icons.arrow_upward : Icons.arrow_downward;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CategoryTag(color: mover.color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mover.categoryName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  'Tekući: ${MoneyFormat.fromMinor(mover.currentTotalMinor, currency)} (Prethodni: ${MoneyFormat.fromMinor(mover.previousTotalMinor, currency)})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 2),
                  Text(
                    '${isIncrease ? '+' : ''}${MoneyFormat.fromMinor(mover.deltaMinor, currency)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (pct != null)
                Text(
                  '${isIncrease ? '+' : ''}${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
