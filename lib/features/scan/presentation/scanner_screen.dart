import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/db/enums.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/providers/review_prompt_controller.dart';
import '../../receipts/presentation/receipt_detail_screen.dart';
import '../data/qr_image_decoder.dart';
import '../domain/ips_qr.dart';
import '../domain/verification_url.dart';
import 'manual_entry_screen.dart';
import 'manual_expense_screen.dart';
import 'scan_controller.dart';
import 'scan_framing_overlay.dart';

/// Skener QR koda (sekcija 7, ekran 1). Posle skeniranja obrađuje rezultat i
/// vodi na detalj ili prikazuje stanje greške/„u obradi".
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, required this.isActive});

  final bool isActive;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  // Samo QR: ML Kit na statičnim slikama (galerija) ume da „prepozna" lažne
  // 1D barkodove u linijama razdvajanja računa (====/----), pa bi se
  // validirao pogrešan sadržaj. Fiskalni i IPS kodovi su uvek QR.
  //
  // cameraResolution: bez nje Android analizira 640×480. Fiskalni QR je
  // verzija ~40 = 177 modula po stranici, pa i kad ispuni ceo kadar to daje
  // 480/177 ≈ 2,7 px po modulu — na samoj granici čitljivosti, a preko pola
  // kadra 1,4 px, što je nemoguće. Na 1080p pola kadra daje ~3 px/modul.
  // Podešavanje važi samo za Android; iOS ignoriše ovaj parametar i drži
  // AVCaptureSession.Preset.high.
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    cameraResolution: const Size(1920, 1080),
  );
  bool _processing = false;

  /// Pomoć se stepenuje po proteklom vremenu bez pogotka: dekoder javlja samo
  /// uspehe, pa je vreme jedini signal da kadriranje ne valja.
  ///
  /// Prvo se traži da korisnik priđe bliže (najčešći uzrok — QR premali u
  /// kadru), pa tek ako ni to ne pomogne nudi se fotografija punom
  /// rezolucijom. Oba, jednom prikazana, ostaju do uspešnog skena da ne bi
  /// treperila, a sklanjaju se pri napuštanju taba.
  static const _closerHintDelay = Duration(milliseconds: 2500);
  static const _captureButtonDelay = Duration(seconds: 5);
  Timer? _closerHintTimer;
  Timer? _captureButtonTimer;
  bool _showCloserHint = false;
  bool _showCaptureButton = false;
  bool _closeRangeLensTried = false;

  /// Kamera se pali i gasi iz tri nezavisna izvora — lifecycle, promena taba i
  /// obrada rezultata — pa se pozivi mogu preklopiti. `start()` baca
  /// `controllerInitializing` ako naleti na start koji je još u toku, zato sve
  /// ide kroz jedan lanac.
  Future<void> _cameraOps = Future<void>.value();

  /// Dok je otvoren `ImagePicker`, kameru vodi `_importImage`. Otvaranje
  /// pickera samo po sebi gura app u `inactive`, a povratak u `resumed` — bez
  /// ovog flega bi lifecycle upalio kameru ispod tuđeg ekrana.
  bool _pickerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _startCamera();
      _armHints();
    }
  }

  @override
  void didUpdateWidget(ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startCamera();
      _armHints();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopCamera();
      _hideHints();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closerHintTimer?.cancel();
    _captureButtonTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// `MobileScanner` sam prati lifecycle samo kad mu se ne prosledi kontroler
  /// (`useAppLifecycleState` — „only applicable if no controller is passed").
  /// Naš kontroler nosi `cameraResolution` i `formats`, koji se internom ne
  /// mogu zadati, pa ostajemo pri svom — i sami gasimo kameru u pozadini.
  ///
  /// Bez ovoga sesija ostaje otvorena dok je app u pozadini: sistem je oduzme
  /// (Android blokira kameru aplikaciji u pozadini, iOS prekine
  /// `AVCaptureSession`), a Dart strana i dalje misli da radi — preview po
  /// povratku ostane zamrznut, a prvi sledeći poziv ka platformi puca.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_pickerOpen) return;
    // Dok kontroler nije spreman nema šta ni da se pali ni da se gasi —
    // sistemski dijalog za dozvolu i sam pravi lifecycle promenu, pre nego što
    // je kamera uopšte inicijalizovana.
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Tajmeri se otkazuju da ne bi stajali celo vreme u pozadini i opalili
        // svi odjednom u trenutku povratka, nad sesijom koje više nema.
        _hideHints();
        _stopCamera();
      case AppLifecycleState.resumed:
        // `_processing` znači da je u toku obrada rezultata — ona sama vraća
        // kameru kad završi.
        if (widget.isActive && !_processing) {
          _startCamera();
          _armHints();
        }
    }
  }

  /// Pokretanje ide preko `stop()`: posle pozadine kontroler ume da veruje da
  /// kamera i dalje radi (`isRunning` ostane `true`, jer nam niko nije javio da
  /// je sesija oduzeta), a tada `start()` odmah izađe i preview ostane crn.
  /// `stop()` je bez efekta ako kamera već stoji.
  Future<void> _startCamera() => _runCameraOp(() async {
        await _controller.stop();
        await _controller.start();
      });

  Future<void> _stopCamera() => _runCameraOp(_controller.stop);

  /// Greške se namerno gutaju: kad sistem oduzme sesiju, i gašenje i paljenje
  /// mogu da bace, a to je stanje od kog se oporavljamo — ne razlog da app
  /// padne na neuhvaćenoj async grešci (nema globalnog `onError`).
  Future<void> _runCameraOp(Future<void> Function() op) {
    final chained = _cameraOps.then((_) async {
      if (!mounted) return;
      try {
        await op();
      } catch (e, stack) {
        debugPrint('Greška pri radu sa kamerom: $e\n$stack');
      }
    });
    _cameraOps = chained;
    return chained;
  }

  void _armHints() {
    if (!_showCloserHint) {
      _closerHintTimer?.cancel();
      _closerHintTimer = Timer(_closerHintDelay, () {
        if (mounted && !_processing) {
          setState(() => _showCloserHint = true);
          // Kroz isti lanac kao start/stop — zamena objektiva ne sme da se
          // preklopi sa pokretanjem kamere.
          _runCameraOp(_tryCloseRangeLens);
        }
      });
    }
    if (_showCaptureButton) return; // već vidljivo — ostaje do uspeha
    _captureButtonTimer?.cancel();
    _captureButtonTimer = Timer(_captureButtonDelay, () {
      if (mounted && !_processing) {
        setState(() => _showCaptureButton = true);
      }
    });
  }

  /// iOS nema `cameraResolution` — plugin drži `AVCaptureSession.Preset.high`
  /// i dekodira Apple Vision-om, koji je na gustim kodovima slabiji od ML
  /// Kit-a. Jedina poluga koja ostaje je objektiv koji fokusira bliže (na
  /// novijim iPhone-ima ultra-wide), jer minimalna daljina fokusa je upravo
  /// zid na koji se naleće kad se prilazi da QR ispuni okvir.
  ///
  /// Namerno se uključuje tek kad kadriranje očigledno ne prolazi: širi ugao
  /// smanjuje udeo QR-a u kadru, pa bi stalno uključen mogao da pokvari
  /// slučajeve koji sad rade. Pokušava se jednom po životu ekrana.
  Future<void> _tryCloseRangeLens() async {
    if (_closeRangeLensTried || !Platform.isIOS) return;
    if (!_controller.value.isRunning) return;
    _closeRangeLensTried = true;
    try {
      final best = await _controller.getBestCloseRangeScanningLens();
      if (best == null || !mounted) return;
      final supported = await _controller.getSupportedLenses();
      if (!supported.contains(best) || !mounted) return;
      await _controller.switchCamera(SelectCamera(lensType: best));
    } catch (_) {
      // Objektiv je pomoć, a ne uslov — nikad ne sme da obori skeniranje.
    }
  }

  void _hideHints() {
    _closerHintTimer?.cancel();
    _captureButtonTimer?.cancel();
    if ((_showCloserHint || _showCaptureButton) && mounted) {
      setState(() {
        _showCloserHint = false;
        _showCaptureButton = false;
      });
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
    await _stopCamera();

    // Predaja kamere lifecycle-u ide preko `_processing`, koji se postavi pre
    // nego što se `_pickerOpen` skine — da između njih ne ostane procep u kom
    // bi observer upalio kameru.
    XFile? picked;
    var pickerFailed = false;
    _pickerOpen = true;
    try {
      picked = await ImagePicker().pickImage(source: source);
      if (picked != null && mounted) {
        setState(() => _processing = true);
      }
    } catch (e, stack) {
      pickerFailed = true;
      debugPrint('Greška pri otvaranju slike: $e\n$stack');
    } finally {
      _pickerOpen = false;
    }

    if (!mounted) return;

    if (picked == null) {
      // korisnik odustao — ili se picker uopšte nije otvorio
      if (pickerFailed) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.scanImageFailed)));
      }
      await _startCamera();
      _armHints();
      return;
    }

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
        await _startCamera();
        _armHints();
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
        await _startCamera();
        _armHints();
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
      await _stopCamera();
    }

    final outcome = await ref.read(scanControllerProvider).process(raw);
    if (!mounted) return;

    switch (outcome) {
      case ScanSaved(:final receiptId, :final wasDuplicate, :final parsed):
        _hideHints(); // skeniranje je uspelo — ponuda više ne treba
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
        // Ocena se traži tek pošto korisnik pogleda račun i vrati se — dakle
        // kad je posao završen, a ne usred toka. Duplikati i računi sačuvani
        // bez mreže (fetchStatus.pending) se ne broje: to nisu uspesi.
        if (mounted &&
            !wasDuplicate &&
            parsed.fetchStatus != FetchStatus.pending) {
          await _recordScanForReview();
        }
      case ScanNotFiscal():
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.scanNotFiscal)));
      case ScanError(:final kind):
        messenger.showSnackBar(
            SnackBar(content: Text(_errorText(l10n, kind))));
    }

    if (mounted) {
      setState(() => _processing = false);
      // Ako je app u međuvremenu otišao u pozadinu (npr. korisnik je zatvorio
      // app dok se račun preuzimao), kameru ne diramo — lifecycle će je vratiti.
      if (widget.isActive &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await _startCamera();
        _armHints();
      }
    }
  }

  /// Zabeleži uspešno skeniranje za brojač ocene.
  ///
  /// Prvo se čeka `.future` da bi brojač bio učitan iz skladišta — `.notifier`
  /// sam po sebi tek pokreće `build()`, pa bi bez ovoga prvo skeniranje uvek
  /// ispalo neizbrojano. Greška ovde ne sme da utiče na tok skeniranja.
  Future<void> _recordScanForReview() async {
    try {
      await ref.read(reviewPromptControllerProvider.future);
      await ref
          .read(reviewPromptControllerProvider.notifier)
          .recordSuccessfulScan();
    } catch (_) {
      // Ocena je sporedna — nikad ne sme da obori skeniranje.
    }
  }

  /// Kamera može da otkaže i van našeg toka: sistem oduzme sesiju dok smo u
  /// pozadini, drugi app je zauzme, dozvola bude povučena. Podrazumevani prikaz
  /// pluginu je crn pravougaonik sa ikonom greške iz kog nema izlaza — ovde
  /// korisnik bar može da pokuša ponovo bez restarta aplikacije.
  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    final l10n = AppLocalizations.of(context);
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(
                permissionDenied ? l10n.scanPermissionDenied : l10n.errGeneric,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              if (!permissionDenied) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _startCamera(),
                  child: Text(l10n.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: _buildCameraError,
        ),
        // Okvir pretvara inače nevidljiv zahtev („QR mora da zauzme oko pola
        // kadra") u metu koju korisnik vidi. Samo iscrtavanje — ne filtrira
        // očitavanja, pa QR izvan okvira i dalje prolazi.
        const Positioned.fill(child: ScanFramingOverlay()),
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
                Text(_showCloserHint ? l10n.scanHintCloser : l10n.scanHint,
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
