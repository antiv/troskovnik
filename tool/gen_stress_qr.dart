// Jednokratni alat: generiše stres-slike gustog QR-a (TaxCore-oblik URL,
// verzija ~40) za proveru dekodera. Pokretanje:
//   fvm dart run tool/gen_stress_qr.dart <izlazni_dir>
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main(List<String> args) {
  final outDir = Directory(args.first)..createSync(recursive: true);
  final content = 'https://suf.purs.gov.rs/v/?vl='
      '${List.generate(2400, (i) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'[i % 64]).join()}';

  final matrix = Encoder.encode(content, ErrorCorrectionLevel.l).matrix!;
  const margin = 4;
  const scale = 4;
  final size = (matrix.width + margin * 2) * scale;
  final base = img.Image(width: size, height: size);
  img.fill(base, color: img.ColorRgb8(255, 255, 255));
  for (var x = 0; x < matrix.width; x++) {
    for (var y = 0; y < matrix.height; y++) {
      if (matrix.get(x, y) == 1) {
        img.fillRect(base,
            x1: (x + margin) * scale,
            y1: (y + margin) * scale,
            x2: (x + margin) * scale + scale - 1,
            y2: (y + margin) * scale + scale - 1,
            color: img.ColorRgb8(0, 0, 0));
      }
    }
  }

  // Varijante: čist render, downscale na ~2.4 px/modulu (kubni i linearni,
  // neceo faktor kao u browseru), i "u kontekstu" — QR na dužem screenshotu
  // sa tekstom iznad/ispod (kao pravi screenshot računa).
  void save(String name, img.Image i) => File('${outDir.path}/$name.png')
      .writeAsBytesSync(img.encodePng(i));

  save('clean', base);
  save('small_cubic',
      img.copyResize(base, width: 450, interpolation: img.Interpolation.cubic));
  save('small_linear',
      img.copyResize(base, width: 443, interpolation: img.Interpolation.linear));

  final ctx = img.Image(width: 720, height: 1600);
  img.fill(ctx, color: img.ColorRgb8(255, 255, 255));
  final qrSmall =
      img.copyResize(base, width: 455, interpolation: img.Interpolation.linear);
  img.compositeImage(ctx, qrSmall, dstX: 132, dstY: 570);
  // Linije razdvajanja kao na fiskalnom isečku (potencijalni lažni 1D barkod).
  for (final y in [200, 240, 1250, 1290]) {
    img.fillRect(ctx,
        x1: 40, y1: y, x2: 680, y2: y + 6, color: img.ColorRgb8(0, 0, 0));
  }
  save('screenshot_ctx', ctx);

  stdout.writeln('OK: ${outDir.path}');
}
