import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/database.dart' show CanonicalItemRow;
import '../../../core/domain/currency.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/currency_picker.dart';
import '../../categories/data/category_providers.dart';
import '../../categories/domain/category_models.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../categories/presentation/category_picker_sheet.dart';
import '../../categories/presentation/category_tag.dart';
import '../../export/data/export_service.dart';
import '../../export/domain/export_range.dart';
import '../../receipts/presentation/receipt_detail_screen.dart';
import '../data/analytics_providers.dart';
import '../data/analytics_repository.dart' show AnalyticsRepository;
import '../domain/analytics_models.dart';
import 'advanced_analytics_screen.dart';
import 'widgets/company_spending_list.dart';

/// Ekran analitike potrošnje (MVP, nad postojećim podacima — bez kategorija).
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final selectedCurrency = ref.watch(analyticsCurrencyProvider).value;

    // Dostupne valute (prazno dok se učitava).
    final availableCurrencies = summaryAsync
            .whenData((s) => s.totalsByCurrency.keys.toList())
            .value ??
        const <Currency>[];
    // Valutu razrešava repozitorijum (iste brojke i oznaka); ovde samo dok se
    // sažetak učitava.
    final activeCurrency = summaryAsync.value?.currency ??
        (availableCurrencies.contains(selectedCurrency)
            ? selectedCurrency!
            : (availableCurrencies.isNotEmpty
                ? availableCurrencies.first
                : Currency.rsd));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _RangeSelector()),
              if (availableCurrencies.length > 1)
                CurrencyPicker(
                  currencies: availableCurrencies,
                  selected: activeCurrency,
                  labelBuilder: (c) => c.symbol,
                  onSelected: (c) =>
                      ref.read(analyticsCurrencyProvider.notifier).set(c),
                ),
              const _ExportButton(),
              const _AdvancedAnalyticsButton(),
            ],
          ),
        ),
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

              // Filtriraj podatke po aktivnoj valuti.
              final monthly = s.monthly
                  .where((m) => m.currency == activeCurrency)
                  .toList();
              final byMerchant = s.byMerchant
                  .where((m) => m.currency == activeCurrency)
                  .toList();
              final totalMinor = s.totalsByCurrency[activeCurrency] ?? 0;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TotalCard(
                    totalMinor: totalMinor,
                    currency: activeCurrency,
                    receiptCount: s.receiptCount,
                    estimatedVatMinor: s.estimatedVatMinor,
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: l10n.analyticsByMonth,
                    child: _SingleCurrencyChart(
                        items: monthly, currency: activeCurrency),
                  ),
                  _Section(
                    title: l10n.analyticsBusinessSplit,
                    child: _BusinessSplitBar(split: s.businessSplit, currency: activeCurrency),
                  ),
                  if (s.byCompany.any((c) => c.taxId != null))
                    _Section(
                      title: l10n.analyticsByCompany,
                      child: CompanySpendingList(
                          items: s.byCompany, currency: activeCurrency),
                    ),
                  if (s.byPaymentMethod.isNotEmpty)
                    _Section(
                      title: l10n.analyticsByPayment,
                      child: _PaymentSplitBar(items: s.byPaymentMethod, currency: activeCurrency),
                    ),
                  _Section(
                    title: l10n.analyticsByMerchant,
                    child: _MerchantList(
                      merchants: byMerchant,
                      onTap: (m) => _showMerchantSheet(
                          context, m.merchantId, m.merchantName),
                    ),
                  ),
                  if (s.byCategory.isNotEmpty)
                    _Section(
                      title: l10n.analyticsByCategory,
                      trailing: IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        tooltip: l10n.categoriesTitle,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const CategoriesScreen()),
                        ),
                      ),
                      child: _CategoryList(
                        items: s.byCategory,
                        currency: activeCurrency,
                        onTap: (c) => _showCategorySheet(
                            context, c.categoryId, c.categoryName),
                      ),
                    ),
                  _Section(
                    title: l10n.analyticsTopItems,
                    trailing: s.totalUniqueItemsCount > 0
                        ? TextButton.icon(
                            onPressed: () => _showCatalogSheet(context),
                            icon: const Icon(Icons.inventory_2_outlined,
                                size: 18),
                            label: Text(l10n
                                .analyticsViewAllItems(s.totalUniqueItemsCount)),
                          )
                        : null,
                    child: _TopItemsList(
                      items: s.topItems,
                      currency: activeCurrency,
                      onTap: (it) => _showItemSheet(context, it.name),
                    ),
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
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: SegmentedButton<AnalyticsRange>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
        ),
        segments: [
          ButtonSegment(
            value: AnalyticsRange.last3Months,
            label: Text(
              l10n.analyticsRange3m,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          ButtonSegment(
            value: AnalyticsRange.last12Months,
            label: Text(
              l10n.analyticsRange12m,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          ButtonSegment(
            value: AnalyticsRange.all,
            label: Text(
              l10n.analyticsRangeAll,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
        selected: {range},
        onSelectionChanged: (s) =>
            ref.read(analyticsRangeProvider.notifier).set(s.first),
      ),
    );
  }
}

/// Dugme za izvoz računa u CSV — otvara izbor perioda u bottom sheet-u.
class _ExportButton extends ConsumerWidget {
  const _ExportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.file_download_outlined),
      tooltip: l10n.exportCsv,
      onPressed: () => _showExportSheet(context, ref),
    );
  }
}

/// Dugme za otvaranje detaljne / napredne analitike.
class _AdvancedAnalyticsButton extends StatelessWidget {
  const _AdvancedAnalyticsButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.insights_outlined),
        tooltip: l10n.advancedAnalyticsTooltip,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AdvancedAnalyticsScreen(),
          ),
        ),
      ),
    );
  }
}

void _showExportSheet(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.today),
            title: Text(l10n.exportCurrentMonth),
            onTap: () {
              Navigator.pop(sheetCtx);
              _runExport(context, ref, ExportRange.currentMonth);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.exportPreviousMonth),
            onTap: () {
              Navigator.pop(sheetCtx);
              _runExport(context, ref, ExportRange.previousMonth);
            },
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(l10n.exportCustomPeriod),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2021, 1, 1),
                lastDate: DateTime(now.year + 1, 12, 31),
              );
              if (picked == null || !context.mounted) return;
              _runExport(context, ref, ExportRange.custom,
                  from: picked.start, to: picked.end);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _runExport(
  BuildContext context,
  WidgetRef ref,
  ExportRange range, {
  DateTime? from,
  DateTime? to,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final service = await ref.read(exportServiceProvider.future);
    final result = await service.exportToFile(range,
        customFrom: from, customTo: to);
    if (result == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportEmpty)));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.filePath)],
        text: l10n.exportShareText,
      ),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.totalMinor,
    required this.currency,
    required this.receiptCount,
    required this.estimatedVatMinor,
  });
  final int totalMinor;
  final Currency currency;
  final int receiptCount;
  final int estimatedVatMinor;

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
              MoneyFormat.fromMinor(totalMinor, currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(l10n.analyticsReceiptCount(receiptCount),
                style: TextStyle(color: scheme.onPrimaryContainer)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.analyticsEstimatedVat,
                    style: TextStyle(color: scheme.onPrimaryContainer)),
                Text(MoneyFormat.fromMinor(estimatedVatMinor, currency),
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
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Distinktne boje za podeljene trake i legende grafova.
///
/// Tema je seedovana iz jedne zelene boje, pa se `primary`/`secondary`/
/// `tertiary` u svetloj temi stope u skoro iste zelene tonove i teško se
/// razlikuju. Ove fiksne nijanse ostaju razdvojive u obe teme — u tamnoj se
/// koriste svetlije nijanse radi kontrasta sa pozadinom.
List<Color> _categoryColors(Brightness brightness) {
  final shade = brightness == Brightness.dark ? 300 : 600;
  return <Color>[
    Colors.green[shade]!,
    Colors.blue[shade]!,
    Colors.orange[shade]!,
    Colors.purple[shade]!,
    Colors.teal[shade]!,
    Colors.red[shade]!,
  ];
}

/// Pozadina + stil teksta za tooltipove na grafovima. Default fl_chart
/// tooltip ima slab kontrast u svetloj temi; `inverseSurface` par je čitljiv
/// u obe teme.
BarTouchData _barTooltip(ColorScheme scheme,
        [Currency currency = Currency.rsd]) =>
    BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => scheme.inverseSurface,
        getTooltipItem: (group, _, rod, _) => BarTooltipItem(
          MoneyFormat.fromDouble(rod.toY, currency),
          TextStyle(
            color: scheme.onInverseSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );

/// Grafikon potrošnje po mesecima. Kad ima više valuta, prikazuje zaseban
/// grafikon po valuti (nikad se ne mešaju na istoj osi).
class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.monthly});
  final List<MonthlySpending> monthly;

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) return const SizedBox.shrink();

    // Grupiši po valuti.
    final byCurrency = <Currency, List<MonthlySpending>>{};
    for (final m in monthly) {
      byCurrency.putIfAbsent(m.currency, () => []).add(m);
    }

    if (byCurrency.length == 1) {
      return _SingleCurrencyChart(
          items: monthly, currency: byCurrency.keys.first);
    }

    return Column(
      children: [
        for (final entry in byCurrency.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(entry.key.symbol,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          _SingleCurrencyChart(items: entry.value, currency: entry.key),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SingleCurrencyChart extends StatelessWidget {
  const _SingleCurrencyChart({required this.items, required this.currency});
  final List<MonthlySpending> items;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxVal = items.map((m) => m.totalMinor).fold<int>(0, (a, b) => a > b ? a : b);
    final minVal = items.map((m) => m.totalMinor).fold<int>(0, (a, b) => a < b ? a : b);
    final maxY = (maxVal / 100.0) * 1.2;
    final minY = minVal < 0 ? (minVal / 100.0) * 1.2 : 0.0;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY == 0 ? 1 : maxY,
          minY: minY,
          barTouchData: _barTooltip(scheme, currency),
          barGroups: [
            for (var i = 0; i < items.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: items[i].totalMinor / 100.0,
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
                  if (i < 0 || i >= items.length) {
                    return const SizedBox.shrink();
                  }
                  final m = items[i];
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
  const _BusinessSplitBar({required this.split, required this.currency});
  final BusinessSplit split;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = _categoryColors(Theme.of(context).brightness);
    final personalColor = palette[0]; // zelena (brend)
    final businessColor = palette[1]; // plava
    // Negativne vrednosti (refundacije) klampujemo na 0 za vizuelni prikaz trake;
    // stvarni iznosi (mogu biti negativni) prikazuju se u legendi.
    final bizFlex = split.businessMinor.clamp(0, 1000000);
    final perFlex = split.personalMinor.clamp(0, 1000000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: bizFlex + perFlex == 0
              ? Container(height: 20, color: personalColor)
              : Row(
                  children: [
                    if (bizFlex > 0)
                      Expanded(
                        flex: bizFlex,
                        child: Container(height: 20, color: businessColor),
                      ),
                    if (perFlex > 0)
                      Expanded(
                        flex: perFlex,
                        child: Container(height: 20, color: personalColor),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LegendDot(
                color: businessColor,
                label:
                    '${l10n.analyticsBusiness}: ${MoneyFormat.fromMinor(split.businessMinor, currency)}'),
            _LegendDot(
                color: personalColor,
                label:
                    '${l10n.analyticsPersonal}: ${MoneyFormat.fromMinor(split.personalMinor, currency)}'),
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

class _PaymentSplitBar extends StatelessWidget {
  const _PaymentSplitBar({required this.items, required this.currency});
  final List<PaymentMethodSpending> items;
  final Currency currency;

  String _label(BuildContext context, String method) =>
      method == AnalyticsRepository.paymentUnknownKey
          ? AppLocalizations.of(context).analyticsPaymentUnknown
          : method;

  @override
  Widget build(BuildContext context) {
    final palette = _categoryColors(Theme.of(context).brightness);
    Color colorFor(int i) => palette[i % palette.length];
    // Samo pozitivne stavke učestvuju u vizuelnom prikazu trake.
    final positiveItems = items.where((e) => e.totalMinor > 0).toList();
    final positiveTotal = positiveItems.fold<int>(0, (a, e) => a + e.totalMinor);
    if (positiveTotal <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              for (var i = 0; i < positiveItems.length; i++)
                Expanded(
                  flex: (positiveItems[i].totalMinor / positiveTotal * 1000)
                      .round()
                      .clamp(1, 1000000),
                  child: Container(height: 20, color: colorFor(i)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < items.length; i++)
              _LegendDot(
                color: colorFor(i),
                label:
                    '${_label(context, items[i].method)}: ${MoneyFormat.fromMinor(items[i].totalMinor, currency)}',
              ),
          ],
        ),
      ],
    );
  }
}

class _MerchantList extends StatelessWidget {
  const _MerchantList({required this.merchants, this.onTap});
  final List<MerchantSpending> merchants;

  /// Klik na prodavca (drill-down). Null → red nije interaktivan.
  final void Function(MerchantSpending)? onTap;

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
          InkWell(
            onTap: onTap == null ? null : () => onTap!(m),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(m.merchantName)),
                      Text(MoneyFormat.fromMinor(m.totalMinor, m.currency),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxV == 0 ? 0 : (m.totalMinor / maxV).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TopItemsList extends StatelessWidget {
  const _TopItemsList({required this.items, required this.currency, this.onTap});
  final List<TopItem> items;
  final Currency currency;

  /// Klik na artikal (drill-down). Null → red nije interaktivan.
  final void Function(TopItem)? onTap;

  @override
  Widget build(BuildContext context) {
    // Filtriramo stavke sa negativnim ukupnim iznosom (refundovani artikli).
    final positiveItems = items.where((it) => it.totalMinor > 0).toList();
    if (positiveItems.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final it in positiveItems)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: onTap == null ? null : () => onTap!(it),
            title: Text(it.name),
            subtitle: Text('×${it.count}'),
            trailing: Text(MoneyFormat.fromMinor(it.totalMinor, currency),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.items, required this.currency, this.onTap});
  final List<CategorySpending> items;
  final Currency currency;

  /// Klik na kategoriju (drill-down). Null → red nije interaktivan.
  final void Function(CategorySpending)? onTap;

  @override
  Widget build(BuildContext context) {
    final top = items.take(8).toList();
    final maxV = top.isEmpty
        ? 1
        : top.map((c) => c.totalMinor).reduce((a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final c in top)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CategoryTag(color: c.color, size: 16),
                          const SizedBox(width: 8),
                          Text(c.categoryName),
                        ],
                      ),
                      Text(MoneyFormat.fromMinor(c.totalMinor, currency),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:
                          maxV == 0 ? 0 : (c.totalMinor / maxV).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --- Drill-down (bottom sheet) ---

void _showMerchantSheet(BuildContext context, int merchantId, String name) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MerchantDetailSheet(merchantId: merchantId, name: name),
  );
}

void _showItemSheet(BuildContext context, String name) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemDetailSheet(name: name),
  );
}

void _showCategorySheet(BuildContext context, int categoryId, String name) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryDetailSheet(categoryId: categoryId, name: name),
  );
}

void _showCatalogSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _CatalogItemsSheet(),
  );
}

/// Zajednički okvir za drill-down sheet: naslov + skrolabilan sadržaj,
/// ograničen na 85% visine ekrana.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MerchantDetailSheet extends ConsumerWidget {
  const _MerchantDetailSheet({required this.merchantId, required this.name});
  final int merchantId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(merchantDetailProvider(merchantId));
    final currency = ref.watch(analyticsCurrencyProvider).value ?? Currency.rsd;
    return _SheetScaffold(
      title: name,
      child: async.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('${l10n.errGeneric}\n$e'),
        data: (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                        label: l10n.analyticsTotalSpent,
                        value: MoneyFormat.fromMinor(d.totalMinor, currency))),
                Expanded(
                    child: _StatTile(
                        label: l10n.analyticsAverage,
                        value: MoneyFormat.fromMinor(d.averageMinor, currency))),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.analyticsReceiptCount(d.receiptCount),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            if (d.monthly.isNotEmpty) ...[
              _Section(
                title: l10n.analyticsByMonth,
                child: _MonthlyChart(monthly: d.monthly),
              ),
            ],
            if (d.topItems.isNotEmpty)
              _Section(
                title: l10n.analyticsTopItems,
                child: _TopItemsList(
                  items: d.topItems,
                  currency: currency,
                  onTap: (it) => _showItemSheet(context, it.name),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemDetailSheet extends ConsumerStatefulWidget {
  const _ItemDetailSheet({required this.name});
  final String name;

  @override
  ConsumerState<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<_ItemDetailSheet> {
  late String _currentName = widget.name;
  String? _selectedMeasure;

  Future<void> _openMergeSheet(BuildContext context, ItemDetail detail) async {
    final canonicalId = detail.canonicalItemId;
    if (canonicalId == null) return;

    final repo = await ref.read(analyticsRepositoryProvider.future);
    final candidates = await repo.canonicalItemsForMerge(
      excludeCanonicalId: canonicalId,
    );
    if (!context.mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _MergeItemsSheet(
        targetCanonicalId: canonicalId,
        initialDisplayName: detail.name,
        candidates: candidates,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentName = result;
        _selectedMeasure = null;
      });
      ref.invalidate(itemDetailProvider);
      ref.invalidate(categoryItemsProvider);
      ref.invalidate(merchantDetailProvider);
      ref.invalidate(catalogItemsProvider);
    }
  }

  Future<void> _confirmUnmergeVariant(
    BuildContext context,
    ItemDetail detail,
    String rawName,
  ) async {
    final canonicalId = detail.canonicalItemId;
    if (canonicalId == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.analyticsUnmergeConfirmTitle),
        content: Text(l10n.analyticsUnmergeConfirmBody(rawName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.analyticsUnmergeAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = await ref.read(analyticsRepositoryProvider.future);
    await repo.unmergeRawVariant(
      canonicalItemId: canonicalId,
      rawName: rawName,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.analyticsUnmergeSuccess)),
    );
    ref.invalidate(itemDetailProvider);
    ref.invalidate(categoryItemsProvider);
    ref.invalidate(merchantDetailProvider);
    ref.invalidate(catalogItemsProvider);
  }

  Future<void> _changeCategory(BuildContext context, ItemDetail detail) async {
    final picked = await CategoryPickerSheet.show(
      context,
      currentCategoryId: detail.categoryId,
    );
    if (picked == null || !mounted) return;
    final catRepo = await ref.read(categoryRepositoryProvider.future);
    await catRepo.assignToItemsByName(
      detail.name,
      picked == CategoryPickerSheet.noneId ? null : picked,
    );
    ref.invalidate(itemDetailProvider);
    ref.invalidate(categoryItemsProvider);
    ref.invalidate(catalogItemsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(itemDetailProvider(_currentName));
    final currency =
        ref.watch(analyticsCurrencyProvider).value ?? Currency.rsd;
    final scheme = Theme.of(context).colorScheme;

    return _SheetScaffold(
      title: _currentName,
      child: async.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('${l10n.errGeneric}\n$e'),
        data: (d) {
          final measures = d.priceHistoryByMeasure.keys.toList();
          final activeMeasure = (_selectedMeasure != null &&
                  d.priceHistoryByMeasure.containsKey(_selectedMeasure))
              ? _selectedMeasure
              : (measures.isNotEmpty ? measures.first : null);
          final chartPoints = activeMeasure != null
              ? (d.priceHistoryByMeasure[activeMeasure] ?? d.priceHistory)
              : d.priceHistory;

          final activeMerchantStats = (activeMeasure != null &&
                  d.merchantStatsByMeasure.containsKey(activeMeasure))
              ? d.merchantStatsByMeasure[activeMeasure]!
              : d.overallMerchantStats;

          final showRawVariants = d.rawVariants.length > 1 ||
              (d.rawVariants.length == 1 && d.rawVariants.first != d.name);
          final canUnmerge =
              d.canonicalItemId != null && d.rawVariants.length > 1;

          // Raspon jedinične cene za trenutno aktivnu meru.
          int? minUnitPrice;
          int? maxUnitPrice;
          int? avgUnitPrice;
          int? latestUnitPrice;
          if (chartPoints.isNotEmpty) {
            var sumP = 0;
            for (final pt in chartPoints) {
              final p = pt.unitPriceMinor;
              if (p <= 0) continue;
              sumP += p;
              if (minUnitPrice == null || p < minUnitPrice) minUnitPrice = p;
              if (maxUnitPrice == null || p > maxUnitPrice) maxUnitPrice = p;
              latestUnitPrice = p;
            }
            if (minUnitPrice != null) {
              avgUnitPrice = (sumP / chartPoints.length).round();
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: _StatTile(
                          label: l10n.analyticsQuantity,
                          value: _formatQty(d.totalQuantity))),
                  Expanded(
                      child: _StatTile(
                          label: l10n.analyticsTotalSpent,
                          value:
                              MoneyFormat.fromMinor(d.totalMinor, currency))),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.analyticsPurchaseCount(d.purchaseCount),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: d.categoryColor != null
                            ? CategoryTag(color: d.categoryColor, size: 12)
                            : const Icon(Icons.label_outline, size: 15),
                        label: Text(
                          d.categoryName ?? l10n.categoryNone,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _changeCategory(context, d),
                      ),
                    ],
                  ),
                  if (d.canonicalItemId != null)
                    TextButton.icon(
                      onPressed: () => _openMergeSheet(context, d),
                      icon: const Icon(Icons.merge_type_rounded, size: 18),
                      label: Text(l10n.analyticsMergeButton),
                    ),
                ],
              ),
              if (d.averageDaysBetweenPurchases != null &&
                  d.estimatedMonthlyMinor != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.autorenew_rounded,
                          size: 18, color: scheme.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.analyticsHabitTitle}: ${l10n.analyticsHabitEveryDays(d.averageDaysBetweenPurchases!, MoneyFormat.fromMinor(d.estimatedMonthlyMinor!, currency))}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (showRawVariants) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.analyticsRawVariants,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final raw in d.rawVariants)
                      Container(
                        padding: EdgeInsets.only(
                          left: 8,
                          right: canUnmerge ? 4 : 8,
                          top: 4,
                          bottom: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                raw,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                            if (canUnmerge) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    _confirmUnmergeVariant(context, d, raw),
                                child: Tooltip(
                                  message: l10n.analyticsUnmergeTooltip,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.call_split_rounded,
                                      size: 14,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (d.priceHistoryByMeasure.length > 1) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final mKey in measures)
                      ChoiceChip(
                        label: Text(
                          mKey.isEmpty ? l10n.analyticsMeasureOther : mKey,
                        ),
                        selected: mKey == activeMeasure,
                        onSelected: (_) =>
                            setState(() => _selectedMeasure = mKey),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (minUnitPrice != null &&
                  avgUnitPrice != null &&
                  maxUnitPrice != null &&
                  latestUnitPrice != null)
                _Section(
                  title: l10n.analyticsPriceRangeTitle,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniPriceStat(
                            label: l10n.analyticsPriceMin,
                            value: MoneyFormat.fromMinor(minUnitPrice, currency),
                            valueColor: Colors.green.shade700,
                          ),
                        ),
                        Expanded(
                          child: _MiniPriceStat(
                            label: l10n.analyticsPriceAvg,
                            value: MoneyFormat.fromMinor(avgUnitPrice, currency),
                          ),
                        ),
                        Expanded(
                          child: _MiniPriceStat(
                            label: l10n.analyticsPriceMax,
                            value: MoneyFormat.fromMinor(maxUnitPrice, currency),
                            valueColor: minUnitPrice != maxUnitPrice
                                ? scheme.error
                                : null,
                          ),
                        ),
                        Expanded(
                          child: _MiniPriceStat(
                            label: l10n.analyticsPriceLatest,
                            value:
                                MoneyFormat.fromMinor(latestUnitPrice, currency),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (chartPoints.length >= 2)
                _Section(
                  title: l10n.analyticsPriceHistory,
                  child: _PriceHistoryChart(
                    points: chartPoints,
                    currency: currency,
                  ),
                ),
              if (d.measureComparisons.length >= 2)
                _Section(
                  title: l10n.analyticsPackageValueTitle,
                  child: Column(
                    children: [
                      for (final mc in d.measureComparisons)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mc.isBestValue
                                ? scheme.primaryContainer.withValues(alpha: 0.45)
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: mc.isBestValue
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    mc.measureLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(×${mc.purchaseCount})',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (mc.isBestValue) ...[
                                    const SizedBox(width: 8),
                                    _BadgePill(
                                      text: l10n.analyticsBestValueBadge,
                                      backgroundColor: scheme.primary,
                                      textColor: scheme.onPrimary,
                                    ),
                                  ],
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    l10n.analyticsNormalizedPrice(
                                      MoneyFormat.fromMinor(
                                        mc.normalizedPricePerBaseMinor,
                                        currency,
                                      ),
                                      mc.baseUnitLabel,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    l10n.analyticsMerchantAvgPrice(
                                      MoneyFormat.fromMinor(
                                        mc.avgUnitPriceMinor,
                                        currency,
                                      ),
                                    ),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (activeMerchantStats.isNotEmpty)
                _Section(
                  title: l10n.analyticsWhereBought,
                  child: _ItemMerchantComparisonList(
                    stats: activeMerchantStats,
                    currency: currency,
                    onTap: (m) => _showMerchantSheet(
                      context,
                      m.merchantId,
                      m.merchantName,
                    ),
                  ),
                )
              else if (d.byMerchant.isNotEmpty)
                _Section(
                  title: l10n.analyticsWhereBought,
                  child: _MerchantList(
                    merchants: d.byMerchant,
                    onTap: (m) => _showMerchantSheet(
                        context, m.merchantId, m.merchantName),
                  ),
                ),
              if (d.recentPurchases.isNotEmpty)
                _Section(
                  title: l10n.analyticsRecentPurchases,
                  child: Column(
                    children: [
                      for (final rec in d.recentPurchases.take(10))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onTap: rec.receiptId > 0
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ReceiptDetailScreen(
                                        receiptId: rec.receiptId,
                                      ),
                                    ),
                                  )
                              : null,
                          title: Text(
                            rec.merchantName.isNotEmpty
                                ? rec.merchantName
                                : rec.rawItemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              if (rec.date != null)
                                DateFormat('dd.MM.yyyy.').format(rec.date!),
                              '${_formatQty(rec.quantity)} × ${MoneyFormat.fromMinor(rec.unitPriceMinor, currency)}',
                            ].join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                MoneyFormat.fromMinor(rec.totalMinor, currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (rec.receiptId > 0) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _formatQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
}

class _MiniPriceStat extends StatelessWidget {
  const _MiniPriceStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ItemMerchantComparisonList extends StatelessWidget {
  const _ItemMerchantComparisonList({
    required this.stats,
    required this.currency,
    required this.onTap,
  });

  final List<ItemMerchantStats> stats;
  final Currency currency;
  final void Function(ItemMerchantStats) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxAvg = stats.isEmpty
        ? 1
        : stats.map((s) => s.avgUnitPriceMinor).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final s in stats)
          InkWell(
            onTap: s.merchantId > 0 ? () => onTap(s) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              s.merchantName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (s.isCheapest)
                              _BadgePill(
                                text: l10n.analyticsCheapestBadge,
                                backgroundColor: Colors.green.shade700,
                                textColor: Colors.white,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        l10n.analyticsMerchantAvgPrice(
                          MoneyFormat.fromMinor(s.avgUnitPriceMinor, currency),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.analyticsMerchantMinMaxPrice(
                            MoneyFormat.fromMinor(
                                s.minUnitPriceMinor, currency),
                            MoneyFormat.fromMinor(
                                s.latestUnitPriceMinor, currency),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '×${s.purchaseCount} • ${MoneyFormat.fromMinor(s.totalMinor, currency)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxAvg == 0
                          ? 0
                          : (s.avgUnitPriceMinor / maxAvg).clamp(0.0, 1.0),
                      minHeight: 5,
                      color: s.isCheapest ? Colors.green.shade700 : scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MergeItemsSheet extends ConsumerStatefulWidget {
  const _MergeItemsSheet({
    required this.targetCanonicalId,
    required this.initialDisplayName,
    required this.candidates,
  });

  final int targetCanonicalId;
  final String initialDisplayName;
  final List<CanonicalItemRow> candidates;

  @override
  ConsumerState<_MergeItemsSheet> createState() => _MergeItemsSheetState();
}

class _MergeItemsSheetState extends ConsumerState<_MergeItemsSheet> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.initialDisplayName);
  final Set<int> _selectedIds = <int>{};
  String _searchQuery = '';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty || _saving) return;
    setState(() => _saving = true);
    final customName = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : widget.initialDisplayName;
    try {
      final repo = await ref.read(analyticsRepositoryProvider.future);
      await repo.mergeCanonicalItems(
        targetCanonicalId: widget.targetCanonicalId,
        sourceCanonicalIds: _selectedIds.toList(),
        customDisplayName: customName,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analyticsMergeSuccess)),
      );
      Navigator.of(context).pop(customName);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _searchQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.candidates
        : widget.candidates
            .where((c) =>
                c.displayName.toLowerCase().contains(q) ||
                c.canonicalKey.toLowerCase().contains(q))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.analyticsMergeTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.analyticsMergeSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.analyticsMergeTargetName,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: l10n.analyticsMergeSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(l10n.analyticsMergeEmpty))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        final checked = _selectedIds.contains(item.id);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: checked,
                          title: Text(item.displayName),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(item.id);
                              } else {
                                _selectedIds.remove(item.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _selectedIds.isEmpty || _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.merge_type_rounded),
              label: Text(l10n.analyticsMergeConfirm),
            ),
          ],
        ),
      ),
    );
  }
}

/// Artikli jedne kategorije, sa ikonicom za premeštanje artikla u drugu
/// kategoriju (olakšava raspoređivanje). Tap na red otvara detalje artikla.
class _CategoryDetailSheet extends ConsumerWidget {
  const _CategoryDetailSheet({required this.categoryId, required this.name});
  final int categoryId;
  final String name;

  Future<void> _changeCategory(
      BuildContext context, WidgetRef ref, String itemName) async {
    final picked = await CategoryPickerSheet.show(
      context,
      currentCategoryId: categoryId == 0 ? null : categoryId,
    );
    if (picked == null) return; // odustao
    final repo = await ref.read(categoryRepositoryProvider.future);
    await repo.assignToItemsByName(
        itemName, picked == CategoryPickerSheet.noneId ? null : picked);
    // Osveži liste artikala po kategorijama (sažetak se osvežava sam,
    // preko stream-a koji prati izmene baze).
    ref.invalidate(categoryItemsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(categoryItemsProvider(categoryId));
    final currency = ref.watch(analyticsCurrencyProvider).value ?? Currency.rsd;
    return _SheetScaffold(
      title: name,
      child: async.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('${l10n.errGeneric}\n$e'),
        data: (items) => items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.analyticsEmpty),
              )
            : Column(
                children: [
                  for (final it in items)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _showItemSheet(context, it.name),
                      title: Text(it.name),
                      subtitle: Text('×${it.count}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(MoneyFormat.fromMinor(it.totalMinor, currency),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.drive_file_move_outlined,
                                size: 20),
                            tooltip: l10n.categoriesEdit,
                            onPressed: () =>
                                _changeCategory(context, ref, it.name),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PriceHistoryChart extends StatelessWidget {
  const _PriceHistoryChart({required this.points, this.currency = Currency.rsd});
  final List<PricePoint> points;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    MoneyFormat.fromDouble(s.y, currency),
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].unitPriceMinor / 100.0),
              ],
              isCurved: false,
              color: scheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

enum _CatalogSortMode {
  spent,
  frequency,
  priceJump,
  name,
}

/// Kompletan katalog kanonskih artikala sa pretragom (po kanonskom nazivu ili
/// sirovom tekstu sa računa), sortiranjem, filtriranjem po kategoriji i brzom
/// dodelom kategorije (Modul 2).
class _CatalogItemsSheet extends ConsumerStatefulWidget {
  const _CatalogItemsSheet();

  @override
  ConsumerState<_CatalogItemsSheet> createState() => _CatalogItemsSheetState();
}

class _CatalogItemsSheetState extends ConsumerState<_CatalogItemsSheet> {
  String _searchQuery = '';
  _CatalogSortMode _sortMode = _CatalogSortMode.spent;
  int? _selectedCategoryFilter; // null = Sve, 0 = Bez kategorije, >0 = ID kategorije

  Future<void> _assignCategory(
    BuildContext context,
    CatalogItemSummary item,
  ) async {
    final picked = await CategoryPickerSheet.show(
      context,
      currentCategoryId: item.categoryId,
    );
    if (picked == null || !mounted) return;
    final repo = await ref.read(categoryRepositoryProvider.future);
    await repo.assignToItemsByName(
      item.name,
      picked == CategoryPickerSheet.noneId ? null : picked,
    );
    ref.invalidate(catalogItemsProvider);
    ref.invalidate(categoryItemsProvider);
    ref.invalidate(itemDetailProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncItems = ref.watch(catalogItemsProvider);
    final currency =
        ref.watch(analyticsCurrencyProvider).value ?? Currency.rsd;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.analyticsAllItemsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: l10n.analyticsSearchItemsHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(l10n.analyticsSortSpent),
                      selected: _sortMode == _CatalogSortMode.spent,
                      onSelected: (_) =>
                          setState(() => _sortMode = _CatalogSortMode.spent),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(l10n.analyticsSortFrequency),
                      selected: _sortMode == _CatalogSortMode.frequency,
                      onSelected: (_) => setState(
                          () => _sortMode = _CatalogSortMode.frequency),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(l10n.analyticsSortPriceJump),
                      selected: _sortMode == _CatalogSortMode.priceJump,
                      onSelected: (_) => setState(
                          () => _sortMode = _CatalogSortMode.priceJump),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(l10n.analyticsSortName),
                      selected: _sortMode == _CatalogSortMode.name,
                      onSelected: (_) =>
                          setState(() => _sortMode = _CatalogSortMode.name),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: asyncItems.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('${l10n.errGeneric}\n$e')),
                  data: (allItems) {
                    // Izvuci dostupne kategorije iz artikala.
                    final distinctCategories = <int, (String, String?)>{};
                    var hasUncategorized = false;
                    for (final it in allItems) {
                      if (it.categoryId == null) {
                        hasUncategorized = true;
                      } else if (it.categoryName != null) {
                        distinctCategories[it.categoryId!] =
                            (it.categoryName!, it.categoryColor);
                      }
                    }

                    final q = _searchQuery.trim().toLowerCase();
                    final filtered = allItems.where((it) {
                      if (_selectedCategoryFilter != null) {
                        if (_selectedCategoryFilter == 0) {
                          if (it.categoryId != null) return false;
                        } else if (it.categoryId != _selectedCategoryFilter) {
                          return false;
                        }
                      }
                      if (q.isEmpty) return true;
                      if (it.name.toLowerCase().contains(q)) return true;
                      return it.rawVariants
                          .any((raw) => raw.toLowerCase().contains(q));
                    }).toList();

                    filtered.sort((a, b) {
                      switch (_sortMode) {
                        case _CatalogSortMode.spent:
                          return b.totalMinor.compareTo(a.totalMinor);
                        case _CatalogSortMode.frequency:
                          final byCount =
                              b.purchaseCount.compareTo(a.purchaseCount);
                          if (byCount != 0) return byCount;
                          return b.totalMinor.compareTo(a.totalMinor);
                        case _CatalogSortMode.priceJump:
                          final jumpA = a.priceChangePercent ?? -999999.0;
                          final jumpB = b.priceChangePercent ?? -999999.0;
                          final byJump = jumpB.compareTo(jumpA);
                          if (byJump != 0) return byJump;
                          return b.totalMinor.compareTo(a.totalMinor);
                        case _CatalogSortMode.name:
                          return a.name
                              .toLowerCase()
                              .compareTo(b.name.toLowerCase());
                      }
                    });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (distinctCategories.isNotEmpty || hasUncategorized) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  label: Text(l10n.analyticsFilterAllCategories),
                                  selected: _selectedCategoryFilter == null,
                                  onSelected: (_) => setState(
                                      () => _selectedCategoryFilter = null),
                                ),
                                const SizedBox(width: 6),
                                for (final entry
                                    in distinctCategories.entries) ...[
                                  FilterChip(
                                    avatar: CategoryTag(
                                      color: entry.value.$2,
                                      size: 12,
                                    ),
                                    label: Text(entry.value.$1),
                                    selected:
                                        _selectedCategoryFilter == entry.key,
                                    onSelected: (_) => setState(
                                      () => _selectedCategoryFilter =
                                          _selectedCategoryFilter == entry.key
                                              ? null
                                              : entry.key,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (hasUncategorized)
                                  FilterChip(
                                    label: Text(l10n.categoryNone),
                                    selected: _selectedCategoryFilter == 0,
                                    onSelected: (_) => setState(
                                      () => _selectedCategoryFilter =
                                          _selectedCategoryFilter == 0
                                              ? null
                                              : 0,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(child: Text(l10n.analyticsEmpty))
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final it = filtered[i];
                                    final pct = it.priceChangePercent;
                                    final showPct =
                                        pct != null && pct.abs() >= 1.0;
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      onTap: () =>
                                          _showItemSheet(context, it.name),
                                      title: Row(
                                        children: [
                                          if (it.categoryColor != null) ...[
                                            CategoryTag(
                                              color: it.categoryColor,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Expanded(
                                            child: Text(
                                              it.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (showPct) ...[
                                            const SizedBox(width: 6),
                                            _BadgePill(
                                              text:
                                                  '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(0)}%',
                                              backgroundColor: pct > 0
                                                  ? scheme.errorContainer
                                                  : Colors.green.shade100,
                                              textColor: pct > 0
                                                  ? scheme.onErrorContainer
                                                  : Colors.green.shade900,
                                            ),
                                          ],
                                        ],
                                      ),
                                      subtitle: Text(
                                        [
                                          '×${it.purchaseCount}',
                                          if (it.categoryName != null)
                                            it.categoryName!,
                                          if (it.rawVariants.length > 1)
                                            '${it.rawVariants.length} var.',
                                        ].join(' • '),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            MoneyFormat.fromMinor(
                                              it.totalMinor,
                                              currency,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: const Icon(
                                              Icons.drive_file_move_outlined,
                                              size: 20,
                                            ),
                                            tooltip: l10n.categoriesEdit,
                                            onPressed: () =>
                                                _assignCategory(context, it),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

