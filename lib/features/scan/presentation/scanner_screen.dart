import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/db/enums.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../receipts/presentation/receipt_detail_screen.dart';
import '../data/qr_image_decoder.dart';
import '../domain/ips_qr.dart';
import '../domain/verification_url.dart';
import 'manual_entry_screen.dart';
import 'manual_expense_screen.dart';
import 'scan_controller.dart';

/// Skener QR koda (sekcija 7, ekran 1). Posle skeniranja obrađuje rezultat i
/// vodi na detalj ili prikazuje stanje greške/„u obradi".
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, required this.isActive});

  final bool isActive;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  // Samo QR: ML Kit na statičnim slikama (galerija) ume da „prepozna" lažne
  // 1D barkodove u linijama razdvajanja računa (====/----), pa bi se
  // validirao pogrešan sadržaj. Fiskalni i IPS kodovi su uvek QR.
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _processing = false;

  /// „Uslikaj kod" se nudi tek kad živo skeniranje očigledno ne prolazi:
  /// ML Kit javlja samo uspehe, pa je jedini signal proteklo vreme bez
  /// detekcije. Jednom prikazano dugme ostaje do uspešnog skena (bez
  /// treperenja), a sklanja se pri napuštanju taba.
  static const _captureButtonDelay = Duration(seconds: 5);
  Timer? _captureButtonTimer;
  bool _showCaptureButton = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _controller.start();
      _armCaptureButton();
    }
  }

  @override
  void didUpdateWidget(ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.start();
      _armCaptureButton();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _hideCaptureButton();
    }
  }

  @override
  void dispose() {
    _captureButtonTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _armCaptureButton() {
    if (_showCaptureButton) return; // već vidljivo — ostaje do uspeha
    _captureButtonTimer?.cancel();
    _captureButtonTimer = Timer(_captureButtonDelay, () {
      if (mounted && !_processing) {
        setState(() => _showCaptureButton = true);
      }
    });
  }

  void _hideCaptureButton() {
    _captureButtonTimer?.cancel();
    if (_showCaptureButton && mounted) {
      setState(() => _showCaptureButton = false);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    await _processRaw(raw);
  }

  /// Uvoz slike (galerija ili fotografija): skenira ceo kadar — QR može biti
  /// bilo gde na slici. Fotografija punom rezolucijom senzora + zxing-cpp
  /// fallback čita i kodove koje živi skener ne može (gusti, loše štampani).
  Future<void> _importImage(ImageSource source) async {
    if (_processing) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Sistemska kamera ne može da se otvori dok naš skener drži uređaj.
    await _controller.stop();

    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) {
      // korisnik odustao
      if (mounted) {
        await _controller.start();
        _armCaptureButton();
      }
      return;
    }
    if (!mounted) return;

    setState(() => _processing = true);

    // analyzeImage ume da baci (npr. nije podržano na iOS simulatoru, ili
    // neispravna slika) — bez catch-a bi UI ostao zaglavljen u _processing.
    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(
        picked.path,
        formats: const [BarcodeFormat.qrCode],
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.scanImageFailed)));
        setState(() => _processing = false);
        await _controller.start();
        _armCaptureButton();
      }
      return;
    }

    var candidates = capture?.barcodes
            .map((b) => b.rawValue)
            .whereType<String>()
            .where((v) => v.isNotEmpty)
            .toList() ??
        const <String>[];

    // ML Kit često ne detektuje gust fiskalni QR (verzija ~40) na statičnoj
    // slici iako ga kamera čita — probaj ZXing pre nego što odustanemo.
    if (candidates.isEmpty) {
      try {
        final fallback = await QrImageDecoder.decode(picked.path);
        if (fallback != null && fallback.isNotEmpty) candidates = [fallback];
      } catch (e, stack) {
        debugPrint('Greška pri dekodiranju pomoću ZXing fallback-a: $e\n$stack');
      }
    }

    if (candidates.isEmpty) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.scanNoQrInImage)));
        setState(() => _processing = false);
        await _controller.start();
        _armCaptureButton();
      }
      return;
    }

    // Na slici može biti više QR kodova — prednost ima onaj koji je
    // fiskalni URL ili IPS nalog; tek ako nijedan ne prolazi, prvi nađeni.
    final raw = candidates.firstWhere(
      (v) =>
          IpsQrParser.tryParse(v) != null ||
          const VerificationUrlValidator().validate(v)
              is ValidVerificationUrl,
      orElse: () => candidates.first,
    );

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
        _hideCaptureButton(); // skeniranje je uspelo — ponuda više ne treba
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
      _armCaptureButton();
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
        // Izlaz za kodove koje živi skener ne očitava (gusti, loše
        // štampani): fotografija punog senzora + zxing-cpp fallback.
        // Pojavljuje se tek posle par sekundi skeniranja bez pogotka.
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: IgnorePointer(
              ignoring: !_showCaptureButton,
              child: AnimatedOpacity(
                opacity: _showCaptureButton ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.scanCapturePhoto),
                  onPressed: () => _importImage(ImageSource.camera),
                ),
              ),
            ),
          ),
        ),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                        icon: const Icon(Icons.photo_library),
                        label: Text(l10n.scanFromGallery,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        onPressed: () =>
                            _importImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.scanAddExpense,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const ManualExpenseScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.scanManualEntry,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const ManualEntryScreen()),
                        ),
                        child: const Icon(Icons.link),
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
