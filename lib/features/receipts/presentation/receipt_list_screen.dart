import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/utils/money_format.dart';
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
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.receiptsSearchHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      ref.read(receiptQueryProvider.notifier).setSearch(v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ReceiptSort>(
                icon: const Icon(Icons.sort),
                initialValue: query.sort,
                onSelected: (s) =>
                    ref.read(receiptQueryProvider.notifier).setSort(s),
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: ReceiptSort.date,
                      child: Text(l10n.receiptsSortDate)),
                  PopupMenuItem(
                      value: ReceiptSort.merchant,
                      child: Text(l10n.receiptsSortMerchant)),
                  PopupMenuItem(
                      value: ReceiptSort.amount,
                      child: Text(l10n.receiptsSortAmount)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: listAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
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
                  return ListTile(
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
                          MoneyFormat.fromMinor(item.receipt.totalAmount),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
