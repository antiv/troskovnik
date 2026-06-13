import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/widgets/clearable_search_field.dart';
import '../../../core/widgets/image_viewer_screen.dart';
import '../../receipts/presentation/receipt_detail_screen.dart';
import '../data/warranty_providers.dart';
import '../data/warranty_repository.dart';
import '../domain/warranty_status.dart';
import 'add_warranty_sheet.dart';
import 'widgets/warranty_status_badge.dart';

/// Lista praćenih garancija, sortirana po roku isteka, sa bedžom statusa.
class WarrantyListScreen extends ConsumerWidget {
  const WarrantyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final listAsync = ref.watch(filteredWarrantyListProvider);
    final search = ref.watch(warrantySearchProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ClearableSearchField(
            hintText: l10n.warrantiesSearchHint,
            initialText: search,
            onChanged: (v) =>
                ref.read(warrantySearchProvider.notifier).set(v),
          ),
        ),
        Expanded(
          child: listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${l10n.errGeneric}\n$e')),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      search.trim().isEmpty
                          ? l10n.warrantiesEmpty
                          : l10n.searchNoResults,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _WarrantyTile(view: items[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WarrantyTile extends ConsumerWidget {
  const _WarrantyTile({required this.view});
  final WarrantyView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat.yMMMd('sr');
    final status = view.status();
    final w = view.warranty;
    final daysLeft = WarrantyTiming.daysLeft(w.expiryDate);

    final hasProof =
        w.proofImagePath != null && File(w.proofImagePath!).existsSync();
    return ListTile(
      leading: hasProof
          ? GestureDetector(
              onTap: () => ImageViewerScreen.open(context,
                  imagePath: w.proofImagePath!, title: w.title),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(w.proofImagePath!),
                    width: 44, height: 44, fit: BoxFit.cover),
              ),
            )
          : const Icon(Icons.shield_outlined, size: 36),
      title: Text(w.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${view.merchantName} · ${l10n.warrantyExpiresOn(df.format(w.expiryDate))}'),
          if (status != WarrantyStatus.expired)
            Text(l10n.warrantyDaysLeft(daysLeft),
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: status != WarrantyStatus.expired,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          WarrantyStatusBadge(status: status),
          const SizedBox(height: 2),
          // Ulaz za prikaz povezanog računa — samo ikona, vizuelno usklađen
          // sa bedžom statusa iznad.
          Tooltip(
            message: l10n.warrantyOpenReceipt,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReceiptDetailScreen(receiptId: w.receiptId),
                ),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
      // Tap → izmena u istoj formi kao unos (#4).
      onTap: () => AddWarrantySheet.show(
        context,
        receiptId: w.receiptId,
        defaultTitle: w.title,
        purchaseDate: w.purchaseDate,
        lineItemId: w.lineItemId,
        existing: w,
      ),
      onLongPress: () => _confirmDelete(context, ref, w.id),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, int id) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.warrantyDeleteConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.warrantyDelete)),
        ],
      ),
    );
    if (ok == true) {
      final repo = await ref.read(warrantyRepositoryProvider.future);
      await repo.delete(id);
    }
  }
}
