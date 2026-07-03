import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/database.dart';
import 'package:troskovnik/core/domain/currency.dart';
import 'package:troskovnik/features/receipts/data/receipt_repository.dart';
import 'package:troskovnik/features/scan/domain/ips_qr.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
  });
  tearDown(() => db.close());

  group('saveIps', () {
    const raw = 'K:PR|V:01|C:1|R:845000000040484987|N:JP EPS BEOGRAD\n'
        'BALKANSKA 13|I:RSD3596,13|P:PERA|SF:189|'
        'S:UPLATA PO RAČUNU ZA EL. ENERGIJU|RO:97163220000111111111000';

    test('IPS nalog se čuva kao ručni račun', () async {
      final data = IpsQrParser.tryParse(raw)!;
      final id = await repo.saveIps(data);

      final r = await repo.findById(id);
      expect(r, isNotNull);
      expect(r!.isManual, isTrue);
      expect(r.totalAmount, 359613);
      expect(r.currency, Currency.rsd);
      expect(r.paymentMethod, 'Prenos');
      expect(r.note, contains('UPLATA PO RAČUNU ZA EL. ENERGIJU'));
      expect(r.note, contains('845000000040484987'));
      expect(r.note, contains('97163220000111111111000'));

      final merchant = await (db.select(db.merchants)
            ..where((m) => m.id.equals(r.merchantId)))
          .getSingle();
      expect(merchant.name, 'JP EPS BEOGRAD');

      final items = await repo.itemsFor(id);
      expect(items, hasLength(1));
      expect(items.single.name, 'UPLATA PO RAČUNU ZA EL. ENERGIJU');
      expect(items.single.total, 359613);
    });

    test('bez svrhe: naziv stavke pada na naziv primaoca', () async {
      final data =
          IpsQrParser.tryParse('K:PR|V:01|C:1|R:123|N:Firma|I:RSD10,00')!;
      final id = await repo.saveIps(data);
      final items = await repo.itemsFor(id);
      expect(items.single.name, 'Firma');
    });
  });

  group('updateManual', () {
    test('menja polja i zamenjuje stavke', () async {
      final id = await repo.saveManual(
        merchantName: 'Stari',
        totalMinor: 10000,
        date: DateTime(2026, 1, 1),
        items: const [(name: 'A', totalMinor: 10000)],
      );

      await repo.updateManual(
        receiptId: id,
        merchantName: 'Novi',
        totalMinor: 25050,
        date: DateTime(2026, 2, 2),
        currency: Currency.eur,
        paymentMethod: 'Kartica',
        note: 'beleska',
        items: const [
          (name: 'B', totalMinor: 20000),
          (name: 'C', totalMinor: 5050),
        ],
      );

      final r = await repo.findById(id);
      expect(r!.totalAmount, 25050);
      expect(r.currency, Currency.eur);
      expect(r.paymentMethod, 'Kartica');
      expect(r.note, 'beleska');
      expect(r.pfrTime, DateTime(2026, 2, 2));

      final merchant = await (db.select(db.merchants)
            ..where((m) => m.id.equals(r.merchantId)))
          .getSingle();
      expect(merchant.name, 'Novi');

      final items = await repo.itemsFor(id);
      expect(items.map((i) => i.name).toSet(), {'B', 'C'});
    });

    test('čuva dodeljenu kategoriju istoimene stavke', () async {
      final id = await repo.saveManual(
        merchantName: 'Prodavac',
        totalMinor: 10000,
        date: DateTime(2026, 1, 1),
        items: const [(name: 'Kafa', totalMinor: 10000)],
      );
      final catId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Piće'));
      final item = (await repo.itemsFor(id)).single;
      await (db.update(db.lineItems)..where((i) => i.id.equals(item.id)))
          .write(LineItemsCompanion(categoryId: Value(catId)));

      await repo.updateManual(
        receiptId: id,
        merchantName: 'Prodavac',
        totalMinor: 12000,
        date: DateTime(2026, 1, 1),
        items: const [(name: 'Kafa', totalMinor: 12000)],
      );

      final updated = (await repo.itemsFor(id)).single;
      expect(updated.total, 12000);
      expect(updated.categoryId, catId);
    });
  });
}
