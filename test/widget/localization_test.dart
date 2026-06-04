import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/l10n/gen/app_localizations.dart';
import 'package:troskovnik/core/l10n/locale_controller.dart';

/// Mali widget koji prikazuje par lokalizovanih stringova u datom lokalu.
Widget _app(Locale? locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context);
          return Scaffold(
            body: Column(
              children: [Text(l.navReceipts), Text(l.warrantyStatusActive)],
            ),
          );
        },
      ),
    );

void main() {
  testWidgets('Serbian Latin shows latinica', (tester) async {
    await tester.pumpWidget(_app(const Locale('sr')));
    await tester.pumpAndSettle();
    expect(find.text('Računi'), findsOneWidget);
    expect(find.text('Važi'), findsOneWidget);
  });

  testWidgets('Serbian Cyrillic shows ћирилица', (tester) async {
    await tester.pumpWidget(_app(
        const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl')));
    await tester.pumpAndSettle();
    expect(find.text('Рачуни'), findsOneWidget);
    expect(find.text('Важи'), findsOneWidget);
  });

  testWidgets('English shows English', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Receipts'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
  });

  group('AppLanguage.locale mapping', () {
    test('maps to correct locales', () {
      expect(AppLanguage.system.locale, isNull);
      expect(AppLanguage.serbianLatin.locale, const Locale('sr'));
      expect(AppLanguage.english.locale, const Locale('en'));
      final cyr = AppLanguage.serbianCyrillic.locale!;
      expect(cyr.languageCode, 'sr');
      expect(cyr.scriptCode, 'Cyrl');
    });

    test('fromStorage round-trips and defaults to system', () {
      expect(AppLanguage.fromStorage('serbianCyrillic'),
          AppLanguage.serbianCyrillic);
      expect(AppLanguage.fromStorage(null), AppLanguage.system);
      expect(AppLanguage.fromStorage('garbage'), AppLanguage.system);
    });
  });
}
