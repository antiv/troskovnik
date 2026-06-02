import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/enums.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../receipts/presentation/receipt_detail_screen.dart';
import 'scan_controller.dart';

/// Ručni unos (fallback kad QR ne valja) — sekcija 7, ekran 5.
///
/// Najpouzdaniji put je nalepiti ceo verifikacioni URL (npr. prepisan sa
/// računa); ide kroz isti tok kao skeniranje. (PFR-polja portala su kandidat
/// za kasnije — sekcija 11 #1.)
class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _urlController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return;

    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final outcome = await ref.read(scanControllerProvider).process(raw);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case ScanSaved(:final receiptId, :final wasDuplicate, :final parsed):
        if (wasDuplicate) {
          messenger.showSnackBar(
              SnackBar(content: Text(l10n.resultDuplicateOpened)));
        } else if (parsed.itemsStatus == ItemsStatus.pendingServer) {
          messenger.showSnackBar(
              SnackBar(content: Text(l10n.resultItemsPending)));
        }
        await navigator.pushReplacement(MaterialPageRoute<void>(
          builder: (_) => ReceiptDetailScreen(receiptId: receiptId),
        ));
      case ScanNotFiscal():
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.scanNotFiscal)));
      case ScanError(:final kind):
        messenger.showSnackBar(SnackBar(
          content: Text(switch (kind) {
            ScanErrorKind.noNetwork => l10n.errNoNetwork,
            ScanErrorKind.portalUnavailable => l10n.errPortalUnavailable,
            ScanErrorKind.invalidReceipt => l10n.errInvalidReceipt,
            ScanErrorKind.generic => l10n.errGeneric,
          }),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.manualTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'https://suf.purs.gov.rs/v/?vl=...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.manualSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
