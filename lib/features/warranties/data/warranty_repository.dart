import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../domain/warranty_status.dart';
import 'warranty_notifier.dart';

/// Garancija sa kontekstom (prodavac, opciono naziv stavke) za prikaz.
class WarrantyView {
  const WarrantyView({
    required this.warranty,
    required this.merchantName,
    this.lineItemName,
  });
  final WarrantyRow warranty;
  final String merchantName;
  final String? lineItemName;

  WarrantyStatus status({DateTime? now}) =>
      WarrantyTiming.statusOf(warranty.expiryDate, now: now);
}

/// CRUD + upiti nad garancijama; zakazuje/otkazuje podsetnike.
class WarrantyRepository {
  WarrantyRepository(this._db, this._notifier);

  final AppDatabase _db;
  final WarrantyNotifier _notifier;

  /// Kreiraj garanciju. Istek se računa iz purchaseDate + durationMonths.
  Future<int> create({
    required int receiptId,
    int? lineItemId,
    required String title,
    required DateTime purchaseDate,
    int durationMonths = WarrantyTiming.defaultDurationMonths,
    String? note,
    String? proofImagePath,
    DateTime? now,
  }) async {
    final expiry = WarrantyTiming.expiryFrom(purchaseDate, durationMonths);
    final id = await _db.into(_db.warranties).insert(
          WarrantiesCompanion.insert(
            receiptId: receiptId,
            lineItemId: Value(lineItemId),
            title: title,
            purchaseDate: purchaseDate,
            durationMonths: Value(durationMonths),
            expiryDate: expiry,
            note: Value(note),
            proofImagePath: Value(proofImagePath),
          ),
        );
    await _notifier.scheduleReminders(
      warrantyId: id,
      title: title,
      expiryDate: expiry,
      now: now,
    );
    return id;
  }

  Future<void> delete(int warrantyId) async {
    await _notifier.cancelReminders(warrantyId);
    await (_db.delete(_db.warranties)..where((w) => w.id.equals(warrantyId)))
        .go();
  }

  Future<WarrantyRow?> findById(int id) =>
      (_db.select(_db.warranties)..where((w) => w.id.equals(id)))
          .getSingleOrNull();

  /// Sve garancije za jedan račun.
  Future<List<WarrantyRow>> forReceipt(int receiptId) =>
      (_db.select(_db.warranties)
            ..where((w) => w.receiptId.equals(receiptId))
            ..orderBy([(w) => OrderingTerm(expression: w.expiryDate)]))
          .get();

  /// Reaktivna lista svih garancija sa kontekstom, sortirana po roku isteka.
  Stream<List<WarrantyView>> watchAll() {
    final query = _db.select(_db.warranties).join([
      innerJoin(_db.receipts,
          _db.receipts.id.equalsExp(_db.warranties.receiptId)),
      innerJoin(_db.merchants,
          _db.merchants.id.equalsExp(_db.receipts.merchantId)),
      leftOuterJoin(_db.lineItems,
          _db.lineItems.id.equalsExp(_db.warranties.lineItemId)),
    ])
      ..orderBy([OrderingTerm(expression: _db.warranties.expiryDate)]);

    return query.watch().map((rows) => rows.map((row) {
          return WarrantyView(
            warranty: row.readTable(_db.warranties),
            merchantName: row.readTable(_db.merchants).name,
            lineItemName: row.readTableOrNull(_db.lineItems)?.name,
          );
        }).toList());
  }
}
