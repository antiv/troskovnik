import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../data/advanced_analytics_providers.dart';
import '../../domain/advanced_analytics_models.dart';

/// Traka sa filterima za naprednu analitiku: izbor perioda, poslovno/lično i kategorija.
class AdvancedFilterBar extends ConsumerWidget {
  const AdvancedFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(advancedAnalyticsFilterProvider);
    final notifier = ref.read(advancedAnalyticsFilterProvider.notifier);

    String presetLabel(AdvancedAnalyticsDatePreset preset) {
      return switch (preset) {
        AdvancedAnalyticsDatePreset.thisMonth => l10n.advancedPresetThisMonth,
        AdvancedAnalyticsDatePreset.lastMonth => l10n.advancedPresetLastMonth,
        AdvancedAnalyticsDatePreset.last30Days => l10n.advancedPresetLast30Days,
        AdvancedAnalyticsDatePreset.last90Days => l10n.advancedPresetLast90Days,
        AdvancedAnalyticsDatePreset.thisYear => l10n.advancedPresetThisYear,
        AdvancedAnalyticsDatePreset.lastYear => l10n.advancedPresetLastYear,
        AdvancedAnalyticsDatePreset.all => l10n.advancedPresetAll,
        AdvancedAnalyticsDatePreset.custom => filter.customFrom != null && filter.customTo != null
            ? '${DateFormat('dd.MM').format(filter.customFrom!)} - ${DateFormat('dd.MM.yy').format(filter.customTo!)}'
            : l10n.advancedPresetCustom,
      };
    }

    Future<void> pickCustomRange() async {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: filter.customFrom != null && filter.customTo != null
            ? DateTimeRange(start: filter.customFrom!, end: filter.customTo!)
            : DateTimeRange(
                start: DateTime(now.year, now.month, 1),
                end: now,
              ),
      );
      if (picked != null) {
        notifier.setCustomRange(picked.start, picked.end);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Period dropdown / chip.
              PopupMenuButton<AdvancedAnalyticsDatePreset>(
                tooltip: l10n.exportCustomPeriod,
                onSelected: (preset) {
                  if (preset == AdvancedAnalyticsDatePreset.custom) {
                    pickCustomRange();
                  } else {
                    notifier.setPreset(preset);
                  }
                },
                itemBuilder: (context) => [
                  for (final p in AdvancedAnalyticsDatePreset.values)
                    PopupMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          Icon(
                            p == filter.preset ? Icons.check : Icons.date_range,
                            size: 18,
                            color: p == filter.preset
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(presetLabel(p)),
                        ],
                      ),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    presetLabel(filter.preset),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
                  onDeleted: () {}, // Samo da prikaže strelicu
                ),
              ),
              const SizedBox(width: 8),
              // Segmented filter poslovno/lično.
              SegmentedButton<AnalyticsBusinessFilter>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: AnalyticsBusinessFilter.all,
                    label: Text(l10n.receiptFilterAll, style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: AnalyticsBusinessFilter.personalOnly,
                    label: Text(l10n.receiptFilterPersonal, style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: AnalyticsBusinessFilter.businessOnly,
                    label: Text(l10n.receiptFilterBusiness, style: const TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {filter.businessFilter},
                onSelectionChanged: (set) => notifier.setBusinessFilter(set.first),
              ),
              if (filter.categoryId != null) ...[
                const SizedBox(width: 8),
                InputChip(
                  label: Text(l10n.categoryAssign),
                  onDeleted: () => notifier.setCategory(null),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
