import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/advanced_analytics_models.dart';

/// Lista artikala sa istorijom poskupljenja i pojeftinjenja (praćenje cena).
class PriceInflationList extends StatelessWidget {
  const PriceInflationList({
    super.key,
    required this.items,
    required this.currency,
  });

  final List<ItemPriceInflation> items;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              l10n.advancedPriceInflationEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
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
                Icon(Icons.price_change_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.advancedPriceInflationTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final it in items.take(15)) ...[
              _InflationTile(item: it, currency: currency),
              if (it != items.take(15).last) const Divider(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _InflationTile extends StatelessWidget {
  const _InflationTile({
    required this.item,
    required this.currency,
  });

  final ItemPriceInflation item;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final isIncrease = item.percentChange > 0;
    final isDecrease = item.percentChange < 0;
    final color = isIncrease
        ? Colors.orange.shade800
        : isDecrease
            ? Colors.green
            : Theme.of(context).colorScheme.outline;

    final firstDateStr = DateFormat('MM.yy').format(item.firstDate);
    final latestDateStr = DateFormat('MM.yy').format(item.latestDate);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${MoneyFormat.fromMinor(item.firstPriceMinor, currency)} ($firstDateStr) → ${MoneyFormat.fromMinor(item.latestPriceMinor, currency)} ($latestDateStr)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                Text(
                  'Raspon: ${MoneyFormat.fromMinor(item.minPriceMinor, currency)} - ${MoneyFormat.fromMinor(item.maxPriceMinor, currency)} · ${item.purchaseCount}x kupljeno',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isIncrease
                      ? Icons.arrow_upward
                      : isDecrease
                          ? Icons.arrow_downward
                          : Icons.remove,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 2),
                Text(
                  '${item.percentChange >= 0 ? '+' : ''}${item.percentChange.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
