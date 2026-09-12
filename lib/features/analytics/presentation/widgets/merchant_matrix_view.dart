import 'package:flutter/material.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/advanced_analytics_models.dart';

/// Prikaz koncentracije prodavaca (Pareto 80/20) i matrice poseta vs prosečne korpe.
class MerchantMatrixView extends StatelessWidget {
  const MerchantMatrixView({
    super.key,
    required this.merchants,
    required this.pareto,
    required this.currency,
  });

  final List<MerchantMatrixItem> merchants;
  final ParetoConcentration pareto;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final topMerchants = merchants.take(10).toList();
    final maxSpend = topMerchants.isEmpty
        ? 1
        : topMerchants.map((m) => m.totalMinor).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pareto uvid
        if (pareto.top3Percentage > 0) ...[
          Card(
            elevation: 0,
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.pie_chart_outline, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.advancedParetoTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.advancedParetoTop3(pareto.top3Percentage.toStringAsFixed(1)),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Matrica prodavaca
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
                    Icon(Icons.storefront_outlined, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      l10n.advancedMerchantMatrixTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final m in topMerchants) ...[
                  _MerchantRow(
                    merchant: m,
                    maxSpend: maxSpend,
                    currency: currency,
                  ),
                  if (m != topMerchants.last) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.merchant,
    required this.maxSpend,
    required this.currency,
  });

  final MerchantMatrixItem merchant;
  final int maxSpend;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = maxSpend > 0 ? (merchant.totalMinor / maxSpend).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                merchant.merchantName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              MoneyFormat.fromMinor(merchant.totalMinor, currency),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${merchant.receiptCount} poseta · Prosečan račun: ${MoneyFormat.fromMinor(merchant.averageBasketMinor, currency)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
            Text(
              '${merchant.percentageOfTotal.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
