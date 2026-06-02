import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/core/db/providers.dart';
import 'package:troskovnik/core/l10n/gen/app_localizations.dart';
import 'package:troskovnik/features/receipts/data/receipt_providers.dart';
import 'package:troskovnik/features/receipts/data/receipt_repository.dart';
import 'package:troskovnik/features/receipts/presentation/receipt_detail_screen.dart';
import 'package:troskovnik/features/receipts/presentation/receipt_list_screen.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';

/// Fake source koji „dopuni" stavke pri refetch-u (happy path za graničan slučaj).
class _CompletingSource implements ReceiptSource {
  @override
  Future<RawPortalResponse> fetch(String url) async =>
      RawPortalResponse(verificationUrl: url, statusCode: 200, body: '');

  @override
  ParsedReceipt parse(RawPortalResponse raw) => const ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: ReceiptHeader(
            merchantName: 'Pekara', merchantTin: '100', totalAmount: 12000),
        items: [
          ParsedLineItem(
              name: 'Burek',
              quantity: 1,
              unitPrice: 12000,
              total: 12000,
              source: ItemsSource.journal),
        ],
      );
}

Widget _wrap(Widget child, AppDatabase db, {ReceiptSource? source}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) async => db),
      if (source != null) receiptSourceProvider.overrideWithValue(source),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sr'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
  });
  tearDown(() => db.close());

  // Drift stream-query cleanup zakazuje tajmer pri dispose-u; ispraznimo stablo
  // i pustimo tajmere pre kraja testa da izbegnemo "Timer still pending".
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('empty list shows empty state', (tester) async {
    await tester.pumpWidget(_wrap(const ReceiptListScreen(), db));
    await tester.pumpAndSettle();
    expect(find.text('Još nema sačuvanih računa.'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('saved receipt appears in list with merchant + amount',
      (tester) async {
    await repo.saveParsed(
      verificationUrl: 'https://suf.purs.gov.rs/v/?vl=A',
      token: 'A',
      parsed: const ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: ReceiptHeader(
            merchantName: 'Maxi',
            merchantTin: '111',
            invoiceNumber: 'I1',
            pfrNumber: 'P1',
            totalAmount: 53000),
      ),
    );

    await tester.pumpWidget(_wrap(const ReceiptListScreen(), db));
    await tester.pumpAndSettle();
    expect(find.text('Maxi'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets(
      'pendingServer detail shows refresh; refetch completes and shows item',
      (tester) async {
    final saved = await repo.saveParsed(
      verificationUrl: 'https://suf.purs.gov.rs/v/?vl=A',
      token: 'A',
      parsed: const ParsedReceipt(
        fetchStatus: FetchStatus.headerOnly,
        itemsStatus: ItemsStatus.pendingServer,
        itemsSource: ItemsSource.none,
        header: ReceiptHeader(
            merchantName: 'Pekara',
            merchantTin: '100',
            invoiceNumber: 'I9',
            pfrNumber: 'P9',
            totalAmount: 12000),
      ),
    );

    await tester.pumpWidget(_wrap(
      ReceiptDetailScreen(receiptId: saved.receiptId),
      db,
      source: _CompletingSource(),
    ));
    await tester.pumpAndSettle();

    // Granični slučaj: objašnjenje + dugme Osveži.
    expect(find.text('Osveži sada'), findsOneWidget);

    await tester.tap(find.text('Osveži sada'));
    await tester.pumpAndSettle();

    // Posle dopune stavke se vide.
    expect(find.text('Burek'), findsOneWidget);
    await teardownTree(tester);
  });
}
