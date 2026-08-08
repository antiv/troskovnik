import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/features/scan/presentation/scan_framing_overlay.dart';

Widget _wrap(Widget child, {Size size = const Size(400, 800)}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );

void main() {
  testWidgets('paints without error on portrait and landscape', (tester) async {
    for (final size in const [Size(400, 800), Size(800, 400), Size(500, 500)]) {
      await tester.pumpWidget(_wrap(const ScanFramingOverlay(), size: size));
      expect(tester.takeException(), isNull);
      expect(find.byType(ScanFramingOverlay), findsOneWidget);
    }
  });

  testWidgets('does not swallow taps meant for widgets underneath',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                ),
              ),
              const Positioned.fill(child: ScanFramingOverlay()),
            ],
          ),
        ),
      ),
    );

    // Sredina okvira i ugao ekrana — oba moraju da prođu kroz overlay.
    await tester.tapAt(tester.getCenter(find.byType(ScanFramingOverlay)));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(taps, 2);
  });

  testWidgets('repaints when the side factor changes', (tester) async {
    await tester.pumpWidget(_wrap(const ScanFramingOverlay(sideFactor: 0.6)));
    await tester.pumpWidget(_wrap(const ScanFramingOverlay(sideFactor: 0.8)));
    expect(tester.takeException(), isNull);
  });
}
