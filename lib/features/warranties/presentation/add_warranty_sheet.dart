import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart' show WarrantyRow;
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/widgets/image_viewer_screen.dart';
import '../data/warranty_providers.dart';
import '../domain/warranty_status.dart';

/// Modalni formular za dodavanje ILI izmenu garancije (#4: ista forma).
class AddWarrantySheet extends ConsumerStatefulWidget {
  const AddWarrantySheet({
    super.key,
    required this.receiptId,
    required this.defaultTitle,
    required this.purchaseDate,
    this.lineItemId,
    this.existingProofImagePath,
    this.existing,
  });

  final int receiptId;
  final int? lineItemId;
  final String defaultTitle;
  final DateTime purchaseDate;
  final String? existingProofImagePath;

  /// Postojeća garancija za izmenu (null = nova).
  final WarrantyRow? existing;

  /// Otvara sheet; vraća true ako je sačuvano/obrisano (lista treba refresh).
  static Future<bool?> show(
    BuildContext context, {
    required int receiptId,
    required String defaultTitle,
    required DateTime purchaseDate,
    int? lineItemId,
    String? existingProofImagePath,
    WarrantyRow? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Builder dobija svoj context čiji viewInsets reaguju na tastaturu (#3).
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AddWarrantySheet(
          receiptId: receiptId,
          defaultTitle: defaultTitle,
          purchaseDate: purchaseDate,
          lineItemId: lineItemId,
          existingProofImagePath: existingProofImagePath,
          existing: existing,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddWarrantySheet> createState() => _AddWarrantySheetState();
}

class _AddWarrantySheetState extends ConsumerState<AddWarrantySheet> {
  late final TextEditingController _title;
  late final TextEditingController _duration;
  late final TextEditingController _note;
  late DateTime _purchaseDate;
  String? _proofPath;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? widget.defaultTitle);
    _duration = TextEditingController(
        text: '${e?.durationMonths ?? WarrantyTiming.defaultDurationMonths}');
    _note = TextEditingController(text: e?.note ?? '');
    _purchaseDate = e?.purchaseDate ?? widget.purchaseDate;
    _proofPath = e?.proofImagePath ?? widget.existingProofImagePath;
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
    await repo.save(
      id: widget.existing?.id,
      receiptId: widget.receiptId,
      lineItemId: widget.lineItemId,
      title: _title.text.trim().isEmpty
          ? widget.defaultTitle
          : _title.text.trim(),
      purchaseDate: _purchaseDate,
      durationMonths: months,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      proofImagePath: _proofPath,
    );
    if (mounted) navigator.pop(true);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true) return;
    final repo = await ref.read(warrantyRepositoryProvider.future);
    await repo.delete(widget.existing!.id);
    if (mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final df = DateFormat.yMMMd('sr');

    return SafeArea(
      // Ograniči visinu i skroluj sadržaj da polje ostane vidljivo kad se
      // pojavi tastatura (#3).
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
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
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                    labelText: l10n.warrantyTitle,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
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
              // Pregled priložene slike (tap → fullscreen sa zoom/share).
              if (_proofPath != null && File(_proofPath!).existsSync()) ...[
                GestureDetector(
                  onTap: () => ImageViewerScreen.open(context,
                      imagePath: _proofPath!, title: _title.text.trim()),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_proofPath!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
              if (_isEdit) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.warrantyDelete),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: _saving ? null : _delete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
