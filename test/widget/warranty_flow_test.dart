import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/core/db/providers.dart';
import 'package:troskovnik/core/l10n/gen/app_localizations.dart';
import 'package:troskovnik/features/receipts/data/receipt_repository.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';
import 'package:troskovnik/features/warranties/data/warranty_notifier.dart';
import 'package:troskovnik/features/warranties/data/warranty_providers.dart';
import 'package:troskovnik/features/warranties/data/warranty_repository.dart';
import 'package:troskovnik/features/warranties/presentation/warranty_list_screen.dart';

class _FakeNotifier implements WarrantyNotifier {
  @override
  Future<void> scheduleReminders({
    required int warrantyId,
    required String title,
    required DateTime expiryDate,
    DateTime? now,
  }) async {}

  @override
  Future<void> cancelReminders(int warrantyId) async {}
}

Widget _wrap(Widget child, AppDatabase db) => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => db),
        warrantyNotifierProvider.overrideWith((ref) async => _FakeNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sr'),
        home: Scaffold(body: child),
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

  testWidgets('empty warranties shows empty state', (tester) async {
    await tester.pumpWidget(_wrap(const WarrantyListScreen(), db));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Još nema praćenih garancija'), findsOneWidget);
    await settleTeardown(tester);
  });

  testWidgets('created warranty appears with title and merchant',
      (tester) async {
    // Seed račun + garancija.
    final rr = ReceiptRepository(db);
    final saved = await rr.saveParsed(
      verificationUrl: 'https://suf.purs.gov.rs/v/?vl=A',
      token: 'A',
      parsed: const ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: ReceiptHeader(
            merchantName: 'TehnoMaxi',
            merchantTin: '1',
            invoiceNumber: 'I',
            pfrNumber: 'P',
            totalAmount: 100),
      ),
    );
    final repo = WarrantyRepository(db, _FakeNotifier());
    await repo.create(
      receiptId: saved.receiptId,
      title: 'Televizor',
      purchaseDate: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(_wrap(const WarrantyListScreen(), db));
    await tester.pumpAndSettle();

    expect(find.text('Televizor'), findsOneWidget);
    expect(find.textContaining('TehnoMaxi'), findsOneWidget);
    await settleTeardown(tester);
  });
}
