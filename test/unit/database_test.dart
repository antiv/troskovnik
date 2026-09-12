import 'package:drift/drift.dart';
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

  test('onUpgrade from v6 to v8 backfills country and currency based on verification_url', () async {
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
      INSERT INTO receipts (id, merchant_id, verification_url) VALUES (3, 1, 'https://suf.purs.gov.rs/v/?vl=SR_TOKEN');
    ''');

    // Close db from setUp before opening test upgrade db.
    await db.close();
    final upgradeDb = AppDatabase(NativeDatabase.opened(rawDb));
    addTearDown(() => upgradeDb.close());

    final receipts = await (upgradeDb.select(upgradeDb.receipts)
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();

    expect(receipts, hasLength(3));
    expect(receipts[0].country, Country.republikaSrpska);
    expect(receipts[0].currency, Currency.bam);
    expect(receipts[1].country, Country.montenegro);
    expect(receipts[1].currency, Currency.eur);
    expect(receipts[2].country, Country.serbia);
    expect(receipts[2].currency, Currency.rsd);
  });
}
