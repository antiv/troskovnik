import 'package:flutter/foundation.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// Fallback dekoder QR koda sa statične slike (uvoz iz galerije).
///
/// ML Kit (`MobileScannerController.analyzeImage`) je nepouzdan za guste QR
/// kodove na statičnim slikama — fiskalni TaxCore QR nosi veliki token
/// (QR verzija ~40) i ML Kit ga na screenshotu često uopšte ne detektuje,
/// iako ga kamera čita. Nativni zxing-cpp čita i module ispod 3 px, uz
/// rotaciju/inverziju, za bilo koje dimenzije slike.
class QrImageDecoder {
  QrImageDecoder._();

  /// Vraća sadržaj prvog QR koda na slici ili `null` ako ga nema.
  ///
  /// Dart deo (dekodiranje PNG/JPEG u piksele) je CPU-intenzivan za velike
  /// fotografije, pa sve radi u posebnom isolate-u.
  static Future<String?> decode(String path) => compute(_decode, path);

  static Future<String?> _decode(String path) async {
    final code = await zx.readBarcodeImagePathString(
      path,
      DecodeParams(
        // readBarcodeImagePath nativnom kodu prosleđuje RGB bajtove (3 B/px),
        // a podrazumevani imageFormat je lum (1 B/px) — bez ovoga zxing-cpp
        // čita pogrešno interpretiran bafer i nikad ništa ne nađe.
        imageFormat: ImageFormat.rgb,
        format: Format.qrCode,
        tryHarder: true,
        tryRotate: true,
        tryInverted: true,
        tryDownscale: true,
        // Podrazumevano 768 smanjuje sliku pre skeniranja — to gust QR na
        // screenshotu (modul ~2.4 px) svede ispod praga čitljivosti.
        // Zato skeniramo u punoj rezoluciji.
        maxSize: 1 << 20,
        maxNumberOfSymbols: 1,
      ),
    );
    final text = code.text;
    return code.isValid && text != null && text.isNotEmpty ? text : null;
  }
}
