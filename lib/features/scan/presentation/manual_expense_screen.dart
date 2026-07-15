import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/currency.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/providers/last_currency_controller.dart';
import '../../../core/utils/money_format.dart';
import '../../receipts/data/receipt_providers.dart';
import '../../receipts/presentation/receipt_detail_screen.dart';

/// Početne vrednosti za izmenu postojećeg ručnog (`isManual`) računa.
class ManualExpenseInitial {
  const ManualExpenseInitial({
    required this.receiptId,
    required this.merchantName,
    required this.date,
    required this.currency,
    this.paymentMethod,
    this.note,
    this.imagePath,
    this.items = const [],
  });

  final int receiptId;
  final String merchantName;
  final DateTime date;
  final Currency currency;
  final String? paymentMethod;
  final String? note;
  final String? imagePath;
  final List<({String name, int totalMinor})> items;
}

/// Forma za ručni unos troška. Radi u dva moda:
///  - novi unos (`initial == null`) → `saveManual`
///  - izmena ručnog/IPS računa (`initial != null`) → `updateManual`
class ManualExpenseScreen extends ConsumerStatefulWidget {
  const ManualExpenseScreen({super.key, this.initial});

  final ManualExpenseInitial? initial;

  bool get isEdit => initial != null;

  @override
  ConsumerState<ManualExpenseScreen> createState() =>
      _ManualExpenseScreenState();
}

class _ManualExpenseScreenState extends ConsumerState<ManualExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  Currency _currency = Currency.rsd;
  String? _paymentMethod;
  String? _imagePath;
  bool _busy = false;

  final _items = <_ExpenseItem>[];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _merchantController.text = initial.merchantName;
      _noteController.text = initial.note ?? '';
      _date = initial.date;
      _currency = initial.currency;
      _paymentMethod = initial.paymentMethod;
      _imagePath = initial.imagePath;
      for (final it in initial.items) {
        final item = _ExpenseItem();
        item.nameController.text = it.name;
        item.amountController.text = (it.totalMinor / 100).toStringAsFixed(2);
        item.amountController.addListener(_onAmountChanged);
        _items.add(item);
      }
    } else {
      _loadLastCurrency();
    }
  }

  Future<void> _loadLastCurrency() async {
    final last = await ref.read(lastCurrencyControllerProvider.future);
    if (mounted) setState(() => _currency = last);
  }

  void _onCurrencyChanged(Currency? value) {
    final currency = value ?? Currency.rsd;
    setState(() => _currency = currency);
    ref.read(lastCurrencyControllerProvider.notifier).setCurrency(currency);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _noteController.dispose();
    for (final item in _items) {
      item.amountController.removeListener(_onAmountChanged);
      item.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  int _computeTotalMinor() {
    int total = 0;
    for (final item in _items) {
      final d = double.tryParse(
          item.amountController.text.trim().replaceAll(',', '.'));
      if (d != null && d > 0) total += (d * 100).round();
    }
    return total;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imagePath = picked.path);
  }

  void _addItem() {
    final item = _ExpenseItem();
    item.amountController.addListener(_onAmountChanged);
    setState(() => _items.add(item));
  }

  void _removeItem(int index) {
    _items[index].amountController.removeListener(_onAmountChanged);
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final totalMinor = _computeTotalMinor();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (totalMinor <= 0) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.expenseTotalRequired)));
      return;
    }

    setState(() => _busy = true);
    final navigator = Navigator.of(context);

    try {
      final validItems = _items
          .where((i) =>
              i.nameController.text.trim().isNotEmpty &&
              i.amountController.text.trim().isNotEmpty)
          .map((i) => (
                name: i.nameController.text.trim(),
                totalMinor: (double.parse(
                                i.amountController.text
                                    .trim()
                                    .replaceAll(',', '.')) *
                            100)
                    .round(),
              ))
          .toList();

      final repo = await ref.read(receiptRepositoryProvider.future);
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();
      final initial = widget.initial;

      if (initial != null) {
        await repo.updateManual(
          receiptId: initial.receiptId,
          merchantName: _merchantController.text.trim(),
          totalMinor: totalMinor,
          date: _date,
          currency: _currency,
          paymentMethod: _paymentMethod,
          note: note,
          imagePath: _imagePath,
          items: validItems,
        );
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(l10n.expenseSaved)));
        navigator.pop();
        return;
      }

      final receiptId = await repo.saveManual(
        merchantName: _merchantController.text.trim(),
        totalMinor: totalMinor,
        date: _date,
        currency: _currency,
        paymentMethod: _paymentMethod,
        note: note,
        imagePath: _imagePath,
        items: validItems,
      );

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.expenseSaved)));
      await navigator.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ReceiptDetailScreen(receiptId: receiptId),
      ));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalMinor = _computeTotalMinor();

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isEdit ? l10n.expenseEditTitle : l10n.expenseTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            TextFormField(
              controller: _merchantController,
              decoration: InputDecoration(
                labelText: l10n.expenseMerchantName,
                hintText: l10n.expenseMerchantHint,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.expenseMerchantRequired
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.expenseDate),
              subtitle: Text(DateFormat('dd.MM.yyyy').format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Currency>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: l10n.expenseCurrency,
                      border: const OutlineInputBorder(),
                    ),
                    items: Currency.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.isoCode),
                            ))
                        .toList(),
                    onChanged: _onCurrencyChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _paymentMethod,
                    decoration: InputDecoration(
                      labelText: l10n.detailPaymentMethod,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(l10n.expensePaymentNotSpecified)),
                      DropdownMenuItem(
                          value: 'Gotovina',
                          child: Text(l10n.expensePaymentCash)),
                      DropdownMenuItem(
                          value: 'Kartica',
                          child: Text(l10n.expensePaymentCard)),
                      DropdownMenuItem(
                          value: 'Prenos',
                          child: Text(l10n.expensePaymentTransfer)),
                    ],
                    onChanged: (v) => _paymentMethod = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: l10n.detailNote,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            if (_imagePath != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_outlined),
                title: Text(l10n.warrantyProofAttached),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _imagePath = null),
                ),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_outlined),
                label: Text(l10n.detailAttachPhoto),
                onPressed: _pickPhoto,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(l10n.detailItems,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (totalMinor > 0)
                  Text(
                    MoneyFormat.fromMinor(totalMinor, _currency),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              _ItemRow(
                key: ObjectKey(_items[i]),
                item: _items[i],
                currency: _currency,
                l10n: l10n,
                onRemove: () => _removeItem(i),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.expenseAddItem),
              onPressed: _addItem,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.expenseSave),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseItem {
  final nameController = TextEditingController();
  final amountController = TextEditingController();

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.currency,
    required this.l10n,
    required this.onRemove,
  });

  final _ExpenseItem item;
  final Currency currency;
  final AppLocalizations l10n;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: item.nameController,
              decoration: InputDecoration(
                labelText: l10n.expenseItemName,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '';
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: item.amountController,
              decoration: InputDecoration(
                labelText: '${l10n.expenseAmount} (${currency.isoCode})',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '';
                final d = double.tryParse(v.trim().replaceAll(',', '.'));
                if (d == null || d <= 0) return '';
                return null;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
