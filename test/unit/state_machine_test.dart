import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/features/receipts/data/receipt_repository.dart';
import 'package:troskovnik/features/receipts/data/refetch_service.dart';
import 'package:troskovnik/features/receipts/domain/retry_policy.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';

ReceiptHeader _header(
        {String tin = '123',
        String? inv = 'INV-1',
        String? pfr = 'PFR-1',
        String? buyerId}) =>
    ReceiptHeader(
      merchantName: 'Test DOO',
      merchantTin: tin,
      buyerId: buyerId,
      invoiceNumber: inv,
      pfrNumber: pfr,
      totalAmount: 53000,
    );

/// Fake source koji vraća unapred zadat ParsedReceipt (bez mreže).
class _FakeSource implements ReceiptSource {
  _FakeSource(this._result, {this.throwError});
  final ParsedReceipt _result;
  ReceiptSourceException? throwError;

  @override
  Future<RawPortalResponse> fetch(String url) async {
    if (throwError != null) throw throwError!;
    return RawPortalResponse(verificationUrl: url, statusCode: 200, body: '');
  }

  @override
  ParsedReceipt parse(RawPortalResponse raw) => _result;
}

void main() {
  group('RetryPolicy', () {
    const p = RetryPolicy();
    final t0 = DateTime(2026, 6, 2, 12);

    test('first retry +5min, then 30min, 2h, 6h, 24h', () {
      expect(p.nextRetryAt(0, from: t0), t0.add(const Duration(minutes: 5)));
      expect(p.nextRetryAt(1, from: t0), t0.add(const Duration(minutes: 30)));
      expect(p.nextRetryAt(2, from: t0), t0.add(const Duration(hours: 2)));
      expect(p.nextRetryAt(3, from: t0), t0.add(const Duration(hours: 6)));
      expect(p.nextRetryAt(4, from: t0), t0.add(const Duration(hours: 24)));
    });

    test('caps at maxRetries (6) then returns null', () {
      expect(p.nextRetryAt(5, from: t0), t0.add(const Duration(hours: 24)));
      expect(p.canRetry(6), isFalse);
      expect(p.nextRetryAt(6, from: t0), isNull);
    });
  });

  group('ReceiptRepository', () {
    late AppDatabase db;
    late ReceiptRepository repo;
    final t0 = DateTime(2026, 6, 2, 12);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = ReceiptRepository(db);
    });
    tearDown(() => db.close());

    test('saving pendingServer schedules first retry (+5min)', () async {
      final res = await repo.saveParsed(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=A',
        token: 'A',
        parsed: ParsedReceipt(
          fetchStatus: FetchStatus.headerOnly,
          itemsStatus: ItemsStatus.pendingServer,
          itemsSource: ItemsSource.none,
          header: _header(),
        ),
        now: t0,
      );
      expect(res.wasDuplicate, isFalse);
      final row = await repo.findById(res.receiptId);
      expect(row!.itemsStatus, ItemsStatus.pendingServer);
      expect(row.nextRetryAt, t0.add(const Duration(minutes: 5)));
    });

    test('duplicate (invoice+pfr) opens existing, does not insert twice',
        () async {
      final parsed = ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: _header(),
      );
      final first = await repo.saveParsed(
          verificationUrl: 'u', token: 't', parsed: parsed, now: t0);
      final second = await repo.saveParsed(
          verificationUrl: 'u', token: 't', parsed: parsed, now: t0);
      expect(second.wasDuplicate, isTrue);
      expect(second.receiptId, first.receiptId);
      final count = await db.select(db.receipts).get();
      expect(count, hasLength(1));
    });

    test('buyer PIB (type 10) auto-marks receipt as business', () async {
      final res = await repo.saveParsed(
        verificationUrl: 'u-biz',
        token: 't',
        parsed: ParsedReceipt(
          fetchStatus: FetchStatus.complete,
          itemsStatus: ItemsStatus.fromJournal,
          itemsSource: ItemsSource.journal,
          header: _header(buyerId: '10:104318304'),
        ),
        now: t0,
      );
      final row = await repo.findById(res.receiptId);
      expect(row!.buyerId, '10:104318304');
      expect(row.isBusiness, isTrue);
    });

    test('buyer JMBG (type 11) does NOT auto-mark business', () async {
      final res = await repo.saveParsed(
        verificationUrl: 'u-jmbg',
        token: 't',
        parsed: ParsedReceipt(
          fetchStatus: FetchStatus.complete,
          itemsStatus: ItemsStatus.fromJournal,
          itemsSource: ItemsSource.journal,
          header: _header(buyerId: '11:0101990800000'),
        ),
        now: t0,
      );
      final row = await repo.findById(res.receiptId);
      expect(row!.buyerId, '11:0101990800000');
      expect(row.isBusiness, isFalse);
    });

    test('no buyer id -> not business', () async {
      final res = await repo.saveParsed(
        verificationUrl: 'u-none',
        token: 't',
        parsed: ParsedReceipt(
          fetchStatus: FetchStatus.complete,
          itemsStatus: ItemsStatus.fromJournal,
          itemsSource: ItemsSource.journal,
          header: _header(),
        ),
        now: t0,
      );
      final row = await repo.findById(res.receiptId);
      expect(row!.buyerId, isNull);
      expect(row.isBusiness, isFalse);
    });

    test('record never lost: saves even with null header', () async {
      final res = await repo.saveParsed(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=Z',
        token: 'Z',
        parsed: const ParsedReceipt(
          fetchStatus: FetchStatus.pending,
          itemsStatus: ItemsStatus.pendingServer,
          itemsSource: ItemsSource.none,
        ),
        now: t0,
      );
      final row = await repo.findById(res.receiptId);
      expect(row, isNotNull);
      expect(row!.verificationUrl, contains('vl=Z'));
    });
  });

  group('RefetchService transitions', () {
    late AppDatabase db;
    late ReceiptRepository repo;
    final t0 = DateTime(2026, 6, 2, 12);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = ReceiptRepository(db);
    });
    tearDown(() => db.close());

    Future<int> seedPending() async {
      final r = await repo.saveParsed(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=A',
        token: 'A',
        parsed: ParsedReceipt(
          fetchStatus: FetchStatus.headerOnly,
          itemsStatus: ItemsStatus.pendingServer,
          itemsSource: ItemsSource.none,
          header: _header(),
        ),
        now: t0,
      );
      return r.receiptId;
    }

    test('successful refetch -> fromJournal/complete + items inserted', () async {
      final id = await seedPending();
      final source = _FakeSource(ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: _header(),
        items: const [
          ParsedLineItem(
              name: 'Hleb',
              quantity: 1,
              unitPrice: 5000,
              total: 5000,
              source: ItemsSource.journal),
        ],
      ));
      final svc = RefetchService(source, repo);
      final ok = await svc.refetchOne(id, now: t0);

      expect(ok, isTrue);
      final row = await repo.findById(id);
      expect(row!.itemsStatus, ItemsStatus.fromJournal);
      expect(row.fetchStatus, FetchStatus.complete);
      expect(row.nextRetryAt, isNull);
      expect(await repo.itemsFor(id), hasLength(1));
    });

    test('still-pending refetch increments retry and reschedules', () async {
      final id = await seedPending();
      final source = _FakeSource(ParsedReceipt(
        fetchStatus: FetchStatus.headerOnly,
        itemsStatus: ItemsStatus.pendingServer,
        itemsSource: ItemsSource.none,
        header: _header(),
      ));
      final svc = RefetchService(source, repo);
      await svc.refetchOne(id, now: t0);

      final row = await repo.findById(id);
      expect(row!.retryCount, 1);
      // retryCount=1 -> +30min
      expect(row.nextRetryAt, t0.add(const Duration(minutes: 30)));
    });

    test('network error keeps record, does not throw', () async {
      final id = await seedPending();
      final source = _FakeSource(
        const ParsedReceipt(
          fetchStatus: FetchStatus.pending,
          itemsStatus: ItemsStatus.pendingServer,
          itemsSource: ItemsSource.none,
        ),
        throwError: const NoNetworkException(),
      );
      final svc = RefetchService(source, repo);
      final ok = await svc.refetchOne(id, now: t0);
      expect(ok, isFalse);
      expect(await repo.findById(id), isNotNull);
    });

    test('processDue picks only due pendingServer receipts', () async {
      final id = await seedPending(); // nextRetryAt = t0+5min
      final source = _FakeSource(ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: _header(),
        items: const [
          ParsedLineItem(
              name: 'X',
              quantity: 1,
              unitPrice: 100,
              total: 100,
              source: ItemsSource.journal),
        ],
      ));
      final svc = RefetchService(source, repo);

      // Pre dospeća: ništa.
      expect(await svc.processDue(now: t0), 0);
      // Posle dospeća (+6min): obrađeno.
      final done = await svc.processDue(now: t0.add(const Duration(minutes: 6)));
      expect(done, 1);
      final row = await repo.findById(id);
      expect(row!.itemsStatus, ItemsStatus.fromJournal);
    });
  });
}
