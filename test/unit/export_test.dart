import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/features/export/data/csv_exporter.dart';
import 'package:troskovnik/features/export/data/export_service.dart';
import 'package:troskovnik/features/export/domain/export_range.dart';

void main() {
  group('CsvExporter', () {
    test('quotes cells with delimiter, quotes and newlines', () {
      final csv = CsvExporter.encodeCsv(
        ['a', 'b'],
        [
          ['x,y', 'he said "hi"'],
          ['line1\nline2', 'z'],
        ],
      );
      final lines = csv.trimRight().split('\n');
      expect(lines[0], 'a,b');
      expect(lines[1], '"x,y","he said ""hi"""');
      // Ćelija sa novim redom je pod navodnicima (pa se prelama na dva fizička reda).
      expect(csv, contains('"line1\nline2",z'));
    });

    test('money formats minor units with dot decimal', () {
      expect(CsvExporter.money(53000), '530.00');
      expect(CsvExporter.money(3152000), '31520.00');
      expect(CsvExporter.money(0), '0.00');
    });
  });

  group('exportRangeBounds', () {
    test('current month', () {
      final b = exportRangeBounds(ExportRange.currentMonth,
          now: DateTime(2026, 6, 15, 10));
      expect(b.from, DateTime(2026, 6, 1));
      expect(b.to, DateTime(2026, 7, 1));
    });

    test('previous month handles year rollover', () {
      final b = exportRangeBounds(ExportRange.previousMonth,
          now: DateTime(2026, 1, 10));
      expect(b.from, DateTime(2025, 12, 1));
      expect(b.to, DateTime(2026, 1, 1));
    });

    test('custom is inclusive of end day', () {
      final b = exportRangeBounds(ExportRange.custom,
          now: DateTime(2026, 6, 1),
          customFrom: DateTime(2026, 3, 5),
          customTo: DateTime(2026, 3, 10));
      expect(b.from, DateTime(2026, 3, 5));
      expect(b.to, DateTime(2026, 3, 11));
    });
  });

  group('ExportService.buildCsv', () {
    late AppDatabase db;
    late ExportService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = ExportService(db);
    });
    tearDown(() => db.close());

    Future<int> merchant(String tin, String name) =>
        db.into(db.merchants).insert(
              MerchantsCompanion.insert(tin: tin, name: name),
            );

    Future<int> receipt({
      required int merchantId,
      required int total,
      required DateTime pfrTime,
      bool business = false,
      FetchStatus status = FetchStatus.complete,
      String? pfr,
    }) =>
        db.into(db.receipts).insert(
              ReceiptsCompanion.insert(
                merchantId: merchantId,
                verificationUrl: 'u${DateTime.now().microsecondsSinceEpoch}',
                pfrNumber: Value(pfr),
                pfrTime: Value(pfrTime),
                totalAmount: Value(total),
                isBusiness: Value(business),
                fetchStatus: Value(status),
              ),
            );

    Future<void> item(int receiptId, String name, int total,
            {int unitPrice = 0, double qty = 1.0}) =>
        db.into(db.lineItems).insert(
              LineItemsCompanion.insert(
                receiptId: receiptId,
                name: name,
                quantity: Value(qty),
                unitPrice: Value(unitPrice),
                total: Value(total),
              ),
            );

    List<String> dataLines(String csv) =>
        csv.trimRight().split('\n').skip(1).toList();

    test('one row per item; receipt fields repeated', () async {
      final m = await merchant('100', 'Maxi');
      final r = await receipt(
          merchantId: m, total: 30000, pfrTime: DateTime(2026, 6, 10), business: true);
      await item(r, 'Mleko', 10000, unitPrice: 10000);
      await item(r, 'Hleb', 20000, unitPrice: 10000, qty: 2);

      final csv = await service.buildCsv(ExportRange.currentMonth,
          now: DateTime(2026, 6, 15));
      expect(csv, isNotNull);
      final lines = dataLines(csv!);
      expect(lines, hasLength(2));
      expect(lines.every((l) => l.contains('Maxi')), isTrue);
      expect(lines.any((l) => l.contains('Mleko')), isTrue);
      expect(lines.any((l) => l.contains('Hleb')), isTrue);
      expect(lines.every((l) => l.contains('da')), isTrue); // poslovni
    });

    test('receipt without items yields one row with blank item cells',
        () async {
      final m = await merchant('100', 'Maxi');
      await receipt(
          merchantId: m,
          total: 5000,
          pfrTime: DateTime(2026, 6, 10),
          status: FetchStatus.headerOnly);

      final csv = await service.buildCsv(ExportRange.currentMonth,
          now: DateTime(2026, 6, 15));
      final lines = dataLines(csv!);
      expect(lines, hasLength(1));
      // 19 kolona; kolone stavke (9..16, uklj. kategorija) prazne, iznos popunjen.
      final cells = lines.first.split(',');
      expect(cells, hasLength(19));
      expect(cells.sublist(9, 17), everyElement(''));
      expect(cells[17], '50.00'); // iznos_racuna
    });

    test('excludes invalid receipts and out-of-range', () async {
      final m = await merchant('100', 'Maxi');
      await receipt(
          merchantId: m,
          total: 1000,
          pfrTime: DateTime(2026, 6, 10),
          status: FetchStatus.invalid);
      await receipt(
          merchantId: m, total: 2000, pfrTime: DateTime(2026, 5, 10)); // prošli mesec

      final csv = await service.buildCsv(ExportRange.currentMonth,
          now: DateTime(2026, 6, 15));
      expect(csv, isNull); // ništa validno u tekućem mesecu
    });

    test('previous month export picks only prior month receipts', () async {
      final m = await merchant('100', 'Maxi');
      final rMay = await receipt(
          merchantId: m, total: 2000, pfrTime: DateTime(2026, 5, 10));
      await item(rMay, 'Maj artikal', 2000);
      final rJun = await receipt(
          merchantId: m, total: 3000, pfrTime: DateTime(2026, 6, 10));
      await item(rJun, 'Jun artikal', 3000);

      final csv = await service.buildCsv(ExportRange.previousMonth,
          now: DateTime(2026, 6, 15));
      final lines = dataLines(csv!);
      expect(lines, hasLength(1));
      expect(lines.first, contains('Maj artikal'));
    });
  });
}
