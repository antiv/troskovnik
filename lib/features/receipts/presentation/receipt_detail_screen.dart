import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart' show LineItemRow, LineItemsCompanion;
import '../../../core/db/enums.dart';
import '../../../core/domain/currency.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/utils/money_format.dart';
import '../../categories/data/category_providers.dart';
import '../../categories/presentation/category_picker_sheet.dart';
import '../../categories/presentation/category_tag.dart';
import '../../scan/presentation/manual_expense_screen.dart';
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

/// Otvara picker za dodeljivanje kategorije stavci.
Future<void> _pickCategory(
  BuildContext context,
  WidgetRef ref,
  LineItemRow item,
) async {
  final categoryId = await CategoryPickerSheet.show(
    context,
    currentCategoryId: item.categoryId,
  );
  final repo = await ref.read(receiptRepositoryProvider.future);
  await (repo.db.update(repo.db.lineItems)..where((i) => i.id.equals(item.id)))
      .write(LineItemsCompanion(
    categoryId: Value(categoryId),
  ));
}

/// Dodeljuje jednu kategoriju svim stavkama računa.
Future<void> _categorizeAll(
  BuildContext context,
  WidgetRef ref,
  int receiptId,
) async {
  final categoryId = await CategoryPickerSheet.show(context);
  if (categoryId == null) return;
  final catRepo = await ref.read(categoryRepositoryProvider.future);
  await catRepo.assignToReceipt(receiptId, categoryId);
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
          if (detailAsync.value?.receipt.isManual ?? false)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.detailEditReceipt,
              onPressed: () => _editReceipt(context, detailAsync.value!),
            ),
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

  /// Otvara formu za izmenu ručnog (`isManual`) računa, popunjenu trenutnim
  /// vrednostima. Forma je ista kao za novi unos (create/edit mod).
  void _editReceipt(BuildContext context, ReceiptDetail detail) {
    final r = detail.receipt;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ManualExpenseScreen(
        initial: ManualExpenseInitial(
          receiptId: r.id,
          merchantName: detail.merchant.name,
          date: r.pfrTime ?? r.createdAt,
          currency: r.currency,
          paymentMethod: r.paymentMethod,
          note: r.note,
          imagePath: r.imagePath,
          items: [
            for (final i in detail.items) (name: i.name, totalMinor: i.total),
          ],
        ),
      ),
    ));
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
          12, 16, 8, 16 + MediaQuery.viewPaddingOf(context).bottom),
      children: [
        // Zaglavlje
        Text(detail.merchant.name,
            style: Theme.of(context).textTheme.titleLarge),
        if (detail.merchant.address != null)
          Text(detail.merchant.address!),
        const SizedBox(height: 4),
        if (!r.isManual) Text('PIB: ${detail.merchant.tin}'),
        if (r.buyerId != null)
          Text('${l10n.detailBuyerId}: ${r.buyerId}'),
        if (r.pfrNumber != null) Text('${l10n.manualPfrNumber}: ${r.pfrNumber}'),
        if (r.pfrTime != null)
          r.isManual
              ? Text('${l10n.expenseDate}: ${DateFormat('dd.MM.yyyy').format(r.pfrTime!)}')
              : Text('${l10n.manualPfrTime}: ${r.pfrTime}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(MoneyFormat.fromMinor(r.totalAmount, r.currency),
                style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            ItemsStatusBadge(
                fetchStatus: r.fetchStatus, itemsStatus: r.itemsStatus),
          ],
        ),
        const Divider(height: 24),

        // Upozorenje: parsirani podaci se ne slažu sa invoiceResult.
        if (r.hasDiscrepancy) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.detailDiscrepancyWarning,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Granični slučaj: stavke u obradi (sekcija 5 UI tretman).
        if (pending) ...[
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.itemsStatus == ItemsStatus.fromJournal
                      ? l10n.detailFromJournalExplain
                      : l10n.detailPendingExplain),
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
        Text(l10n.detailItems,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        // Akcije u Wrap-u da se preliju u novi red na uskim ekranima.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (!pending && detail.items.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.local_offer_outlined, size: 18),
                label: Text(l10n.categoryAssignAll),
                onPressed: () => _categorizeAll(context, ref, r.id),
              ),
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
        if (detail.items.isEmpty && !pending && !r.isManual)
          Text(l10n.resultItemsPending)
        else
          ...detail.items.map((it) => _ItemTile(
                item: it,
                currency: r.currency,
                l10n: l10n,
                onAddWarranty: () => _addWarranty(
                  context,
                  receiptId: r.id,
                  lineItemId: it.id,
                  defaultTitle: it.name,
                  purchaseDate: r.pfrTime ?? r.createdAt,
                  proofImagePath: r.imagePath,
                ),
                onCategoryTap: () => _pickCategory(context, ref, it),
              )),

        // Način plaćanja (uklj. kombinovano)
        if (r.paymentsJson != null || r.paymentMethod != null) ...[
          const Divider(height: 24),
          Text(l10n.detailPaymentMethod,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _PaymentBreakdown(
              paymentsJson: r.paymentsJson,
              paymentMethod: r.paymentMethod,
              currency: r.currency),
        ],

        // Obračun poreza
        if (r.taxJson != null) ...[
          const Divider(height: 24),
          Text(l10n.detailTaxBreakdown,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TaxBreakdown(taxJson: r.taxJson!),
        ],

        // Dokaz (sačuvan žurnal + zvanični SUF link) — #5
        // Za ručne unose nema TaxCore linka ni refresh dugmeta.
        if (!r.isManual) ...[
          const Divider(height: 24),
          Text(l10n.detailProof,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.detailProofHint,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.detailOpenOnSuf),
                  onPressed: () => _openOnSuf(context, r.verificationUrl),
                ),
              ),
              const SizedBox(width: 8),
              // Ručni refresh dostupan i za već učitan račun (uz potvrdu) —
              // ponovo povuče zaglavlje/stavke, a kategorije/garancije se čuvaju.
              _RefreshButton(receiptId: r.id, iconOnly: true, confirm: true),
            ],
          ),
        ],

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
  const _RefreshButton({
    required this.receiptId,
    this.iconOnly = false,
    this.confirm = false,
  });
  final int receiptId;

  /// Prikaži kao ikonicu (za Proof sekciju) umesto punog dugmeta.
  final bool iconOnly;

  /// Traži potvrdu pre osvežavanja (za već učitan račun).
  final bool confirm;

  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.iconOnly) {
      return IconButton(
        tooltip: l10n.detailRefreshTooltip,
        onPressed: _busy ? null : _refresh,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh),
      );
    }
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
    final l10nConfirm = AppLocalizations.of(context);
    if (widget.confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10nConfirm.detailRefreshConfirmBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10nConfirm.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10nConfirm.detailRefreshNow)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
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

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.item,
    required this.currency,
    required this.l10n,
    required this.onAddWarranty,
    required this.onCategoryTap,
  });
  final LineItemRow item;
  final Currency currency;
  final AppLocalizations l10n;
  final VoidCallback onAddWarranty;
  final VoidCallback onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    Color? categoryColor;
    if (item.categoryId != null) {
      final cats = ref.watch(categoriesProvider).value;
      final match = cats?.where((c) => c.id == item.categoryId);
      if (match != null && match.isNotEmpty) {
        categoryColor = parseCategoryColor(match.first.color);
      }
    }

    return ListTile(
      dense: true,
      title: Tooltip(
        message: item.name,
        child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
                '$qty × ${MoneyFormat.fromMinor(item.unitPrice, currency)}'
                '${item.taxLabel != null ? '  (${item.taxLabel})' : ''}',
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: l10n.categoryAssign,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: onCategoryTap,
            icon: Icon(
              item.categoryId != null
                  ? Icons.local_offer
                  : Icons.local_offer_outlined,
              size: 18,
              color: categoryColor ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(MoneyFormat.fromMinor(item.total, currency)),
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
  const _PaymentBreakdown({
    required this.paymentsJson,
    required this.paymentMethod,
    this.currency = Currency.rsd,
  });
  final String? paymentsJson;
  final String? paymentMethod;
  final Currency currency;

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
                      Text(MoneyFormat.fromMinor((e.value as num).toInt(), currency),
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
