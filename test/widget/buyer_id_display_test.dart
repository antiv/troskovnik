import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/core/db/providers.dart';
import 'package:troskovnik/core/domain/country.dart';
import 'package:troskovnik/core/domain/currency.dart';
import 'package:troskovnik/core/l10n/gen/app_localizations.dart';
import 'package:troskovnik/core/providers/last_currency_controller.dart';
import 'package:troskovnik/features/analytics/data/analytics_providers.dart';
import 'package:troskovnik/features/analytics/domain/analytics_models.dart';
import 'package:troskovnik/features/analytics/presentation/analytics_screen.dart';
import 'package:troskovnik/features/analytics/presentation/widgets/company_spending_list.dart';
import 'package:troskovnik/features/companies/data/company_repository.dart';
import 'package:troskovnik/features/receipts/data/receipt_repository.dart';
import 'package:troskovnik/features/receipts/presentation/receipt_detail_screen.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';

class FakeCur extends AnalyticsCurrencyNotifier {
  FakeCur(this.c);
  final Currency? c;
  @override
  Future<Currency?> build() async => c;
  @override
  Future<void> set(Currency? v) async => state = AsyncData(v);
}

class FakeLast extends LastCurrencyController {
  @override
  Future<Currency> build() async => Currency.rsd;
  @override
  Future<void> setCurrency(Currency currency) async =>
      state = AsyncData(currency);
}

Widget wrap(AppDatabase db, Widget child,
        {Locale locale = const Locale('sr'), Currency? cur = Currency.rsd}) =>
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => db),
        analyticsCurrencyProvider.overrideWith(() => FakeCur(cur)),
        lastCurrencyControllerProvider.overrideWith(() => FakeLast()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: child),
      ),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ReceiptRepository repo;
  var n = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
  });
  tearDown(() => db.close());

  Future<int> save(String? buyer,
      {int total = 1200000, Country country = Country.serbia, String? name}) async {
    n++;
    final r = await repo.saveParsed(
      verificationUrl: 'u$n',
      token: 't$n',
      country: country,
      parsed: ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: ReceiptHeader(
          merchantName: 'Prodavac',
          merchantTin: '100',
          buyerId: buyer,
          buyerName: name,
          invoiceNumber: 'I$n',
          pfrNumber: 'P$n',
          pfrTime: DateTime.now().subtract(const Duration(days: 3)),
          totalAmount: total,
        ),
        items: [
          ParsedLineItem(
              name: 'Usluga',
              quantity: 1,
              unitPrice: total,
              total: total,
              taxRate: 20,
              source: ItemsSource.journal),
        ],
      ),
    );
    return r.receiptId;
  }

  Future<void> settle(WidgetTester t) => t.pumpAndSettle();

  Future<void> cleanup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  testWidgets('W1 sekcija se prikazuje, preimenovanje kroz dijalog osvežava red',
      (t) async {
    t.view.physicalSize = const Size(2600, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await save('10:104318304');
    await t.pumpWidget(wrap(db, const AnalyticsScreen()));
    await settle(t);
    expect(find.text('Po firmama (PIB)'), findsOneWidget);
    expect(find.text('PIB 104318304'), findsOneWidget);
    await t.tap(find.text('PIB 104318304'));
    await settle(t);
    expect(find.text('Naziv firme'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'Moja firma d.o.o.');
    await t.tap(find.byType(FilledButton).last);
    await settle(t);
    expect(find.text('Moja firma d.o.o.'), findsOneWidget);
    expect(find.textContaining('PIB 104318304'), findsOneWidget);
    await cleanup(t);
  });

  testWidgets('W2 bez PIB firme nema sekcije', (t) async {
    t.view.physicalSize = const Size(2600, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await save('11:0101990800000');
    await t.pumpWidget(wrap(db, const AnalyticsScreen()));
    await settle(t);
    expect(find.text('Po firmama (PIB)'), findsNothing);
    await cleanup(t);
  });

  testWidgets('W3 dugačak naziv na uskom ekranu ne pravi overflow', (t) async {
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrap(
        db,
        CompanySpendingList(currency: Currency.rsd, items: [
          CompanySpending(
              country: Country.serbia,
              taxId: '104318304',
              name: 'Veoma dugacak naziv firme ' * 5,
              totalMinor: 123456789012,
              receiptCount: 123456,
              vatMinor: 20576131502),
        ])));
    await settle(t);
    expect(t.takeException(), isNull);
    await cleanup(t);
  });

  testWidgets('W4 bez izabrane valute BAM firma se ne prikazuje kao RSD',
      (t) async {
    t.view.physicalSize = const Size(2600, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await save('10:104318304', total: 1000000);
    await save('10:4400000000001',
        total: 50000, country: Country.republikaSrpska);
    await t.pumpWidget(wrap(db, const AnalyticsScreen(), cur: null));
    await settle(t);
    expect(find.textContaining('JIB 4400000000001'), findsNothing);
    await cleanup(t);
  });

  Future<void> detail(WidgetTester t, int id, Object m,
      {Locale locale = const Locale('sr')}) async {
    await t.pumpWidget(wrap(db, ReceiptDetailScreen(receiptId: id), locale: locale));
    await settle(t);
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((s) =>
            s.startsWith('ID kupca') ||
            s.startsWith('ИД купца') ||
            s.startsWith('Buyer'))
        .toList();
    expect(texts.single, m);
    await cleanup(t);
  }

  testWidgets('W5 detalj: PIB + naziv', (t) async {
    final id = await save('10:104318304');
    await CompanyRepository(db).setName(Country.serbia, '104318304', 'Moja firma');
    await detail(t, id, 'ID kupca: PIB 104318304 · Moja firma');
  });

  testWidgets('W6 detalj: JMBG maskiran', (t) async {
    final id = await save('11:0101990800000');
    await detail(t, id, 'ID kupca: JMBG •••••••••0000');
  });

  testWidgets('W7 detalj: CG TIN sa nazivom sa računa', (t) async {
    final id =
        await save('TIN:02345678', country: Country.montenegro, name: 'Firma CG');
    await detail(t, id, 'ID kupca: PIB 02345678 · Firma CG');
  });

  testWidgets('W8 detalj: nepoznat format je maskiran, bez praznog prefiksa',
      (t) async {
    final id = await save('104318304');
    await detail(t, id, 'ID kupca: •••••8304');
  });

  testWidgets('W9 detalj: lični dokument ne prikazuje sirov kod', (t) async {
    final id = await save('20:123456789');
    await detail(t, id, 'ID kupca: Lični dokument •••••6789');
  });

  testWidgets('W10 ćirilica: oznake su prevedene', (t) async {
    final id = await save('10:104318304');
    await detail(t, id, 'ИД купца: ПИБ 104318304',
        locale: const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl'));
  });

  testWidgets('W11 lista firmi: strani TIN i ćirilični PIB', (t) async {
    t.view.physicalSize = const Size(1200, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrap(
        db,
        const CompanySpendingList(currency: Currency.rsd, items: [
          CompanySpending(
              country: Country.serbia,
              taxId: '104318304',
              totalMinor: 1000,
              receiptCount: 1,
              vatMinor: 0),
          CompanySpending(
              country: Country.serbia,
              taxId: 'DE123456789',
              totalMinor: 500,
              receiptCount: 1,
              vatMinor: 0),
        ]),
        locale: const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl')));
    await settle(t);
    expect(find.text('ПИБ 104318304'), findsOneWidget);
    expect(find.text('ТИН DE123456789'), findsOneWidget);
    await cleanup(t);
  });

  Future<String> merchantLine(WidgetTester t, int id, Locale locale) async {
    await t.pumpWidget(wrap(db, ReceiptDetailScreen(receiptId: id), locale: locale));
    await settle(t);
    final line = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .singleWhere((s) => s.endsWith(': 100'));
    await cleanup(t);
    return line;
  }

  testWidgets('W12 PIB prodavca: preveden, JIB za RS', (t) async {
    final sr = await save(null);
    final rs = await save(null, country: Country.republikaSrpska);
    expect(await merchantLine(t, sr, const Locale('sr')), 'PIB: 100');
    expect(
        await merchantLine(t, sr,
            const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl')),
        'ПИБ: 100');
    expect(await merchantLine(t, rs, const Locale('sr')), 'JIB: 100');
  });
}
