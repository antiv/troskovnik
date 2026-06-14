import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/db/providers.dart';
import '../domain/export_range.dart';
import 'csv_exporter.dart';

/// Rezultat izvoza: putanja do CSV fajla + broj redova (stavki) u izvozu.
class ExportResult {
  const ExportResult({required this.filePath, required this.rowCount});
  final String filePath;
  final int rowCount;
}

/// Sastavlja CSV izvoz računa (red po stavci) za izabrani period i upisuje ga
/// u privremeni fajl spreman za deljenje.
class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  static final _fileStamp = DateFormat('yyyyMMdd');

  /// Vrati CSV tekst za period, ili `null` ako nema računa.
  Future<String?> buildCsv(
    ExportRange range, {
    DateTime? now,
    DateTime? customFrom,
    DateTime? customTo,
  }) async {
    final b = exportRangeBounds(range,
        now: now ?? DateTime.now(),
        customFrom: customFrom,
        customTo: customTo);

    final r = _db.receipts;
    final m = _db.merchants;
    final notInvalid = r.fetchStatus.equalsValue(FetchStatus.invalid).not();
    // U periodu po pfr_time, ili (nema pfr_time) po created_at.
    final inPeriod = (r.pfrTime.isBiggerOrEqualValue(b.from) &
            r.pfrTime.isSmallerThanValue(b.to)) |
        (r.pfrTime.isNull() &
            r.createdAt.isBiggerOrEqualValue(b.from) &
            r.createdAt.isSmallerThanValue(b.to));

    final query = _db.select(r).join([
      innerJoin(m, m.id.equalsExp(r.merchantId)),
    ])
      ..where(notInvalid & inPeriod)
      ..orderBy([
        OrderingTerm(expression: r.pfrTime),
        OrderingTerm(expression: r.createdAt),
      ]);

    final joined = await query.get();
    if (joined.isEmpty) return null;

    final receipts = [for (final row in joined) row.readTable(r)];
    final merchantsById = {
      for (final row in joined) row.readTable(r).id: row.readTable(m),
    };

    // Sve stavke za te račune jednim upitom, grupisane po receiptId.
    final ids = receipts.map((e) => e.id).toList();
    final items = await (_db.select(_db.lineItems)
          ..where((li) => li.receiptId.isIn(ids)))
        .get();
    final itemsByReceipt = <int, List<LineItemRow>>{};
    for (final it in items) {
      (itemsByReceipt[it.receiptId] ??= []).add(it);
    }

    // Nazivi kategorija po id-u (za kolonu kategorija u izvozu).
    final categories = await _db.select(_db.categories).get();
    final categoryNameById = {for (final c in categories) c.id: c.name};

    final rows = <List<String>>[];
    for (final rec in receipts) {
      final merchant = merchantsById[rec.id];
      final base = _receiptCells(rec, merchant);
      final recItems = itemsByReceipt[rec.id] ?? const [];
      if (recItems.isEmpty) {
        // Račun bez stavki: jedan red sa praznim kolonama stavke
        // (artikal, kategorija, kolicina, jedinica, jedinicna_cena,
        // ukupno_stavka, poreska_oznaka, poreska_stopa = 8 praznih).
        rows.add([
          ...base,
          '', '', '', '', '', '', '', '',
          _money(rec.totalAmount),
          rec.verificationUrl,
        ]);
      } else {
        for (final it in recItems) {
          rows.add([
            ...base,
            it.name,
            it.categoryId == null ? '' : categoryNameById[it.categoryId] ?? '',
            _qty(it.quantity),
            it.unit ?? '',
            _money(it.unitPrice),
            _money(it.total),
            it.taxLabel ?? '',
            it.taxRate?.toString() ?? '',
            _money(rec.totalAmount),
            rec.verificationUrl,
          ]);
        }
      }
    }

    return CsvExporter.encodeCsv(CsvExporter.header, rows);
  }

  /// Sastavi CSV i upiši ga u privremeni fajl; vrati [ExportResult] ili `null`.
  Future<ExportResult?> exportToFile(
    ExportRange range, {
    DateTime? now,
    DateTime? customFrom,
    DateTime? customTo,
  }) async {
    final csv = await buildCsv(range,
        now: now, customFrom: customFrom, customTo: customTo);
    if (csv == null) return null;

    final b = exportRangeBounds(range,
        now: now ?? DateTime.now(),
        customFrom: customFrom,
        customTo: customTo);
    // Gornja granica je ekskluzivna (početak narednog dana) → -1 dan za naziv.
    final lastDay = b.to.subtract(const Duration(days: 1));
    final name =
        'troskovnik-${_fileStamp.format(b.from)}-${_fileStamp.format(lastDay)}.csv';

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(csv); // UTF-8 podrazumevano, bez BOM.

    // Svaki red (uklj. zaglavlje) završava sa '\n'; oduzmi zaglavlje.
    final rowCount = '\n'.allMatches(csv).length - 1;
    return ExportResult(filePath: file.path, rowCount: rowCount);
  }

  List<String> _receiptCells(ReceiptRow rec, MerchantRow? merchant) => [
        CsvExporter.date(rec.pfrTime ?? rec.createdAt),
        merchant?.name ?? '',
        merchant?.tin ?? '',
        rec.buyerId ?? '',
        rec.isBusiness ? 'da' : 'ne',
        rec.pfrNumber ?? '',
        rec.invoiceCounter ?? '',
        rec.transactionType == TransactionType.refund ? 'refundacija' : 'prodaja',
        rec.paymentMethod ?? '',
      ];

  static String _money(int minor) => CsvExporter.money(minor);

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

/// Servis za izvoz — dostupan kad se baza otvori.
final exportServiceProvider = FutureProvider<ExportService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ExportService(db);
});
