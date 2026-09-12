import 'package:flutter/material.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/advanced_analytics_models.dart';
import '../../domain/analytics_models.dart';

/// Kartica sa detaljnim prikazom PDV-a po stopama i poslovnih troškova (Varijanta A).
class TaxBreakdownCard extends StatelessWidget {
  const TaxBreakdownCard({
    super.key,
    required this.taxBreakdown,
    required this.businessSplit,
    required this.currency,
    required this.businessFilter,
    this.onFilterChanged,
  });

  final List<TaxRateBreakdown> taxBreakdown;
  final BusinessSplit businessSplit;
  final Currency currency;
  final AnalyticsBusinessFilter businessFilter;
  final ValueChanged<AnalyticsBusinessFilter>? onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final totalVat = taxBreakdown.fold<int>(0, (sum, t) => sum + t.vatMinor);
    final totalBase = taxBreakdown.fold<int>(0, (sum, t) => sum + t.taxableBaseMinor);

    final bizTotal = businessSplit.businessMinor;
    final perTotal = businessSplit.personalMinor;
    final allTotal = businessSplit.totalMinor;

    final bizFlex = bizTotal.clamp(0, 1000000);
    final perFlex = perTotal.clamp(0, 1000000);

    return Column(
      children: [
        // 1. Poslovno vs Lično kartica (uvek prikazuje ukupan stvarni odnos za period)
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
                    Icon(Icons.business_center_outlined, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      l10n.advancedBusinessDeductibleTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      l10n.advancedBusinessRatio,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.outline,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Vizuelna traka odnosa
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: allTotal == 0
                      ? Container(height: 12, color: scheme.surfaceContainerHighest)
                      : Row(
                          children: [
                            if (bizFlex > 0)
                              Expanded(
                                flex: bizFlex,
                                child: Container(height: 12, color: Colors.blue.shade700),
                              ),
                            if (perFlex > 0)
                              Expanded(
                                flex: perFlex,
                                child: Container(height: 12, color: Colors.green.shade700),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SplitCard(
                        title: l10n.analyticsBusiness,
                        amountMinor: bizTotal,
                        totalMinor: allTotal,
                        color: Colors.blue.shade700,
                        currency: currency,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SplitCard(
                        title: l10n.analyticsPersonal,
                        amountMinor: perTotal,
                        totalMinor: allTotal,
                        color: Colors.green.shade700,
                        currency: currency,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Struktura PDV-a sa filterom opsega
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.receipt_outlined, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.advancedTaxTitle,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            switch (businessFilter) {
                              AnalyticsBusinessFilter.all => l10n.advancedVatAllBadge,
                              AnalyticsBusinessFilter.businessOnly =>
                                l10n.advancedVatDeductibleBadge,
                              AnalyticsBusinessFilter.personalOnly =>
                                l10n.advancedVatPersonalBadge,
                            },
                            style: TextStyle(
                              fontSize: 11,
                              color: businessFilter == AnalyticsBusinessFilter.businessOnly
                                  ? Colors.blue.shade700
                                  : scheme.outline,
                              fontWeight: businessFilter == AnalyticsBusinessFilter.businessOnly
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Brzi filter opsega za PDV tabelu
                if (onFilterChanged != null) ...[
                  SegmentedButton<AnalyticsBusinessFilter>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    segments: [
                      ButtonSegment(
                        value: AnalyticsBusinessFilter.all,
                        label: Text(
                          l10n.receiptFilterAll,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      ButtonSegment(
                        value: AnalyticsBusinessFilter.businessOnly,
                        label: Text(
                          l10n.receiptFilterBusiness,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      ButtonSegment(
                        value: AnalyticsBusinessFilter.personalOnly,
                        label: Text(
                          l10n.receiptFilterPersonal,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                    selected: {businessFilter},
                    onSelectionChanged: (set) => onFilterChanged!(set.first),
                  ),
                  const SizedBox(height: 16),
                ],

                if (taxBreakdown.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        l10n.analyticsEmpty,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ] else ...[
                  // Zaglavlje
                  Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text('Stopa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(l10n.advancedTaxBase,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(l10n.advancedTaxVat,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  for (final row in taxBreakdown) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              '${row.taxRate.toStringAsFixed(0)}% ${row.taxLabel != null ? '(${row.taxLabel})' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              MoneyFormat.fromMinor(row.taxableBaseMinor, currency),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              MoneyFormat.fromMinor(row.vatMinor, currency),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 16),
                  // Ukupno red
                  Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text('UKUPNO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          MoneyFormat.fromMinor(totalBase, currency),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          MoneyFormat.fromMinor(totalVat, currency),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.title,
    required this.amountMinor,
    required this.totalMinor,
    required this.color,
    required this.currency,
  });

  final String title;
  final int amountMinor;
  final int totalMinor;
  final Color color;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = totalMinor > 0 ? (amountMinor / totalMinor * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            MoneyFormat.fromMinor(amountMinor, currency),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
