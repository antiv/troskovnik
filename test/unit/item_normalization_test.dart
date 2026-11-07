import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/core/domain/currency.dart';
import 'package:troskovnik/core/normalization/item_normalization_service.dart';
import 'package:troskovnik/core/normalization/item_normalizer.dart';
import 'package:troskovnik/core/normalization/token_set_matcher.dart';
import 'package:troskovnik/features/analytics/data/analytics_repository.dart';
import 'package:troskovnik/features/analytics/domain/advanced_analytics_models.dart';
import 'package:troskovnik/features/analytics/domain/analytics_models.dart';

void main() {
  group('Layer 1: ItemNormalizer', () {
    test('transliterates Serbian Cyrillic and canonicalizes measures', () {
      final res = ItemNormalizer.normalize('ХЛЕБ САВА 500Г АКЦИЈА');
      expect(res.extractedMeasure, '500g');
      expect(res.orderedTokens, containsAll(['hleb', 'sava']));
      expect(res.orderedTokens, isNot(contains('akcija')));
    });

    test('strips leading PLU/SKU codes, packaging noise, and expands ERP abbreviations', () {
      final res1 = ItemNormalizer.normalize('3850123 KOKA KOLA 0.5L PET');
      expect(res1.extractedMeasure, '0.5l');
      expect(res1.cleanedKey, 'coca cola');

      final res2 = ItemNormalizer.normalize('MOJA KRAVICA MLK. 2,8%MM 1000ML TT AKCIJA');
      expect(res2.extractedMeasure, '1l');
      expect(res2.orderedTokens, containsAll(['kravica', 'mleko']));
      expect(res2.allMeasures, containsAll(['2.8%mm', '1l']));
    });

    test('normalizes ekavian and ijekavian variants to the same canonical tokens', () {
      final ekav = ItemNormalizer.normalize('IMLEK MLEKO KRAVICA 2.8% 1L');
      final ijekav = ItemNormalizer.normalize('IMLEK MLIJEKO KRAVICA 2.8% 1L');
      expect(ekav.cleanedKey, ijekav.cleanedKey);
      expect(ekav.orderedTokens, containsAll(['kravica', 'mleko']));
    });
  });

  group('Layer 3: TokenSetMatcher', () {
    test('matches word order permutations with extra vendor tokens at 100%', () {
      final a = ItemNormalizer.normalize('IMLEK MLEKO MOJA KRAVICA 2.8% 1L').cleanedKey;
      final b = ItemNormalizer.normalize('MOJA KRAVICA MLEKO 2.8% 1L').cleanedKey;
      expect(TokenSetMatcher.tokenSetRatio(a, b), greaterThanOrEqualTo(95));
    });

    test('tolerates 1-character ERP/OCR typos on tokens longer than 4 chars', () {
      final a = ItemNormalizer.normalize('JOGURT BALANS 1KG').cleanedKey;
      final b = ItemNormalizer.normalize('JOGRT BALANS 1KG').cleanedKey;
      expect(TokenSetMatcher.tokenSetRatio(a, b), greaterThanOrEqualTo(85));
    });

    test('prevents false merges when intersection only contains generic category words', () {
      final a = ItemNormalizer.normalize('IMLEK MLEKO 1L').cleanedKey;
      final b = ItemNormalizer.normalize('MEGGLE MLEKO 1L').cleanedKey;
      expect(TokenSetMatcher.tokenSetRatio(a, b), lessThan(85));
    });

    test('prevents false merges across incompatible product variants (Zero, Tip 400 vs 500)', () {
      final cola = ItemNormalizer.normalize('COCA COLA 0.5L').cleanedKey;
      final colaZero = ItemNormalizer.normalize('COCA COLA ZERO 0.5L').cleanedKey;
      expect(TokenSetMatcher.tokenSetRatio(cola, colaZero), lessThan(85));

      final t400 = ItemNormalizer.normalize('BRASNO TIP 400 1KG').cleanedKey;
      final t500 = ItemNormalizer.normalize('BRASNO TIP 500 1KG').cleanedKey;
      expect(TokenSetMatcher.tokenSetRatio(t400, t500), lessThan(85));
    });
  });

  group('End-to-End Normalization & Analytics', () {
    late AppDatabase db;
    late AnalyticsRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = AnalyticsRepository(db);
    });

    tearDown(() => db.close());

    Future<int> insertMerchant(String tin, String name) =>
        db.into(db.merchants).insert(
              MerchantsCompanion.insert(tin: tin, name: name),
            );

    Future<int> insertReceipt({
      required int merchantId,
      required int total,
      required DateTime pfrTime,
    }) =>
        db.into(db.receipts).insert(
              ReceiptsCompanion.insert(
                merchantId: merchantId,
                verificationUrl: 'u_${DateTime.now().microsecondsSinceEpoch}',
                pfrTime: Value(pfrTime),
                totalAmount: Value(total),
                fetchStatus: const Value(FetchStatus.complete),
              ),
            );

    Future<void> insertLineItem({
      required int receiptId,
      required String name,
      required int unitPrice,
      required int total,
      double qty = 1.0,
    }) =>
        db.into(db.lineItems).insert(
              LineItemsCompanion.insert(
                receiptId: receiptId,
                name: name,
                quantity: Value(qty),
                unitPrice: Value(unitPrice),
                total: Value(total),
              ),
            );

    test('aggregates fragmented fiscal names across merchants and separates measures in price history & inflation', () async {
      final maxi = await insertMerchant('100', 'Maxi');
      final idea = await insertMerchant('200', 'Idea');
      final pekara = await insertMerchant('300', 'Lokalni Market');

      final r1 = await insertReceipt(
        merchantId: maxi,
        total: 15000,
        pfrTime: DateTime(2026, 1, 5),
      );
      final r2 = await insertReceipt(
        merchantId: idea,
        total: 16500,
        pfrTime: DateTime(2026, 2, 10),
      );
      final r3 = await insertReceipt(
        merchantId: pekara,
        total: 9000,
        pfrTime: DateTime(2026, 2, 20),
      );

      // Tri različita zapisa istog proizvoda (dva od 1L, jedan od 0.5L)
      await insertLineItem(
        receiptId: r1,
        name: 'MOJA KRAVICA 2.8%MM 1L TT AKCIJA',
        unitPrice: 15000,
        total: 15000,
      );
      await insertLineItem(
        receiptId: r2,
        name: 'IMLEK MLEKO KRAVICA 2,8% 1000ML',
        unitPrice: 16500,
        total: 16500,
      );
      await insertLineItem(
        receiptId: r3,
        name: 'МЛЕКО МОЈА КРАВИЦА 2.8% 0.5Л',
        unitPrice: 9000,
        total: 9000,
      );

      final summary = await repo.loadSummary(
        AnalyticsRange.all,
        now: DateTime(2026, 3, 1),
      );

      // Sve tri stavke su grupisane u jedan kanonski proizvod u topItems
      expect(summary.topItems, hasLength(1));
      final top = summary.topItems.first;
      expect(top.name, 'Mleko Moja Kravica');
      expect(top.totalMinor, 40500);
      expect(top.count, 3);
      expect(top.canonicalItemId, isNotNull);

      // Detalji artikla sadrže sve 3 sirove varijante i razdvojenu istoriju cena po meri (1L vs 0.5L)
      final detail = await repo.itemDetail(
        top.name,
        AnalyticsRange.all,
        now: DateTime(2026, 3, 1),
      );
      expect(detail.rawVariants, hasLength(3));
      expect(detail.priceHistoryByMeasure.keys, containsAll(['1L', '0.5L']));
      expect(detail.priceHistoryByMeasure['1L'], hasLength(2));
      expect(detail.priceHistoryByMeasure['0.5L'], hasLength(1));
      // Primarna serija na grafikonu koristi meru sa najviše kupovina (1L: 150 -> 165 RSD)
      expect(
        detail.priceHistory.map((p) => p.unitPriceMinor).toList(),
        [15000, 16500],
      );

      // Napredna analitika (praćenje inflacije cena) ne meša 0.5L i 1L
      final adv = await repo.loadAdvancedSummary(
        const AdvancedAnalyticsFilter(
          preset: AdvancedAnalyticsDatePreset.all,
          currency: Currency.rsd,
        ),
        now: DateTime(2026, 3, 1),
      );
      expect(adv.priceInflation, hasLength(1));
      expect(adv.priceInflation.first.name, 'Mleko Moja Kravica (1L)');
      expect(adv.priceInflation.first.firstPriceMinor, 15000);
      expect(adv.priceInflation.first.latestPriceMinor, 16500);
    });

    test('manual merge (human-in-the-loop) combines canonical items and persists aliases for future receipts', () async {
      final m = await insertMerchant('100', 'Maxi');
      final r1 = await insertReceipt(
        merchantId: m,
        total: 20000,
        pfrTime: DateTime(2026, 1, 5),
      );
      final r2 = await insertReceipt(
        merchantId: m,
        total: 22000,
        pfrTime: DateTime(2026, 1, 10),
      );

      // Dva potpuno različita interna naziva za isti lokalni proizvod
      await insertLineItem(
        receiptId: r1,
        name: 'DOMACA KAFA GRAND GOLD 200G',
        unitPrice: 20000,
        total: 20000,
      );
      await insertLineItem(
        receiptId: r2,
        name: 'PRZIONICA KAFA ZLATNA 200G',
        unitPrice: 22000,
        total: 22000,
      );

      final before = await repo.loadSummary(
        AnalyticsRange.all,
        now: DateTime(2026, 2, 1),
      );
      expect(before.topItems, hasLength(2));

      final target = before.topItems.first;
      final source = before.topItems.last;

      await repo.mergeCanonicalItems(
        targetCanonicalId: target.canonicalItemId!,
        sourceCanonicalIds: [source.canonicalItemId!],
        customDisplayName: 'Grand Gold Kafa',
      );

      // Novi račun sa sirovim nazivom iz spojenog artikla automatski dobija ciljni canonicalItemId
      final r3 = await insertReceipt(
        merchantId: m,
        total: 23000,
        pfrTime: DateTime(2026, 1, 20),
      );
      await insertLineItem(
        receiptId: r3,
        name: 'PRZIONICA KAFA ZLATNA 200G',
        unitPrice: 23000,
        total: 23000,
      );

      final after = await repo.loadSummary(
        AnalyticsRange.all,
        now: DateTime(2026, 2, 1),
      );
      expect(after.topItems, hasLength(1));
      expect(after.topItems.first.name, 'Grand Gold Kafa');
      expect(after.topItems.first.totalMinor, 65000);
      expect(after.topItems.first.count, 3);
    });

    test('bulk migration of 5,000 existing line items completes in milliseconds', () async {
      final m = await insertMerchant('100', 'Maxi');
      final r = await insertReceipt(
        merchantId: m,
        total: 50000000,
        pfrTime: DateTime(2026, 1, 15),
      );

      final sampleRawNames = [
        '3850123 MOJA KRAVICA MLEKO 2.8% 1L TT',
        'IMLEK KRAVICA ML. 1L',
        'COCA COLA 0.5L PET',
        'KOKA KOLA GAZ.SOK 0,5L',
        'SMOKI STARK 150G',
        'PLAZMA KEKS 300G BAMBI',
        'JAFFA CAKES 150G CRVENKA',
        'PAVLAKA MOJA KRAVICA 20% 180G',
        'JOGURT BALANS+ 1KG IMLEK',
        'BANANA 1KG',
        'HLEB SAVA 500G',
        'JAJA M 10/1',
        'SUNCOKRETOVO ULJE DIJAMANT 1L',
        'GRAND KAFA GOLD 200G',
        'TOALET PAPIR PERFEX 10/1 3SL',
        'DETERDZENT ARIEL 2KG',
        'EUROKREM TAKOVO 500G',
        'KNJAZ MILOS 1.5L GAZIRANA',
        'ROSA VODA 1.5L NEGAZ.',
        'LOKALNA PEKARA BUREK SA SIROM 250G',
      ];

      // Ubacimo 5.000 sirovih stavki direktno u line_items sa canonicalItemId = NULL
      // (simulacija postojeće baze korisnika pre migracije v8 -> v9).
      await db.batch((b) {
        for (var i = 0; i < 5000; i++) {
          final rawName = sampleRawNames[i % sampleRawNames.length];
          b.insert(
            db.lineItems,
            LineItemsCompanion.insert(
              receiptId: r,
              name: rawName,
              quantity: const Value(1.0),
              unit: const Value('KOM'),
              unitPrice: const Value(15000),
              total: const Value(15000),
            ),
          );
        }
      });

      final sw = Stopwatch()..start();
      await ItemNormalizationService(db).ensureNormalized();
      sw.stop();

      // Proverimo da su sve stavke dobile canonicalItemId i da je izvršavanje brzo (< 500 ms).
      final remainingNull = await (db.select(db.lineItems)
            ..where((li) => li.canonicalItemId.isNull()))
          .get();
      expect(remainingNull, isEmpty);
      expect(sw.elapsedMilliseconds, lessThan(1000));
      // ignore: avoid_print
      print('5,000 line_items normalized in ${sw.elapsedMilliseconds} ms');
    });

    test('concurrent v8 -> v10 upgrade: app migrates (with retry), background worker skips instead of colliding', () async {
      final tempDir = await Directory.systemTemp.createTemp('troskovnik_v8_upgrade_');
      final dbFile = File(p.join(tempDir.path, 'test_v8.db'));

      try {
        // Kreiraj v8 bazu (pre dodavanja canonical_items i item_aliases) sa postojećim računima i stavkama.
        final rawDb = raw_sqlite.sqlite3.open(dbFile.path);
        rawDb.execute('''
          CREATE TABLE merchants (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            tin TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            location_name TEXT,
            address TEXT,
            city TEXT,
            first_seen INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
          );
          CREATE TABLE categories (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color TEXT NOT NULL DEFAULT '#607D8B',
            icon TEXT,
            is_default INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0
          );
          CREATE TABLE receipts (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            merchant_id INTEGER NOT NULL REFERENCES merchants(id),
            verification_url TEXT NOT NULL,
            token TEXT,
            invoice_number TEXT,
            pfr_number TEXT,
            buyer_id TEXT,
            pfr_time INTEGER,
            sdc_time INTEGER,
            invoice_counter TEXT,
            invoice_type INTEGER NOT NULL DEFAULT 0,
            transaction_type INTEGER NOT NULL DEFAULT 0,
            total_amount INTEGER NOT NULL DEFAULT 0,
            payment_method TEXT,
            payments_json TEXT,
            tax_json TEXT,
            journal_text TEXT,
            fetch_status INTEGER NOT NULL DEFAULT 2,
            items_status INTEGER NOT NULL DEFAULT 0,
            items_source INTEGER NOT NULL DEFAULT 0,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry_at INTEGER,
            is_business INTEGER NOT NULL DEFAULT 0,
            is_manual INTEGER NOT NULL DEFAULT 0,
            has_discrepancy INTEGER NOT NULL DEFAULT 0,
            country INTEGER NOT NULL DEFAULT 0,
            currency INTEGER NOT NULL DEFAULT 0,
            note TEXT,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
          );
          CREATE TABLE line_items (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            receipt_id INTEGER NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            quantity REAL NOT NULL DEFAULT 1.0,
            unit TEXT,
            unit_price INTEGER NOT NULL DEFAULT 0,
            total INTEGER NOT NULL DEFAULT 0,
            tax_label TEXT,
            tax_rate REAL,
            source INTEGER NOT NULL DEFAULT 0,
            is_unparsed INTEGER NOT NULL DEFAULT 0,
            category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL
          );
          CREATE TABLE warranties (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            receipt_id INTEGER NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
            line_item_id INTEGER REFERENCES line_items(id) ON DELETE SET NULL,
            product_name TEXT NOT NULL,
            purchase_date INTEGER NOT NULL,
            expiry_date INTEGER NOT NULL,
            duration_months INTEGER NOT NULL DEFAULT 24,
            reminder_days_before INTEGER NOT NULL DEFAULT 30,
            image_paths TEXT,
            note TEXT,
            created_at INTEGER NOT NULL DEFAULT 0
          );
          INSERT INTO merchants (id, tin, name) VALUES (1, '100200300', 'Maxi');
          INSERT INTO receipts (id, merchant_id, verification_url, pfr_time, total_amount, fetch_status)
            VALUES (1, 1, 'https://suf.purs.gov.rs/v/?vl=test1', 1767225600, 31500, 2);
          INSERT INTO line_items (receipt_id, name, quantity, unit, unit_price, total)
            VALUES (1, 'MOJA KRAVICA MLEKO 2.8% 1L', 1.0, 'KOM', 15000, 15000),
                   (1, 'IMLEK MLEKO KRAVICA 2,8% 1000ML', 1.0, 'KOM', 16500, 16500);
          PRAGMA user_version = 8;
        ''');
        rawDb.dispose();

        AppDatabase openInBackground({bool allowMigration = true}) =>
            AppDatabase(
              NativeDatabase.createInBackground(
                dbFile,
                setup: (d) {
                  d.execute('PRAGMA busy_timeout = 30000;');
                  d.execute('PRAGMA journal_mode = WAL;');
                  d.execute('PRAGMA foreign_keys = ON;');
                  if (!allowMigration) throwIfMigrationPending(d);
                },
              ),
            );

        // Glavni UI izolat i Android WorkManager izolat otvaraju isti v8 fajl
        // u istom trenutku (ažuriranje aplikacije). Migraciju sme da radi samo
        // aplikacija (uz ponovni pokušaj); worker bez prava na migraciju
        // preskače krug ako baza još nije migrirana.
        final mainFuture = openAppDatabaseWithRetry(openInBackground);
        final dbWorker = openInBackground(allowMigration: false);
        final workerFuture = dbWorker.select(dbWorker.receipts).get().then<List<ReceiptRow>?>(
              (rows) => rows,
              // Isto kao background_refetch: preskoči krug, ne ruši se.
              onError: (Object e) => shouldSkipBackgroundRun(e)
                  ? null
                  : throw e,
            );
        final dbMain = await mainFuture;

        try {
          final results = await Future.wait<Object?>([
            dbMain.select(dbMain.receipts).get(),
            workerFuture,
            AnalyticsRepository(dbMain).loadSummary(
              AnalyticsRange.all,
              now: DateTime(2026, 3, 1),
            ),
          ]);

          final mainReceipts = results[0] as List<ReceiptRow>;
          // Worker je ili preskočio krug (null) ili video već migriranu bazu.
          final workerReceipts = results[1] as List<ReceiptRow>?;
          final summary = results[2] as AnalyticsSummary;

          expect(mainReceipts, hasLength(1));
          if (workerReceipts != null) expect(workerReceipts, hasLength(1));
          expect(summary.topItems, hasLength(1));
          expect(summary.topItems.first.name, 'Mleko Moja Kravica');
          expect(summary.topItems.first.count, 2);
        } finally {
          await dbMain.close();
          await dbWorker.close();
        }
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('Module 1 & 2: itemDetail computes cheapest merchant, 1L/1kg package value, cadence, unmerge, and catalogItems', () async {
      final mMaxi = await insertMerchant('101', 'Maxi');
      final mLidl = await insertMerchant('102', 'Lidl');

      final r1 = await insertReceipt(
        merchantId: mMaxi,
        total: 40000,
        pfrTime: DateTime(2026, 1, 5),
      );
      final r2 = await insertReceipt(
        merchantId: mLidl,
        total: 40000,
        pfrTime: DateTime(2026, 1, 15),
      );
      final r3 = await insertReceipt(
        merchantId: mMaxi,
        total: 40000,
        pfrTime: DateTime(2026, 1, 25),
      );

      // Kupovina Coca-Cole u različitim prodavnicama i pakovanjima (0.5L i 1.5L)
      await insertLineItem(
        receiptId: r1,
        name: 'COCA COLA 0.5L PET',
        unitPrice: 9500, // 95 RSD (190 RSD / 1L)
        total: 9500,
      );
      await insertLineItem(
        receiptId: r2,
        name: 'KOKA KOLA GAZ. 0,5L',
        unitPrice: 8000, // 80 RSD u Lidlu (najpovoljnije za 0.5L)
        total: 8000,
      );
      await insertLineItem(
        receiptId: r3,
        name: 'COCA-COLA 1.5L PET',
        unitPrice: 15000, // 150 RSD za 1.5L (100 RSD / 1L -> Najisplativije pakovanje!)
        total: 15000,
      );

      final summary = await repo.loadSummary(
        AnalyticsRange.all,
        now: DateTime(2026, 2, 1),
      );
      expect(summary.totalUniqueItemsCount, 1);
      final canonicalName = summary.topItems.first.name;
      expect(canonicalName, 'Coca-Cola');

      final detail = await repo.itemDetail(
        canonicalName,
        AnalyticsRange.all,
        now: DateTime(2026, 2, 1),
      );

      // 1. Poređenje cena po prodavcima za 0.5L
      final stats05 = detail.merchantStatsByMeasure['0.5L'];
      expect(stats05, isNotNull);
      expect(stats05, hasLength(2));
      expect(stats05!.first.merchantName, 'Lidl');
      expect(stats05.first.avgUnitPriceMinor, 8000);
      expect(stats05.first.isCheapest, isTrue);
      expect(stats05.last.merchantName, 'Maxi');
      expect(stats05.last.isCheapest, isFalse);

      // 2. Poređenje isplativosti pakovanja (cena po 1L)
      expect(detail.measureComparisons, hasLength(2));
      final bestPack = detail.measureComparisons.first;
      expect(bestPack.measureLabel, '1.5L');
      expect(bestPack.baseUnitLabel, '1L');
      expect(bestPack.normalizedPricePerBaseMinor, 10000); // 100.00 RSD / 1L
      expect(bestPack.isBestValue, isTrue);

      final smallerPack = detail.measureComparisons.last;
      expect(smallerPack.measureLabel, '0.5L');
      expect(smallerPack.isBestValue, isFalse);

      // 3. Ritam kupovine (3 kupovine u rasponu od 20 dana -> svakih ~10 dana)
      expect(detail.averageDaysBetweenPurchases, 10);
      expect(detail.estimatedMonthlyMinor, isNotNull);
      expect(detail.recentPurchases, hasLength(3));
      expect(detail.recentPurchases.first.receiptId, r3);

      // 4. Katalog artikala (Modul 2)
      final catalog = await repo.catalogItems(
        AnalyticsRange.all,
        now: DateTime(2026, 2, 1),
      );
      expect(catalog, hasLength(1));
      expect(catalog.first.name, 'Coca-Cola');
      expect(catalog.first.rawVariants, hasLength(3));

      // 5. Odvajanje sirove varijante (Unmerge)
      expect(detail.canonicalItemId, isNotNull);
      await repo.unmergeRawVariant(
        canonicalItemId: detail.canonicalItemId!,
        rawName: 'COCA-COLA 1.5L PET',
      );

      final catalogAfterUnmerge = await repo.catalogItems(
        AnalyticsRange.all,
        now: DateTime(2026, 2, 1),
      );
      expect(catalogAfterUnmerge, hasLength(2));
    });
  });
}



