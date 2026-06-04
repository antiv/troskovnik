import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/l10n/gen/app_localizations.dart';
import 'package:troskovnik/core/widgets/image_viewer_screen.dart';

// 1x1 PNG (transparentni piksel) — validan fajl za Image.file.
const _png1x1 = <int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, //
  120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, //
  78, 68, 174, 66, 96, 130,
];

Widget _wrap(String path) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sr'),
      home: ImageViewerScreen(imagePath: path, title: 'Račun dokaz'),
    );

void main() {
  late File img;

  setUp(() async {
    img = File(
        '${Directory.systemTemp.path}/iv_test_${DateTime.now().microsecondsSinceEpoch}.png');
    await img.writeAsBytes(_png1x1);
  });
  tearDown(() async {
    if (img.existsSync()) await img.delete();
  });

  testWidgets('viewer shows image with zoom + share, title in app bar',
      (tester) async {
    await tester.pumpWidget(_wrap(img.path));
    await tester.pumpAndSettle();

    expect(find.text('Račun dokaz'), findsOneWidget);
    // Zoom/pan kontejner i slika prisutni.
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    // Share dugme (ikona) prisutno.
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('missing file shows fallback text, no crash', (tester) async {
    await tester.pumpWidget(_wrap('/nepostojeci/put/slika.png'));
    await tester.pumpAndSettle();
    expect(find.text('Slika nije pronađena.'), findsOneWidget);
  });
}
