import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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
import '../data/analytics_providers.dart';
import '../data/analytics_repository.dart' show AnalyticsRepository;
import '../domain/analytics_models.dart';

/// Ekran analitike potrošnje (MVP, nad postojećim podacima — bez kategorija).
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final selectedCurrency = ref.watch(analyticsCurrencyProvider);

    // Dostupne valute (prazno dok se učitava).
    final availableCurrencies = summaryAsync
            .whenData((s) => s.totalsByCurrency.keys.toList())
            .value ??
        const <Currency>[];
    final activeCurrency = availableCurrencies.contains(selectedCurrency)
        ? selectedCurrency!
        : (availableCurrencies.isNotEmpty ? availableCurrencies.first : Currency.rsd);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: SegmentedButton<AnalyticsRange>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
              value: AnalyticsRange.last3Months,
              label: Text(l10n.analyticsRange3m)),
          ButtonSegment(
              value: AnalyticsRange.last12Months,
              label: Text(l10n.analyticsRange12m)),
          ButtonSegment(
              value: AnalyticsRange.all, label: Text(l10n.analyticsRangeAll)),
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
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: const Icon(Icons.file_download_outlined),
        tooltip: l10n.exportCsv,
        onPressed: () => _showExportSheet(context, ref),
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
    final currency = ref.watch(analyticsCurrencyProvider) ?? Currency.rsd;
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

class _ItemDetailSheet extends ConsumerWidget {
  const _ItemDetailSheet({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(itemDetailProvider(name));
    final currency = ref.watch(analyticsCurrencyProvider) ?? Currency.rsd;
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
                        label: l10n.analyticsQuantity,
                        value: _formatQty(d.totalQuantity))),
                Expanded(
                    child: _StatTile(
                        label: l10n.analyticsTotalSpent,
                        value: MoneyFormat.fromMinor(d.totalMinor, currency))),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.analyticsPurchaseCount(d.purchaseCount),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            if (d.priceHistory.length >= 2)
              _Section(
                title: l10n.analyticsPriceHistory,
                child: _PriceHistoryChart(points: d.priceHistory, currency: currency),
              ),
            if (d.byMerchant.isNotEmpty)
              _Section(
                title: l10n.analyticsWhereBought,
                child: _MerchantList(
                  merchants: d.byMerchant,
                  onTap: (m) =>
                      _showMerchantSheet(context, m.merchantId, m.merchantName),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
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
    final currency = ref.watch(analyticsCurrencyProvider) ?? Currency.rsd;
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
