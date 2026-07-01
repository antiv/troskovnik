import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/clearable_search_field.dart';
import '../../../core/widgets/currency_picker.dart';
import '../data/receipt_providers.dart';
import 'receipt_detail_screen.dart';
import 'receipt_list_controller.dart';
import 'widgets/items_status_badge.dart';

/// Lista računa: pretraga + sortiranje + bedž stanja (sekcija 7, ekran 3).
class ReceiptListScreen extends ConsumerWidget {
  const ReceiptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final listAsync = ref.watch(receiptListProvider);
    final query = ref.watch(receiptQueryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ClearableSearchField(
                  hintText: l10n.receiptsSearchHint,
                  initialText: query.search,
                  onChanged: (v) =>
                      ref.read(receiptQueryProvider.notifier).setSearch(v),
                ),
              ),
              const SizedBox(width: 8),
              ref.watch(receiptCurrenciesProvider).whenData((currencies) {
                    if (currencies.length <= 1) return const SizedBox.shrink();
                    return CurrencyPicker(
                      currencies: currencies,
                      selected: query.currency,
                      allLabel: l10n.receiptFilterAll,
                      onSelected: (c) => ref
                          .read(receiptQueryProvider.notifier)
                          .setCurrency(c),
                    );
                  }).value ??
                  const SizedBox.shrink(),
              PopupMenuButton<ReceiptSort>(
                icon: const Icon(Icons.sort),
                initialValue: query.sort,
                onSelected: (s) =>
                    ref.read(receiptQueryProvider.notifier).setSort(s),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ReceiptSort.date,
                    child: Text(l10n.receiptsSortDate),
                  ),
                  PopupMenuItem(
                    value: ReceiptSort.merchant,
                    child: Text(l10n.receiptsSortMerchant),
                  ),
                  PopupMenuItem(
                    value: ReceiptSort.amount,
                    child: Text(l10n.receiptsSortAmount),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Filter poslovni/privatni/svi (#8)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<ReceiptKindFilter>(
            segments: [
              ButtonSegment(
                value: ReceiptKindFilter.all,
                label: Text(l10n.receiptFilterAll),
              ),
              ButtonSegment(
                value: ReceiptKindFilter.business,
                label: Text(l10n.receiptFilterBusiness),
              ),
              ButtonSegment(
                value: ReceiptKindFilter.personal,
                label: Text(l10n.receiptFilterPersonal),
              ),
            ],
            selected: {query.kind},
            onSelectionChanged: (s) =>
                ref.read(receiptQueryProvider.notifier).setKind(s.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${l10n.errGeneric}\n$e')),
            data: (items) {
              if (items.isEmpty) {
                return Center(child: Text(l10n.receiptsEmpty));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final scheme = Theme.of(context).colorScheme;
                  // Iste boje kao analitika: poslovno=tercijarna, lično=primarna.
                  final kindColor = item.receipt.isBusiness
                      ? scheme.tertiary
                      : scheme.primary;
                  return Dismissible(
                    key: ValueKey(item.receipt.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: scheme.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete, color: scheme.onErrorContainer),
                    ),
                    confirmDismiss: (_) => _confirmDeleteReceipt(context, ref),
                    onDismissed: (_) => deleteReceipt(ref, item.receipt.id),
                    child: ListTile(
                      leading: item.receipt.isManual
                          ? Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: scheme.outline,
                            )
                          : Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: kindColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                      title: Text(item.merchant.name),
                      subtitle: Text(
                        item.receipt.pfrTime?.toString().split('.').first ??
                            item.receipt.createdAt.toString().split('.').first,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            MoneyFormat.fromMinor(
                              item.receipt.totalAmount,
                              item.receipt.currency,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          if (item.receipt.hasDiscrepancy)
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ItemsStatusBadge(
                            fetchStatus: item.receipt.fetchStatus,
                            itemsStatus: item.receipt.itemsStatus,
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ReceiptDetailScreen(receiptId: item.receipt.id),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmDeleteReceipt(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.detailDeleteReceiptConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.detailDeleteReceipt),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
