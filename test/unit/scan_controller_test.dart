import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/core/db/providers.dart';
import 'package:troskovnik/features/receipts/data/receipt_providers.dart';
import 'package:troskovnik/features/scan/presentation/scan_controller.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';

/// Fake source vraća zadat ParsedReceipt ili baca grešku.
class _Source implements ReceiptSource {
  _Source(this.result, {this.error});
  final ParsedReceipt result;
  final ReceiptSourceException? error;

  @override
  Future<RawPortalResponse> fetch(String url) async {
    if (error != null) throw error!;
    return RawPortalResponse(verificationUrl: url, statusCode: 200, body: '');
  }

  @override
  ParsedReceipt parse(RawPortalResponse raw) => result;
}

ParsedReceipt _complete() => const ParsedReceipt(
      fetchStatus: FetchStatus.complete,
      itemsStatus: ItemsStatus.fromJournal,
      itemsSource: ItemsSource.journal,
      header: ReceiptHeader(
          merchantName: 'M',
          merchantTin: '1',
          invoiceNumber: 'I',
          pfrNumber: 'P',
          totalAmount: 100),
    );

ProviderContainer _container(AppDatabase db, ReceiptSource source) {
  final c = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWith((ref) async => db),
    receiptSourceProvider.overrideWithValue(source),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const validUrl = 'https://suf.purs.gov.rs/v/?vl=TOKEN';

  test('non-fiscal content -> ScanNotFiscal', () async {
    final c = _container(db, _Source(_complete()));
    final outcome =
        await c.read(scanControllerProvider).process('random text');
    expect(outcome, isA<ScanNotFiscal>());
  });

  test('valid receipt -> saved (not duplicate)', () async {
    final c = _container(db, _Source(_complete()));
    final outcome = await c.read(scanControllerProvider).process(validUrl);
    expect(outcome, isA<ScanSaved>());
    expect((outcome as ScanSaved).wasDuplicate, isFalse);
  });

  test('scanning same receipt twice -> second is duplicate', () async {
    final c = _container(db, _Source(_complete()));
    final ctrl = c.read(scanControllerProvider);
    await ctrl.process(validUrl);
    final second = await ctrl.process(validUrl);
    expect((second as ScanSaved).wasDuplicate, isTrue);
  });

  test('invalid receipt -> ScanError(invalidReceipt)', () async {
    final c = _container(
        db,
        _Source(const ParsedReceipt(
          fetchStatus: FetchStatus.invalid,
          itemsStatus: ItemsStatus.none,
          itemsSource: ItemsSource.none,
        )));
    final outcome = await c.read(scanControllerProvider).process(validUrl);
    expect((outcome as ScanError).kind, ScanErrorKind.invalidReceipt);
  });

  test('no network -> record still saved (not lost)', () async {
    final c = _container(
        db,
        _Source(_complete(), error: const NoNetworkException()));
    final outcome = await c.read(scanControllerProvider).process(validUrl);
    expect(outcome, isA<ScanSaved>());
    expect((outcome as ScanSaved).parsed.itemsStatus,
        ItemsStatus.pendingServer);
  });

  test('portal unavailable -> ScanError(portalUnavailable)', () async {
    final c = _container(
        db,
        _Source(_complete(),
            error: const PortalUnavailableException('down')));
    final outcome = await c.read(scanControllerProvider).process(validUrl);
    expect((outcome as ScanError).kind, ScanErrorKind.portalUnavailable);
  });
}
