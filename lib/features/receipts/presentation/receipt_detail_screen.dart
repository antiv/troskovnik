import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart' show LineItemRow;
import '../../../core/db/enums.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/utils/money_format.dart';
import '../../warranties/presentation/add_warranty_sheet.dart';
import '../data/receipt_providers.dart';
import 'receipt_detail_controller.dart';
import 'widgets/items_status_badge.dart';

/// Otvara formular za dodavanje garancije.
Future<void> _addWarranty(
  BuildContext context, {
  required int receiptId,
  required String defaultTitle,
  required DateTime purchaseDate,
  int? lineItemId,
  String? proofImagePath,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final saved = await AddWarrantySheet.show(
    context,
    receiptId: receiptId,
    defaultTitle: defaultTitle,
    purchaseDate: purchaseDate,
    lineItemId: lineItemId,
    existingProofImagePath: proofImagePath,
  );
  if (saved == true) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.warrantyReminderInfo)));
  }
}

/// Detalj računa: zaglavlje, porez, stavke ili „u obradi" + Osveži (sekcija 7, ekran 4).
class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final int receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(receiptDetailProvider(receiptId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.detailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.detailDeleteReceipt,
            onPressed: () => _confirmDeleteReceipt(context, ref),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.errGeneric}\n$e')),
        data: (detail) {
          if (detail == null) {
            return Center(child: Text(l10n.errGeneric));
          }
          return _DetailBody(detail: detail);
        },
      ),
    );
  }

  Future<void> _confirmDeleteReceipt(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.detailDeleteReceiptConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.detailDeleteReceipt)),
        ],
      ),
    );
    if (ok != true) return;
    await deleteReceipt(ref, receiptId);
    navigator.pop();
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});
  final ReceiptDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final r = detail.receipt;
    final pending = r.itemsStatus == ItemsStatus.pendingServer;

    return ListView(
      // Donji safe-area inset da poslednji red (poslovni račun) ne ostane
      // ispod Android sistemske navigacije.
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
      children: [
        // Zaglavlje
        Text(detail.merchant.name,
            style: Theme.of(context).textTheme.titleLarge),
        if (detail.merchant.address != null)
          Text(detail.merchant.address!),
        const SizedBox(height: 4),
        Text('PIB: ${detail.merchant.tin}'),
        if (r.buyerId != null)
          Text('${l10n.detailBuyerId}: ${r.buyerId}'),
        if (r.pfrNumber != null) Text('${l10n.manualPfrNumber}: ${r.pfrNumber}'),
        if (r.pfrTime != null)
          Text('${l10n.manualPfrTime}: ${r.pfrTime}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(MoneyFormat.fromMinor(r.totalAmount),
                style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            ItemsStatusBadge(
                fetchStatus: r.fetchStatus, itemsStatus: r.itemsStatus),
          ],
        ),
        const Divider(height: 24),

        // Granični slučaj: stavke u obradi (sekcija 5 UI tretman).
        if (pending) ...[
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.detailPendingExplain),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _RefreshButton(receiptId: r.id),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Stavke
        Row(
          children: [
            Text(l10n.detailItems,
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: Text(l10n.warrantyAddForReceipt),
              onPressed: () => _addWarranty(
                context,
                receiptId: r.id,
                defaultTitle: detail.merchant.name,
                purchaseDate: r.pfrTime ?? r.createdAt,
                proofImagePath: r.imagePath,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (detail.items.isEmpty && !pending)
          Text(l10n.resultItemsPending)
        else
          ...detail.items.map((it) => _ItemTile(
                item: it,
                l10n: l10n,
                onAddWarranty: () => _addWarranty(
                  context,
                  receiptId: r.id,
                  lineItemId: it.id,
                  defaultTitle: it.name,
                  purchaseDate: r.pfrTime ?? r.createdAt,
                  proofImagePath: r.imagePath,
                ),
              )),

        // Način plaćanja (uklj. kombinovano)
        if (r.paymentsJson != null || r.paymentMethod != null) ...[
          const Divider(height: 24),
          Text(l10n.detailPaymentMethod,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _PaymentBreakdown(
              paymentsJson: r.paymentsJson, paymentMethod: r.paymentMethod),
        ],

        // Obračun poreza
        if (r.taxJson != null) ...[
          const Divider(height: 24),
          Text(l10n.detailTaxBreakdown,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TaxBreakdown(taxJson: r.taxJson!),
        ],

        const Divider(height: 24),

        // Dokaz (sačuvan žurnal + zvanični SUF link) — #5
        Text(l10n.detailProof,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l10n.detailProofHint,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(l10n.detailOpenOnSuf),
          onPressed: () => _openOnSuf(context, r.verificationUrl),
        ),

        const Divider(height: 24),

        // Poslovni račun
        SwitchListTile(
          title: Text(l10n.detailMarkBusiness),
          value: r.isBusiness,
          onChanged: (v) async {
            final repo = await ref.read(receiptRepositoryProvider.future);
            await repo.setBusiness(r.id, v);
          },
        ),
      ],
    );
  }

  Future<void> _openOnSuf(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }
}

class _RefreshButton extends ConsumerStatefulWidget {
  const _RefreshButton({required this.receiptId});
  final int receiptId;

  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: _busy ? null : _refresh,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh),
      label: Text(l10n.detailRefreshNow),
    );
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final svc = await ref.read(refetchServiceProvider.future);
      final ok = await svc.refetchOne(widget.receiptId);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? l10n.detailItemsRefreshed : l10n.errPortalUnavailable),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.l10n,
    required this.onAddWarranty,
  });
  final LineItemRow item;
  final AppLocalizations l10n;
  final VoidCallback onAddWarranty;

  @override
  Widget build(BuildContext context) {
    if (item.isUnparsed) {
      return ListTile(
        dense: true,
        leading: const Icon(Icons.help_outline, size: 18),
        title: Text(item.name),
        subtitle: Text(l10n.detailUnparsedRow),
      );
    }
    final qty = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    return ListTile(
      dense: true,
      title: Text(item.name),
      subtitle: Text(
          '$qty × ${MoneyFormat.fromMinor(item.unitPrice)}'
          '${item.taxLabel != null ? '  (${item.taxLabel})' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(MoneyFormat.fromMinor(item.total)),
          IconButton(
            tooltip: l10n.warrantyAddForItem,
            icon: const Icon(Icons.shield_outlined, size: 18),
            onPressed: onAddWarranty,
          ),
        ],
      ),
    );
  }
}

class _PaymentBreakdown extends StatelessWidget {
  const _PaymentBreakdown({required this.paymentsJson, required this.paymentMethod});
  final String? paymentsJson;
  final String? paymentMethod;

  @override
  Widget build(BuildContext context) {
    // Strukturirani breakdown (uklj. kombinovano plaćanje).
    if (paymentsJson != null) {
      Map<String, dynamic> map;
      try {
        map = jsonDecode(paymentsJson!) as Map<String, dynamic>;
      } catch (_) {
        map = const {};
      }
      if (map.isNotEmpty) {
        return Column(
          children: map.entries
              .map((e) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key),
                      Text(MoneyFormat.fromMinor((e.value as num).toInt()),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ))
              .toList(),
        );
      }
    }
    // Fallback: samo naziv (stari računi bez iznosa).
    if (paymentMethod != null) return Text(paymentMethod!);
    return const SizedBox.shrink();
  }
}

class _TaxBreakdown extends StatelessWidget {
  const _TaxBreakdown({required this.taxJson});
  final String taxJson;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> map;
    try {
      map = jsonDecode(taxJson) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }
    return Column(
      children: map.entries
          .map((e) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key),
                  Text('${e.value}%'),
                ],
              ))
          .toList(),
    );
  }
}
