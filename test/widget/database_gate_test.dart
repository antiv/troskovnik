import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart';
import 'package:troskovnik/core/db/providers.dart';
import 'package:troskovnik/core/l10n/gen/app_localizations.dart';
import 'package:troskovnik/features/home/database_gate.dart';

Widget _wrap(Object error) => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => throw error),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sr'),
        home: const DatabaseGate(child: Text('shell')),
      ),
    );

void main() {
  testWidgets('nečitljiva baza vodi na ekran oporavka', (tester) async {
    await tester.pumpWidget(_wrap(SqliteException(
      26,
      'file is not a database',
      null,
      'SELECT count(*) FROM sqlite_master;',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Podaci se ne mogu otvoriti'), findsOneWidget);
    expect(find.text('Obriši podatke i počni ispočetka'), findsOneWidget);
    expect(find.text('shell'), findsNothing);
  });

  testWidgets('druge greške puštaju aplikaciju dalje', (tester) async {
    await tester.pumpWidget(_wrap(Exception('nema mreže')));
    await tester.pumpAndSettle();

    expect(find.text('shell'), findsOneWidget);
    expect(find.text('Podaci se ne mogu otvoriti'), findsNothing);
  });
}
