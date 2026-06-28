import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/domain/country.dart';
import '../../../core/domain/currency.dart';
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

  /// Račun je „poslovni" ako je kupac identifikovan PIB-om firme (tip „10").
  /// JMBG/lična dokumenta (drugi tipovi) se ne računaju kao poslovni.
  static bool isBusinessFromBuyer(String? buyerId) =>
      buyerId?.startsWith('10:') ?? false;

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
    Country country = Country.serbia,
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
              buyerId: Value(header?.buyerId),
              isBusiness: Value(isBusinessFromBuyer(header?.buyerId)),
              pfrTime: Value(header?.pfrTime),
              invoiceCounter: Value(header?.invoiceCounter),
              transactionType:
                  Value(header?.transactionType ?? TransactionType.sale),
              totalAmount: Value(header?.totalAmount ?? 0),
              paymentMethod: Value(header?.paymentMethod),
              paymentsJson: Value(header?.paymentsJson),
              taxJson: Value(header?.taxJson),
              journalText: Value(parsed.journalText),
              fetchStatus: Value(parsed.fetchStatus),
              itemsStatus: Value(parsed.itemsStatus),
              itemsSource: Value(parsed.itemsSource),
              hasDiscrepancy: Value(parsed.hasDiscrepancy),
              nextRetryAt: Value(nextRetry),
              country: Value(country),
              currency: Value(country.currency),
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
      // Zameni stavke ako su stigle bolje — ali zadrži korisnički unos: dodelu
      // kategorije po stavci i garancije vezane za konkretnu stavku (lineItemId).
      if (parsed.items.isNotEmpty) {
        await _replaceItemsPreserving(receiptId, parsed.items);
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

      // Nikad ne degradiramo status — fromSpecifications je bolji od fromJournal.
      final newItemsStatus = _betterItemsStatus(current.itemsStatus, parsed.itemsStatus);

      final header = parsed.header;

      // Žurnal (sa PIB-om kupca) stiže tek na refetch-u: popuni buyerId ako
      // je još prazan. NE diramo isBusiness — auto-postavka važi samo pri prvom
      // upisu, da se poštuje eventualni ručni izbor korisnika.
      final newBuyerId = current.buyerId ?? header?.buyerId;
      final newPaymentMethod = current.paymentMethod ?? header?.paymentMethod;
      final newPaymentsJson = current.paymentsJson ?? header?.paymentsJson;

      // Backfill zaglavlja: kad je račun prvi put sačuvan bez žurnala (još nije
      // bio proknjižen na serveru), upisan je kao UNKNOWN prodavac sa iznosom 0
      // i bez ПФР vremena/broja računa. Sada kad je žurnal stigao, prebaci zapis
      // na pravog prodavca i popuni polja zaglavlja — inače prodavac/iznos ostaju
      // UNKNOWN, a prazan pfr_time gura račun na dno liste sortirane po datumu.
      final currentMerchant = await (_db.select(_db.merchants)
            ..where((m) => m.id.equals(current.merchantId)))
          .getSingleOrNull();
      final needsHeaderBackfill =
          header != null && currentMerchant?.tin == 'UNKNOWN';
      final newMerchantId =
          needsHeaderBackfill ? await _upsertMerchant(header, ts) : null;

      await (_db.update(_db.receipts)..where((r) => r.id.equals(receiptId)))
          .write(ReceiptsCompanion(
        fetchStatus: Value(parsed.fetchStatus),
        itemsStatus: Value(newItemsStatus),
        itemsSource: Value(parsed.itemsSource),
        merchantId:
            newMerchantId != null ? Value(newMerchantId) : const Value.absent(),
        invoiceNumber: needsHeaderBackfill
            ? Value(header.invoiceNumber)
            : const Value.absent(),
        pfrNumber:
            needsHeaderBackfill ? Value(header.pfrNumber) : const Value.absent(),
        pfrTime:
            needsHeaderBackfill ? Value(header.pfrTime) : const Value.absent(),
        invoiceCounter: needsHeaderBackfill
            ? Value(header.invoiceCounter)
            : const Value.absent(),
        transactionType: needsHeaderBackfill
            ? Value(header.transactionType)
            : const Value.absent(),
        totalAmount: needsHeaderBackfill
            ? Value(header.totalAmount)
            : const Value.absent(),
        taxJson:
            needsHeaderBackfill ? Value(header.taxJson) : const Value.absent(),
        buyerId: Value(newBuyerId),
        paymentMethod: Value(newPaymentMethod),
        paymentsJson: Value(newPaymentsJson),
        journalText: Value(parsed.journalText ?? current.journalText),
        hasDiscrepancy: Value(parsed.hasDiscrepancy),
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

  /// Obriši račun (#7) zajedno sa njegovim stavkama i garancijama, u jednoj
  /// transakciji. (Brišemo eksplicitno jer FK kaskade nisu pouzdane na svim
  /// konfiguracijama.) Vraća id-jeve obrisanih garancija da caller otkaže
  /// njihove notifikacije.
  Future<List<int>> delete(int receiptId) async {
    return _db.transaction(() async {
      final warrantyIds = await (_db.selectOnly(_db.warranties)
            ..addColumns([_db.warranties.id])
            ..where(_db.warranties.receiptId.equals(receiptId)))
          .map((row) => row.read(_db.warranties.id)!)
          .get();

      await (_db.delete(_db.warranties)
            ..where((w) => w.receiptId.equals(receiptId)))
          .go();
      await (_db.delete(_db.lineItems)
            ..where((i) => i.receiptId.equals(receiptId)))
          .go();
      await (_db.delete(_db.receipts)..where((r) => r.id.equals(receiptId)))
          .go();
      return warrantyIds;
    });
  }

  Future<List<LineItemRow>> itemsFor(int receiptId) =>
      (_db.select(_db.lineItems)..where((i) => i.receiptId.equals(receiptId)))
          .get();

  /// Zameni stavke računa novim parsiranim stavkama, ali sačuvaj korisnički
  /// unos: dodelu kategorije (`categoryId`) i garancije vezane za stavku
  /// (`Warranties.lineItemId`).
  ///
  /// Stare i nove stavke se uparuju po nazivu (FIFO za istoimene); za uparenu
  /// stavku se prenosi kategorija, a garancije se prepoje sa starog na novi id.
  /// Neuparene stare stavke nestaju — njihove garancije ostaju na računu
  /// (lineItemId → null preko ON DELETE SET NULL).
  Future<void> _replaceItemsPreserving(
      int receiptId, List<ParsedLineItem> items) async {
    final oldItems = await itemsFor(receiptId);

    // Garancije vezane za konkretne stare stavke (pre brisanja, da znamo mapu).
    final itemWarranties = await (_db.select(_db.warranties)
          ..where((w) =>
              w.receiptId.equals(receiptId) & w.lineItemId.isNotNull()))
        .get();

    // Stare stavke grupisane po nazivu (FIFO), za prenos kategorije i mapiranje.
    final oldByName = <String, List<LineItemRow>>{};
    for (final o in oldItems) {
      oldByName.putIfAbsent(o.name, () => <LineItemRow>[]).add(o);
    }

    // Ubaci nove stavke; zapamti mapu stari_id → novi_id za uparene i skup
    // svih novih id-jeva (da pri brisanju ne diramo nove neuparene stavke).
    final oldToNew = <int, int>{};
    final newIds = <int>[];
    for (final it in items) {
      final queue = oldByName[it.name];
      final matched =
          (queue != null && queue.isNotEmpty) ? queue.removeAt(0) : null;
      final newId = await _db.into(_db.lineItems).insert(
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
              categoryId: Value(matched?.categoryId),
            ),
          );
      newIds.add(newId);
      if (matched != null) oldToNew[matched.id] = newId;
    }

    // Obriši stare stavke (sve osim upravo ubačenih). ON DELETE SET NULL nulira
    // lineItemId na garancijama vezanim za stare stavke.
    await (_db.delete(_db.lineItems)
          ..where(
              (i) => i.receiptId.equals(receiptId) & i.id.isNotIn(newIds)))
        .go();

    // Prepoji garancije sa stare stavke na njenu zamenu.
    for (final w in itemWarranties) {
      final newId = oldToNew[w.lineItemId];
      if (newId != null) {
        await (_db.update(_db.warranties)..where((x) => x.id.equals(w.id)))
            .write(WarrantiesCompanion(lineItemId: Value(newId)));
      }
    }
  }

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

  /// Ručni unos troška (bez QR/TaxCore). Kreira ili pronalazi prodavca po imenu,
  /// upisuje račun sa `isManual = true` i opcionalne stavke.
  Future<int> saveManual({
    required String merchantName,
    required int totalMinor,
    required DateTime date,
    Currency currency = Currency.rsd,
    String? paymentMethod,
    String? note,
    String? imagePath,
    List<({String name, int totalMinor})> items = const [],
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    return _db.transaction(() async {
      final merchantId = await _upsertManualMerchant(merchantName, ts);
      final receiptId = await _db.into(_db.receipts).insert(
            ReceiptsCompanion.insert(
              merchantId: merchantId,
              verificationUrl: 'manual:${ts.millisecondsSinceEpoch}',
              isManual: const Value(true),
              totalAmount: Value(totalMinor),
              currency: Value(currency),
              pfrTime: Value(date),
              paymentMethod: Value(paymentMethod),
              fetchStatus: Value(FetchStatus.complete),
              itemsStatus: Value(ItemsStatus.none),
              itemsSource: Value(ItemsSource.none),
              note: Value(note),
              imagePath: Value(imagePath),
              createdAt: Value(ts),
              updatedAt: Value(ts),
            ),
          );
      if (items.isNotEmpty) {
        await _db.batch((b) {
          for (final item in items) {
            b.insert(
              _db.lineItems,
              LineItemsCompanion.insert(
                receiptId: receiptId,
                name: item.name,
                total: Value(item.totalMinor),
                unitPrice: Value(item.totalMinor),
                source: Value(ItemsSource.none),
              ),
            );
          }
        });
      }
      return receiptId;
    });
  }

  Future<int> _upsertManualMerchant(String name, DateTime ts) async {
    final tin = 'MANUAL:${name.toLowerCase().trim()}';
    final existing = await (_db.select(_db.merchants)
          ..where((m) => m.tin.equals(tin)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return _db.into(_db.merchants).insert(
          MerchantsCompanion.insert(
            tin: tin,
            name: name,
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

  // fromSpecifications > fromJournal > pendingServer > none
  static ItemsStatus _betterItemsStatus(ItemsStatus current, ItemsStatus next) {
    const rank = {
      ItemsStatus.none: 0,
      ItemsStatus.pendingServer: 1,
      ItemsStatus.fromJournal: 2,
      ItemsStatus.fromSpecifications: 3,
    };
    return (rank[next] ?? 0) > (rank[current] ?? 0) ? next : current;
  }
}
