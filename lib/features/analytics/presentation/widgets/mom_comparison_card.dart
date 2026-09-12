import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/advanced_analytics_models.dart';

/// Kartica sa Month-over-Month (MoM) poređenjem potrošnje i ključnim metrikama.
class MomComparisonCard extends StatelessWidget {
  const MomComparisonCard({
    super.key,
    required this.mom,
    required this.currency,
  });

  final MonthOverMonthComparison mom;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final prevMonthDate = DateTime(mom.previousYear, mom.previousMonth, 1);
    final prevMonthName = DateFormat('MMMM yyyy').format(prevMonthDate);

    final pct = mom.percentageChange;
    final isIncrease = pct != null && pct > 0;
    final isDecrease = pct != null && pct < 0;

    // Za troškove, smanjenje je obično pozitivno (zeleno), a povećanje troškova narandžasto/crveno.
    final badgeColor = isDecrease
        ? Colors.green
        : isIncrease
            ? Colors.orange.shade800
            : scheme.outline;

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
                Icon(Icons.compare_arrows, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.advancedMomTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  MoneyFormat.fromMinor(mom.currentTotalMinor, currency),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 12),
                if (pct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
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
                          size: 14,
                          color: badgeColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.advancedMomVsPrev(prevMonthName)}: ${MoneyFormat.fromMinor(mom.previousTotalMinor, currency)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatMetric(
                    label: l10n.receiptsTitle,
                    value: '${mom.currentReceiptCount}',
                    subtext: mom.receiptCountDelta != 0
                        ? '${mom.receiptCountDelta > 0 ? '+' : ''}${mom.receiptCountDelta} vs prošli'
                        : 'isto kao prošli',
                  ),
                ),
                Expanded(
                  child: _StatMetric(
                    label: 'Razlika',
                    value: '${mom.deltaMinor >= 0 ? '+' : ''}${MoneyFormat.fromMinor(mom.deltaMinor, currency)}',
                    valueColor: badgeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  const _StatMetric({
    required this.label,
    required this.value,
    this.subtext,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? subtext;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
        if (subtext != null) ...[
          const SizedBox(height: 2),
          Text(
            subtext!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}
