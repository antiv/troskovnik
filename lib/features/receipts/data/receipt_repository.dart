import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../source/domain/receipt_source.dart';
import '../domain/retry_policy.dart';

/// Rezultat čuvanja: id zapisa i da li je bio duplikat (već postojao).
class SaveResult {
  const SaveResult({required this.receiptId, required this.wasDuplicate});
  final int receiptId;
  final bool wasDuplicate;
}

/// Repository nad Drift bazom: čuvanje/čitanje računa.
///
/// Garantuje da se zapis NIKAD ne gubi (sekcija 8): čak i kad nema stavki,
/// zaglavlje/token se upisuju, a stavke se dopune kasnije (sekcija 5).
class ReceiptRepository {
  ReceiptRepository(this._db, {this._retryPolicy = const RetryPolicy()});

  final AppDatabase _db;
  final RetryPolicy _retryPolicy;

  /// Pristup bazi za jednostavna ažuriranja iz UI-ja (npr. oznaka „poslovni", beleška).
  AppDatabase get db => _db;

  /// Postavi/oslobodi oznaku „poslovni račun".
  Future<void> setBusiness(int receiptId, bool value, {DateTime? now}) =>
      (_db.update(_db.receipts)..where((r) => r.id.equals(receiptId)))
          .write(ReceiptsCompanion(
        isBusiness: Value(value),
        updatedAt: Value(now ?? DateTime.now()),
      ));

  /// Sačuvaj belešku.
  Future<void> setNote(int receiptId, String? note, {DateTime? now}) =>
      (_db.update(_db.receipts)..where((r) => r.id.equals(receiptId)))
          .write(ReceiptsCompanion(
        note: Value(note),
        updatedAt: Value(now ?? DateTime.now()),
      ));

  /// Sačuvaj parsiran račun. Ako (invoice_number + pfr_number) već postoji,
  /// vrati postojeći zapis (otvaranje umesto novog — sekcija 8).
  Future<SaveResult> saveParsed({
    required String verificationUrl,
    required String? token,
    required ParsedReceipt parsed,
    DateTime? now,
  }) async {
    final header = parsed.header;
    final ts = now ?? DateTime.now();

    return _db.transaction(() async {
      // Duplikat?
      if (header?.invoiceNumber != null || header?.pfrNumber != null) {
        final existing = await (_db.select(_db.receipts)
              ..where((r) =>
                  r.invoiceNumber.equalsNullable(header?.invoiceNumber) &
                  r.pfrNumber.equalsNullable(header?.pfrNumber)))
            .get();
        if (existing.isNotEmpty) {
          return SaveResult(
              receiptId: existing.first.id, wasDuplicate: true);
        }
      }

      final merchantId = header == null
          ? await _upsertUnknownMerchant()
          : await _upsertMerchant(header, ts);

      final nextRetry = parsed.itemsStatus == ItemsStatus.pendingServer
          ? _retryPolicy.nextRetryAt(0, from: ts)
          : null;

      final receiptId = await _db.into(_db.receipts).insert(
            ReceiptsCompanion.insert(
              merchantId: merchantId,
              verificationUrl: verificationUrl,
              token: Value(token),
              invoiceNumber: Value(header?.invoiceNumber),
              pfrNumber: Value(header?.pfrNumber),
              pfrTime: Value(header?.pfrTime),
              invoiceCounter: Value(header?.invoiceCounter),
              transactionType:
                  Value(header?.transactionType ?? TransactionType.sale),
              totalAmount: Value(header?.totalAmount ?? 0),
              paymentMethod: Value(header?.paymentMethod),
              taxJson: Value(header?.taxJson),
              journalText: Value(parsed.journalText),
              fetchStatus: Value(parsed.fetchStatus),
              itemsStatus: Value(parsed.itemsStatus),
              itemsSource: Value(parsed.itemsSource),
              nextRetryAt: Value(nextRetry),
              createdAt: Value(ts),
              updatedAt: Value(ts),
            ),
          );

      await _insertItems(receiptId, parsed.items);
      return SaveResult(receiptId: receiptId, wasDuplicate: false);
    });
  }

  /// Ažuriraj postojeći zapis posle uspešnog re-fetch-a (sekcija 5, tačka 4).
  Future<void> applyRefetch(int receiptId, ParsedReceipt parsed,
      {DateTime? now}) async {
    final ts = now ?? DateTime.now();
    await _db.transaction(() async {
      // Zameni stavke ako su stigle bolje.
      if (parsed.items.isNotEmpty) {
        await (_db.delete(_db.lineItems)
              ..where((i) => i.receiptId.equals(receiptId)))
            .go();
        await _insertItems(receiptId, parsed.items);
      }

      final currentRows = await (_db.select(_db.receipts)
            ..where((r) => r.id.equals(receiptId)))
          .get();
      if (currentRows.isEmpty) return;
      final current = currentRows.first;

      final stillPending = parsed.itemsStatus == ItemsStatus.pendingServer;
      final newRetryCount = stillPending ? current.retryCount + 1 : current.retryCount;
      final nextRetry = stillPending
          ? _retryPolicy.nextRetryAt(newRetryCount, from: ts)
          : null;

      await (_db.update(_db.receipts)..where((r) => r.id.equals(receiptId)))
          .write(ReceiptsCompanion(
        fetchStatus: Value(parsed.fetchStatus),
        itemsStatus: Value(parsed.itemsStatus),
        itemsSource: Value(parsed.itemsSource),
        journalText: Value(parsed.journalText ?? current.journalText),
        retryCount: Value(newRetryCount),
        nextRetryAt: Value(nextRetry),
        updatedAt: Value(ts),
      ));
    });
  }

  /// Računi kojima treba re-fetch (pendingServer i next_retry_at <= sada).
  Future<List<ReceiptRow>> dueForRefetch({DateTime? now}) {
    final ts = now ?? DateTime.now();
    return (_db.select(_db.receipts)
          ..where((r) =>
              r.itemsStatus.equalsValue(ItemsStatus.pendingServer) &
              r.nextRetryAt.isSmallerOrEqualValue(ts)))
        .get();
  }

  Future<ReceiptRow?> findById(int id) =>
      (_db.select(_db.receipts)..where((r) => r.id.equals(id)))
          .getSingleOrNull();

  Future<List<LineItemRow>> itemsFor(int receiptId) =>
      (_db.select(_db.lineItems)..where((i) => i.receiptId.equals(receiptId)))
          .get();

  Future<void> _insertItems(int receiptId, List<ParsedLineItem> items) async {
    await _db.batch((b) {
      for (final it in items) {
        b.insert(
          _db.lineItems,
          LineItemsCompanion.insert(
            receiptId: receiptId,
            name: it.name,
            quantity: Value(it.quantity),
            unit: Value(it.unit),
            unitPrice: Value(it.unitPrice),
            total: Value(it.total),
            taxLabel: Value(it.taxLabel),
            taxRate: Value(it.taxRate),
            source: Value(it.source),
            isUnparsed: Value(it.isUnparsed),
          ),
        );
      }
    });
  }

  Future<int> _upsertMerchant(ReceiptHeader header, DateTime ts) async {
    final existing = await (_db.select(_db.merchants)
          ..where((m) => m.tin.equals(header.merchantTin)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return _db.into(_db.merchants).insert(
          MerchantsCompanion.insert(
            tin: header.merchantTin,
            name: header.merchantName.isEmpty
                ? header.merchantTin
                : header.merchantName,
            locationName: Value(header.locationName),
            address: Value(header.address),
            firstSeen: Value(ts),
          ),
        );
  }

  Future<int> _upsertUnknownMerchant() async {
    final existing = await (_db.select(_db.merchants)
          ..where((m) => m.tin.equals('UNKNOWN')))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return _db.into(_db.merchants).insert(
          MerchantsCompanion.insert(tin: 'UNKNOWN', name: 'UNKNOWN'),
        );
  }
}
