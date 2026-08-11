import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:troskovnik/core/l10n/gen/app_localizations.dart';
import 'package:troskovnik/features/scan/presentation/scanner_screen.dart';

/// Lažna platforma koja beleži redosled poziva ka kameri.
///
/// Sve što nije preklopljeno ostaje `UnimplementedError` iz interfejsa — test
/// dodiruje samo start/stop putanju.
class _FakeScannerPlatform extends MobileScannerPlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = <String>[];

  /// Sledeći `start()` otkazuje — kao kad sesiju u međuvremenu zauzme neko drugi.
  bool errorOnNextStart = false;

  final _barcodes = StreamController<BarcodeCapture?>.broadcast();
  final _torch = StreamController<TorchState>.broadcast();
  final _zoom = StreamController<double>.broadcast();

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoom.stream;

  @override
  Widget buildCameraView() => const SizedBox.expand();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    calls.add('start');
    if (errorOnNextStart) {
      errorOnNextStart = false;
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      numberOfCameras: 1,
      size: Size(1920, 1080),
      initialDeviceOrientation: DeviceOrientation.portraitUp,
    );
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async {
    unawaited(_barcodes.close());
    unawaited(_torch.close());
    unawaited(_zoom.close());
  }
}

Widget _app({required bool isActive}) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('sr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ScannerScreen(isActive: isActive)),
      ),
    );

void main() {
  late _FakeScannerPlatform platform;

  setUp(() {
    platform = _FakeScannerPlatform();
    MobileScannerPlatform.instance = platform;
  });

  testWidgets('kamera se gasi kad app ode u pozadinu i vraća se na povratak',
      (tester) async {
    await tester.pumpWidget(_app(isActive: true));
    await tester.pumpAndSettle();

    expect(platform.calls, ['start'], reason: 'kamera se pali pri ulasku');

    // Odlazak u pozadinu: `inactive` stiže prvi (npr. povlačenje app switchera),
    // pa tek onda `paused`. Kamera mora da bude puštena odmah — ako ostane
    // otvorena, sistem oduzme sesiju, a Dart strana i dalje misli da radi.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(platform.calls, ['start', 'stop']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(platform.calls.last, 'start',
        reason: 'po povratku kamera mora ponovo da se pokrene');
    expect(tester.takeException(), isNull);
  });

  testWidgets('lifecycle ne pali kameru dok je skener u neaktivnom tabu',
      (tester) async {
    await tester.pumpWidget(_app(isActive: true));
    await tester.pumpAndSettle();
    expect(platform.calls, ['start']);

    // Korisnik pređe na drugi tab, pa tek onda app ode u pozadinu i vrati se.
    await tester.pumpWidget(_app(isActive: false));
    await tester.pumpAndSettle();
    expect(platform.calls, ['start', 'stop']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(platform.calls, ['start', 'stop'],
        reason: 'skener nije na ekranu — kamera ostaje ugašena');
  });

  testWidgets('greška kamere nudi ponovni pokušaj umesto slepe ulice',
      (tester) async {
    await tester.pumpWidget(_app(isActive: true));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('sr'));
    expect(find.text(l10n.retry), findsNothing);

    // Sesija otkaže van našeg toka (drugi app zauzme kameru, sistem je oduzme).
    platform.errorOnNextStart = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text(l10n.retry), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'greška kamere ne sme da izađe kao neuhvaćena async greška');
  });
}
