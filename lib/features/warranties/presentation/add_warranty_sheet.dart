import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../data/warranty_providers.dart';
import '../domain/warranty_status.dart';

/// Modalni formular za dodavanje garancije (po stavci ili za ceo račun).
class AddWarrantySheet extends ConsumerStatefulWidget {
  const AddWarrantySheet({
    super.key,
    required this.receiptId,
    required this.defaultTitle,
    required this.purchaseDate,
    this.lineItemId,
    this.existingProofImagePath,
  });

  final int receiptId;
  final int? lineItemId;
  final String defaultTitle;
  final DateTime purchaseDate;
  final String? existingProofImagePath;

  /// Otvara sheet; vraća true ako je garancija sačuvana.
  static Future<bool?> show(
    BuildContext context, {
    required int receiptId,
    required String defaultTitle,
    required DateTime purchaseDate,
    int? lineItemId,
    String? existingProofImagePath,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddWarrantySheet(
          receiptId: receiptId,
          defaultTitle: defaultTitle,
          purchaseDate: purchaseDate,
          lineItemId: lineItemId,
          existingProofImagePath: existingProofImagePath,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddWarrantySheet> createState() => _AddWarrantySheetState();
}

class _AddWarrantySheetState extends ConsumerState<AddWarrantySheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.defaultTitle);
  late final TextEditingController _duration = TextEditingController(
      text: '${WarrantyTiming.defaultDurationMonths}');
  final _note = TextEditingController();
  late DateTime _purchaseDate = widget.purchaseDate;
  String? _proofPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _proofPath = widget.existingProofImagePath;
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    // Kopiraj u trajni direktorijum aplikacije (dokaz se čuva).
    final dir = await getApplicationDocumentsDirectory();
    final proofs = Directory(p.join(dir.path, 'warranty_proofs'));
    await proofs.create(recursive: true);
    final dest = p.join(proofs.path,
        'proof_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}');
    await File(picked.path).copy(dest);
    if (mounted) setState(() => _proofPath = dest);
  }

  Future<void> _save() async {
    final months = int.tryParse(_duration.text.trim()) ??
        WarrantyTiming.defaultDurationMonths;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final repo = await ref.read(warrantyRepositoryProvider.future);
    await repo.create(
      receiptId: widget.receiptId,
      lineItemId: widget.lineItemId,
      title: _title.text.trim().isEmpty ? widget.defaultTitle : _title.text.trim(),
      purchaseDate: _purchaseDate,
      durationMonths: months,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      proofImagePath: _proofPath,
    );
    if (mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final df = DateFormat.yMMMd('sr');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.lineItemId != null
                  ? l10n.warrantyAddForItem
                  : l10n.warrantyAddForReceipt,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                  labelText: l10n.warrantyTitle,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('${l10n.warrantyPurchaseDate}: '
                        '${df.format(_purchaseDate)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _purchaseDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _purchaseDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: l10n.warrantyDuration,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                  labelText: l10n.warrantyNoteLabel,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(_proofPath != null
                  ? Icons.check_circle
                  : Icons.add_a_photo),
              label: Text(_proofPath != null
                  ? l10n.warrantyProofAttached
                  : l10n.warrantyAttachProof),
              onPressed: _pickProof,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.warrantyProofHint,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            Text(l10n.warrantyReminderInfo,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.warrantySave),
            ),
          ],
        ),
      ),
    );
  }
}
