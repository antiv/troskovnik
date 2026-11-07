import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/domain/buyer_identity.dart';
import 'package:troskovnik/core/domain/country.dart';

void main() {
  BuyerIdentity? parse(String? raw, [Country c = Country.serbia]) =>
      BuyerIdentity.parse(raw, c);

  group('Srbija (TaxCore)', () {
    test('10: PIB firme je poslovni', () {
      final b = parse('10:104318304')!;
      expect(b.kind, BuyerKind.company);
      expect(b.isBusiness, isTrue);
      expect(b.taxId, '104318304');
      expect(b.label(Country.serbia), 'PIB');
    });

    test('12: PIB + JBKJS daje isti PIB kao ključ', () {
      final b = parse('12:104318304:12345')!;
      expect(b.isBusiness, isTrue);
      expect(b.taxId, '104318304');
    });

    test('11: JMBG nije poslovni i maskira se', () {
      final b = parse('11:0101990800000')!;
      expect(b.kind, BuyerKind.person);
      expect(b.isBusiness, isFalse);
      expect(b.taxId, isNull);
      expect(b.maskedNumber, '•••••••••0000');
      expect(b.label(Country.serbia), 'JMBG');
    });

    test('20: lični dokument nije poslovni', () {
      final b = parse('20:123456789')!;
      expect(b.kind, BuyerKind.document);
      expect(b.isBusiness, isFalse);
    });

    test('40: strani poreski broj je poslovni', () {
      final b = parse('40:DE123456789')!;
      expect(b.kind, BuyerKind.foreignCompany);
      expect(b.taxId, 'DE123456789');
    });

    test('null, prazno i nepoznat format', () {
      expect(parse(null), isNull);
      expect(parse('  '), isNull);
      expect(parse('nešto')!.isBusiness, isFalse);
    });
  });

  group('Republika Srpska', () {
    test('JIB pravnog lica (13 cifara, počinje sa 4) je poslovni', () {
      final b = parse('10:4400000000001', Country.republikaSrpska)!;
      expect(b.isBusiness, isTrue);
      expect(b.taxId, '4400000000001');
      expect(b.label(Country.republikaSrpska), 'JIB');
    });

    test('JMB pod kodom 10 nije poslovni', () {
      final b = parse('10:0101990100005', Country.republikaSrpska)!;
      expect(b.kind, BuyerKind.person);
      expect(b.isBusiness, isFalse);
    });
  });

  group('Crna Gora (EFI)', () {
    test('TIN je poslovni', () {
      final b = parse('TIN:02345678', Country.montenegro)!;
      expect(b.isBusiness, isTrue);
      expect(b.taxId, '02345678');
    });

    test('ID (lični broj) nije poslovni', () {
      final b = parse('ID:0101990210005', Country.montenegro)!;
      expect(b.kind, BuyerKind.person);
      expect(b.isBusiness, isFalse);
    });
  });
}
