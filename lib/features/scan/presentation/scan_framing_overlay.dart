import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Okvir koji korisniku pokazuje koliko QR kod treba da bude velik u kadru.
///
/// Razlog postojanja je merljiv, ne estetski: gust fiskalni QR (verzija ~40)
/// ima 177 modula po stranici, a dekoderu treba oko 3 px po modulu. Na analizi
/// od 1920×1080 to znači da QR mora da zauzme grubo 60% kraće stranice kadra —
/// zahtev koji je korisniku inače potpuno nevidljiv. Okvir ga pretvara u metu.
///
/// Namerno **nije** `scanWindow` iz `mobile_scanner`: taj filtrira rezultate i
/// odbacuje kod koji delom izađe iz okvira iako ga je pročitao. Ovde je sve
/// samo iscrtavanje, pa pogrešno kadriranje nikad ne može da obori uspešno
/// očitavanje.
class ScanFramingOverlay extends StatelessWidget {
  const ScanFramingOverlay({super.key, this.sideFactor = 0.6});

  /// Stranica okvira kao udeo kraće stranice kadra.
  final double sideFactor;

  @override
  Widget build(BuildContext context) {
    // Okvir ne sme da otima dodire dugmadima ispod sebe.
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FramingPainter(sideFactor: sideFactor),
      ),
    );
  }
}

class _FramingPainter extends CustomPainter {
  const _FramingPainter({required this.sideFactor});

  final double sideFactor;

  static const _radius = 16.0;
  static const _dim = Color(0x8A000000);

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * sideFactor;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
    final rrect = RRect.fromRectXY(rect, _radius, _radius);

    // Zatamnjenje svuda osim unutar okvira.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rrect),
      ),
      Paint()..color = _dim,
    );

    // Uglovi umesto punog pravougaonika — manje zaklanjaju sliku.
    final stroke = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final arm = side * 0.12;

    for (final path in _corners(rect, arm)) {
      canvas.drawPath(path, stroke);
    }
  }

  /// Četiri „L" oblika sa zaobljenim prelazom, po jedan u svakom uglu.
  List<Path> _corners(Rect r, double arm) {
    const rad = Radius.circular(_radius);
    return [
      Path()
        ..moveTo(r.left, r.top + _radius + arm)
        ..lineTo(r.left, r.top + _radius)
        ..arcToPoint(Offset(r.left + _radius, r.top), radius: rad)
        ..lineTo(r.left + _radius + arm, r.top),
      Path()
        ..moveTo(r.right - _radius - arm, r.top)
        ..lineTo(r.right - _radius, r.top)
        ..arcToPoint(Offset(r.right, r.top + _radius), radius: rad)
        ..lineTo(r.right, r.top + _radius + arm),
      Path()
        ..moveTo(r.right, r.bottom - _radius - arm)
        ..lineTo(r.right, r.bottom - _radius)
        ..arcToPoint(Offset(r.right - _radius, r.bottom), radius: rad)
        ..lineTo(r.right - _radius - arm, r.bottom),
      Path()
        ..moveTo(r.left + _radius + arm, r.bottom)
        ..lineTo(r.left + _radius, r.bottom)
        ..arcToPoint(Offset(r.left, r.bottom - _radius), radius: rad)
        ..lineTo(r.left, r.bottom - _radius - arm),
    ];
  }

  @override
  bool shouldRepaint(covariant _FramingPainter oldDelegate) =>
      oldDelegate.sideFactor != sideFactor;
}
