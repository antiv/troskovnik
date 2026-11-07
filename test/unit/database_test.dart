import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/core/domain/country.dart';
import 'package:troskovnik/core/domain/currency.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('insert merchant + receipt + line item round-trips with enums', () async {
    final merchantId = await db.into(db.merchants).insert(
          MerchantsCompanion.insert(tin: '123456789', name: 'Maxi'),
        );

    final receiptId = await db.into(db.receipts).insert(
          ReceiptsCompanion.insert(
            merchantId: merchantId,
            verificationUrl: 'https://suf.purs.gov.rs/v/?vl=ABC',
            invoiceNumber: const Value('AB-1'),
            pfrNumber: const Value('PFR-1'),
            totalAmount: const Value(123456), // 1.234,56 RSD
            fetchStatus: const Value(FetchStatus.headerOnly),
            itemsStatus: const Value(ItemsStatus.pendingServer),
          ),
        );

    await db.into(db.lineItems).insert(
          LineItemsCompanion.insert(
            receiptId: receiptId,
            name: 'Mleko 1l',
            quantity: const Value(2.0),
            unitPrice: const Value(9900),
            total: const Value(19800),
            taxLabel: const Value('Ђ'),
            taxRate: const Value(10),
            source: const Value(ItemsSource.journal),
          ),
        );

    final receipt = await (db.select(db.receipts)
          ..where((r) => r.id.equals(receiptId)))
        .getSingle();
    expect(receipt.fetchStatus, FetchStatus.headerOnly);
    expect(receipt.itemsStatus, ItemsStatus.pendingServer);
    expect(receipt.totalAmount, 123456);

    final items = await db.select(db.lineItems).get();
    expect(items, hasLength(1));
    expect(items.first.name, 'Mleko 1l');
    expect(items.first.taxLabel, 'Ђ');
  });

  test('duplicate (invoice_number + pfr_number) is rejected', () async {
    final merchantId = await db.into(db.merchants).insert(
          MerchantsCompanion.insert(tin: '111', name: 'Idea'),
        );

    Future<void> insertReceipt() => db.into(db.receipts).insert(
          ReceiptsCompanion.insert(
            merchantId: merchantId,
            verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
            invoiceNumber: const Value('DUP-1'),
            pfrNumber: const Value('PFR-DUP'),
          ),
        );

    await insertReceipt();
    expect(
      insertReceipt,
      throwsA(predicate(
        (e) => e.toString().toLowerCase().contains('unique'),
        'is a UNIQUE constraint violation',
      )),
    );
  });

  test('onUpgrade from v6 backfills country/currency and buyer companies', () async {
    final rawDb = sqlite3.openInMemory();
    rawDb.execute('''
      PRAGMA user_version = 6;
      CREATE TABLE merchants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tin TEXT NOT NULL,
        name TEXT NOT NULL,
        location_name TEXT,
        address TEXT,
        first_seen INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_id INTEGER NOT NULL REFERENCES merchants (id),
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
        verification_url TEXT NOT NULL,
        token TEXT,
        journal_text TEXT,
        fetch_status INTEGER NOT NULL DEFAULT 0,
        items_status INTEGER NOT NULL DEFAULT 0,
        items_source INTEGER NOT NULL DEFAULT 0,
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_retry_at INTEGER,
        is_business INTEGER NOT NULL DEFAULT 0,
        is_manual INTEGER NOT NULL DEFAULT 0,
        image_path TEXT,
        note TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE line_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL REFERENCES receipts (id),
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit TEXT,
        unit_price INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL DEFAULT 0,
        tax_label TEXT,
        tax_rate REAL,
        source INTEGER NOT NULL DEFAULT 0,
        is_unparsed INTEGER NOT NULL DEFAULT 0,
        category_id INTEGER
      );
      CREATE TABLE warranties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL REFERENCES receipts (id),
        line_item_id INTEGER REFERENCES line_items (id),
        title TEXT NOT NULL,
        purchase_date INTEGER NOT NULL,
        duration_months INTEGER NOT NULL,
        expiry_date INTEGER NOT NULL,
        note TEXT,
        proof_image_path TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0
      );

      INSERT INTO merchants (id, tin, name) VALUES (1, '123456789', 'Test Merchant');
      INSERT INTO receipts (id, merchant_id, verification_url) VALUES (1, 1, 'https://suf.poreskaupravars.org/v/?vl=RS_TOKEN');
      INSERT INTO receipts (id, merchant_id, verification_url) VALUES (2, 1, 'https://tax.gov.me/v/?vl=ME_TOKEN');
      INSERT INTO receipts (id, merchant_id, verification_url, buyer_id) VALUES (3, 1, 'https://suf.purs.gov.rs/v/?vl=SR_TOKEN', '10:104318304');
      INSERT INTO receipts (id, merchant_id, verification_url, buyer_id) VALUES (4, 1, 'https://suf.purs.gov.rs/v/?vl=SR_JMBG', '11:0101990800000');
    ''');

    // Close db from setUp before opening test upgrade db.
    await db.close();
    final upgradeDb = AppDatabase(NativeDatabase.opened(rawDb));
    addTearDown(() => upgradeDb.close());

    final receipts = await (upgradeDb.select(upgradeDb.receipts)
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();

    expect(receipts, hasLength(4));
    expect(receipts[0].country, Country.republikaSrpska);
    expect(receipts[0].currency, Currency.bam);
    expect(receipts[1].country, Country.montenegro);
    expect(receipts[1].currency, Currency.eur);
    expect(receipts[2].country, Country.serbia);
    expect(receipts[2].currency, Currency.rsd);

    // v9: PIB kupca → buyer_tax_id + firma; JMBG ne. isBusiness se ne dira.
    expect(receipts[2].buyerTaxId, '104318304');
    expect(receipts[2].isBusiness, isFalse);
    expect(receipts[3].buyerTaxId, isNull);
    final companies = await upgradeDb.select(upgradeDb.companies).get();
    expect(companies.single.taxId, '104318304');
    expect(companies.single.country, Country.serbia);
  });

  // v9 je postojao u dve varijante (firme kupca / normalizacija artikala);
  // v10 mora da dovede bilo koju od njih (i prekinutu migraciju) do pune šeme.
  group('onUpgrade na v10 iz obe v9 varijante', () {
    /// Napravi bazu u punoj šemi, pa je „unazadi" datim SQL naredbama.
    Future<File> downgraded(List<String> sql) async {
      final dir = Directory.systemTemp.createTempSync('db_v10_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/app.db');
      final fresh = AppDatabase(NativeDatabase(file));
      await fresh.customSelect('SELECT 1').get();
      await fresh.close();
      final raw = sqlite3.open(file.path);
      raw.execute("INSERT INTO merchants (id, tin, name) VALUES (1, '100', 'M')");
      raw.execute("INSERT INTO receipts (id, merchant_id, verification_url, "
          "buyer_id, fetch_status) VALUES (1, 1, 'u1', '10:104318304', 2)");
      for (final s in sql) {
        raw.execute(s);
      }
      raw.dispose();
      return file;
    }

    Future<void> expectFullSchema(File file) async {
      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final receipt = await upgraded.select(upgraded.receipts).getSingle();
      expect(receipt.buyerTaxId, '104318304');
      final company = await upgraded.select(upgraded.companies).getSingle();
      expect(company.taxId, '104318304');
      // Kolone/tabele normalizacije moraju postojati (upit ne sme da pukne).
      await upgraded.select(upgraded.lineItems).get();
      await upgraded.select(upgraded.canonicalItems).get();
      await upgraded.select(upgraded.itemAliases).get();
      final v = await upgraded.customSelect('PRAGMA user_version').getSingle();
      expect(v.data.values.first, 10);
    }

    const dropCompanies = [
      'DROP TABLE companies',
      'ALTER TABLE receipts DROP COLUMN buyer_tax_id',
    ];
    const dropNormalization = [
      'DROP INDEX IF EXISTS idx_line_items_canonical',
      'ALTER TABLE line_items DROP COLUMN canonical_item_id',
      'ALTER TABLE line_items DROP COLUMN extracted_measure',
      'DROP TABLE item_aliases',
      'DROP TABLE canonical_items',
    ];

    test('v8 (bez obe nove šeme)', () async {
      await expectFullSchema(await downgraded(
          [...dropCompanies, ...dropNormalization, 'PRAGMA user_version = 8']));
    });

    test('v9 sa normalizacijom, bez firmi', () async {
      await expectFullSchema(
          await downgraded([...dropCompanies, 'PRAGMA user_version = 9']));
    });

    test('v9 sa firmama, bez normalizacije', () async {
      await expectFullSchema(
          await downgraded([...dropNormalization, 'PRAGMA user_version = 9']));
    });

    test('prekinuta migracija (buyer_tax_id već postoji, verzija 8)',
        () async {
      await expectFullSchema(await downgraded([
        'DROP TABLE companies',
        'UPDATE receipts SET buyer_tax_id = NULL',
        ...dropNormalization,
        'PRAGMA user_version = 8',
      ]));
    });
  });

  group('pozadinski izolat ne migrira', () {
    Future<File> v8File() async {
      final dir = Directory.systemTemp.createTempSync('db_guard_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/app.db');
      final fresh = AppDatabase(NativeDatabase(file));
      await fresh.customSelect('SELECT 1').get();
      await fresh.close();
      final raw = sqlite3.open(file.path);
      raw.execute('PRAGMA user_version = 8');
      raw.dispose();
      return file;
    }

    AppDatabase guarded(File f) =>
        AppDatabase(NativeDatabase(f, setup: throwIfMigrationPending));

    test('stara šema: baca DatabaseMigrationPendingException i ne dira bazu',
        () async {
      final file = await v8File();
      final worker = guarded(file);
      Object? error;
      try {
        await worker.customSelect('SELECT 1').get();
      } catch (e) {
        error = e;
      }
      await worker.close().catchError((_) {});
      expect(error, isNotNull);
      expect(isMigrationPendingError(error!), isTrue);
      expect(shouldSkipBackgroundRun(error), isTrue);
      final raw = sqlite3.open(file.path);
      addTearDown(raw.dispose);
      expect(raw.select('PRAGMA user_version').first.values.first, 8);
    });

    test('posle migracije aplikacije worker normalno radi', () async {
      final file = await v8File();
      final app = await openAppDatabaseWithRetry(
          () => AppDatabase(NativeDatabase(file)));
      await app.close();
      final worker = guarded(file);
      addTearDown(worker.close);
      expect(await worker.select(worker.receipts).get(), isEmpty);
    });
  });

  group('openAppDatabaseWithRetry', () {
    test('ponavlja posle prolazne greške', () async {
      var calls = 0;
      final db = await openAppDatabaseWithRetry(() {
        calls++;
        return AppDatabase(NativeDatabase.memory(setup: (d) {
          if (calls == 1) {
            throw SqliteException(5, 'database is locked');
          }
        }));
      }, delay: Duration.zero);
      addTearDown(db.close);
      expect(calls, 2);
      expect(await db.select(db.receipts).get(), isEmpty);
    });

    test('druga greška: vraća neotvorenu instancu (greška na prvom upitu)',
        () async {
      var calls = 0;
      final db = await openAppDatabaseWithRetry(() {
        calls++;
        return AppDatabase(NativeDatabase.memory(setup: (d) {
          throw SqliteException(26, 'file is not a database');
        }));
      }, delay: Duration.zero);
      expect(calls, 2); // jedan pokušaj + sveža lenja instanca
      await expectLater(db.select(db.receipts).get(), throwsA(anything));
      await db.close().catchError((_) {});
    });
  });
}
