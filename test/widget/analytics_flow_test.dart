import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/core/db/providers.dart';
import 'package:troskovnik/core/l10n/gen/app_localizations.dart';
import 'package:troskovnik/core/domain/currency.dart';
import 'package:troskovnik/core/providers/last_currency_controller.dart';
import 'package:troskovnik/features/analytics/data/analytics_providers.dart';
import 'package:troskovnik/features/analytics/presentation/analytics_screen.dart';

class FakeAnalyticsCurrencyNotifier extends AnalyticsCurrencyNotifier {
  @override
  Future<Currency?> build() async => Currency.rsd;

  @override
  Future<void> set(Currency? c) async {
    state = AsyncData(c);
  }
}

class FakeLastCurrencyController extends LastCurrencyController {
  @override
  Future<Currency> build() async => Currency.rsd;

  @override
  Future<void> setCurrency(Currency currency) async {
    state = AsyncData(currency);
  }
}

Widget _wrap(AppDatabase db) => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => db),
        analyticsCurrencyProvider.overrideWith(() => FakeAnalyticsCurrencyNotifier()),
        lastCurrencyControllerProvider.overrideWith(() => FakeLastCurrencyController()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('sr'),
        home: Scaffold(body: AnalyticsScreen()),
      ),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settleTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('empty analytics shows empty state', (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nema dovoljno podataka'), findsOneWidget);
    await settleTeardown(tester);
  });

  testWidgets('with receipts shows total spent', (tester) async {
    final m = await db.into(db.merchants).insert(
          MerchantsCompanion.insert(tin: '1', name: 'Maxi'),
        );
    await db.into(db.receipts).insert(
          ReceiptsCompanion.insert(
            merchantId: m,
            verificationUrl: 'u',
            invoiceNumber: const Value('I'),
            pfrNumber: const Value('P'),
            pfrTime: Value(DateTime.now()),
            totalAmount: const Value(53000),
            fetchStatus: const Value(FetchStatus.complete),
          ),
        );

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // Kartica ukupne potrošnje je na vrhu (vidljiva bez skrolovanja).
    expect(find.text('Ukupno potrošeno'), findsOneWidget);
    expect(find.textContaining('530'), findsWidgets); // 530,00 RSD
    // Sekcija prodavaca je niže u listi — skroluj do nje.
    await tester.scrollUntilVisible(
      find.text('Najveći prodavci'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Najveći prodavci'), findsOneWidget);
    await settleTeardown(tester);
  });
}
