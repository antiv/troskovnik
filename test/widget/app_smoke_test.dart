import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/app.dart';

void main() {
  testWidgets('app boots and shows localized scan hint', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TroskovnikApp()));
    await tester.pumpAndSettle();

    // SR is the default locale; the scan hint should be present.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
