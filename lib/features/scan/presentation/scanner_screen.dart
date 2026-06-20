import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/db/enums.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../receipts/presentation/receipt_detail_screen.dart';
import 'manual_entry_screen.dart';
import 'scan_controller.dart';

/// Skener QR koda (sekcija 7, ekran 1). Posle skeniranja obrađuje rezultat i
/// vodi na detalj ili prikazuje stanje greške/„u obradi".
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _controller = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    await _processRaw(raw);
  }

  /// Uvoz slike iz galerije: skenira ceo kadar (QR može biti bilo gde na slici).
  Future<void> _pickFromGallery() async {
    if (_processing) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return; // korisnik odustao

    setState(() => _processing = true);
    await _controller.stop();

    // analyzeImage ume da baci (npr. nije podržano na iOS simulatoru, ili
    // neispravna slika) — bez catch-a bi UI ostao zaglavljen u _processing.
    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(picked.path);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.scanImageFailed)));
        setState(() => _processing = false);
        await _controller.start();
      }
      return;
    }

    final raw = capture?.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.scanNoQrInImage)));
        setState(() => _processing = false);
        await _controller.start();
      }
      return;
    }

    await _processRaw(raw, alreadyProcessing: true);
  }

  Future<void> _processRaw(String raw, {bool alreadyProcessing = false}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!alreadyProcessing) {
      setState(() => _processing = true);
      await _controller.stop();
    }

    final outcome = await ref.read(scanControllerProvider).process(raw);
    if (!mounted) return;

    switch (outcome) {
      case ScanSaved(:final receiptId, :final wasDuplicate, :final parsed):
        if (wasDuplicate) {
          messenger.showSnackBar(
              SnackBar(content: Text(l10n.resultDuplicateOpened)));
        } else if (parsed.itemsStatus == ItemsStatus.pendingServer) {
          messenger.showSnackBar(
              SnackBar(content: Text(l10n.resultItemsPending)));
        }
        await navigator.push(MaterialPageRoute<void>(
          builder: (_) => ReceiptDetailScreen(receiptId: receiptId),
        ));
      case ScanNotFiscal():
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.scanNotFiscal)));
      case ScanError(:final kind):
        messenger.showSnackBar(
            SnackBar(content: Text(_errorText(l10n, kind))));
    }

    if (mounted) {
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  String _errorText(AppLocalizations l10n, ScanErrorKind kind) =>
      switch (kind) {
        ScanErrorKind.noNetwork => l10n.errNoNetwork,
        ScanErrorKind.portalUnavailable => l10n.errPortalUnavailable,
        ScanErrorKind.invalidReceipt => l10n.errInvalidReceipt,
        ScanErrorKind.generic => l10n.errGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        if (_processing)
          const ColoredBox(
            color: Colors.black45,
            child: Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.scanHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.photo_library),
                      label: Text(l10n.scanFromGallery),
                      onPressed: _pickFromGallery,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.keyboard),
                      label: Text(l10n.scanManualEntry),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const ManualEntryScreen()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
