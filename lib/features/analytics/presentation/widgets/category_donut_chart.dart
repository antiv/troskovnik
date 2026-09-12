import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/utils/money_format.dart';
import '../../../categories/domain/category_models.dart';
import '../../../categories/presentation/category_tag.dart';

/// Donut (kružni) grafikon raspodele troškova po kategorijama.
class CategoryDonutChart extends StatefulWidget {
  const CategoryDonutChart({
    super.key,
    required this.categories,
    required this.currency,
    this.onCategoryTap,
  });

  final List<CategorySpending> categories;
  final Currency currency;
  final void Function(CategorySpending)? onCategoryTap;

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int _touchedIndex = -1;

  static const _defaultColors = [
    Color(0xFF2E7D32), // Green
    Color(0xFF1976D2), // Blue
    Color(0xFFF57C00), // Orange
    Color(0xFF7B1FA2), // Purple
    Color(0xFF0097A7), // Teal
    Color(0xFFD32F2F), // Red
    Color(0xFFC2185B), // Pink
    Color(0xFF5D4037), // Brown
    Color(0xFF455A64), // BlueGrey
  ];

  Color _colorFor(CategorySpending c, int index) {
    if (c.color != null && c.color!.isNotEmpty) {
      try {
        final hex = c.color!.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return _defaultColors[index % _defaultColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validCategories = widget.categories.where((c) => c.totalMinor > 0).toList();
    if (validCategories.isEmpty) {
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
            child: Column(
              children: [
                Icon(Icons.pie_chart_outline, size: 40, color: scheme.outline),
                const SizedBox(height: 8),
                Text(
                  'Nema stavki sa kategorijama za izabrani period.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalSpend = validCategories.fold<int>(0, (sum, c) => sum + c.totalMinor);

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
          children: [
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex =
                                pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: [
                        for (var i = 0; i < validCategories.length; i++)
                          _buildSection(
                            category: validCategories[i],
                            index: i,
                            totalSpend: totalSpend,
                            isTouched: i == _touchedIndex,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _touchedIndex >= 0 && _touchedIndex < validCategories.length
                            ? validCategories[_touchedIndex].categoryName
                            : 'Ukupno',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _touchedIndex >= 0 && _touchedIndex < validCategories.length
                            ? MoneyFormat.fromMinor(
                                validCategories[_touchedIndex].totalMinor,
                                widget.currency,
                              )
                            : MoneyFormat.fromMinor(totalSpend, widget.currency),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Lista kategorija sa udelima.
            Column(
              children: [
                for (var i = 0; i < validCategories.length; i++)
                  _CategoryLegendRow(
                    category: validCategories[i],
                    color: _colorFor(validCategories[i], i),
                    totalSpend: totalSpend,
                    currency: widget.currency,
                    isSelected: i == _touchedIndex,
                    onTap: widget.onCategoryTap != null
                        ? () => widget.onCategoryTap!(validCategories[i])
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _buildSection({
    required CategorySpending category,
    required int index,
    required int totalSpend,
    required bool isTouched,
  }) {
    final double pct = totalSpend > 0 ? (category.totalMinor / totalSpend * 100) : 0.0;
    final radius = isTouched ? 34.0 : 26.0;
    final color = _colorFor(category, index);

    return PieChartSectionData(
      color: color,
      value: category.totalMinor.toDouble(),
      title: pct >= 5 ? '${pct.round()}%' : '',
      radius: radius,
      titleStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({
    required this.category,
    required this.color,
    required this.totalSpend,
    required this.currency,
    required this.isSelected,
    this.onTap,
  });

  final CategorySpending category;
  final Color color;
  final int totalSpend;
  final Currency currency;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pct = totalSpend > 0 ? (category.totalMinor / totalSpend * 100) : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            CategoryTag(color: category.color, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.categoryName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: scheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              MoneyFormat.fromMinor(category.totalMinor, currency),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
