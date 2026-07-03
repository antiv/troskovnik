import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/domain/currency.dart';
import 'package:troskovnik/features/scan/domain/ips_qr.dart';

void main() {
  group('IpsQrParser.tryParse', () {
    test('parsira realan EPS nalog (višelinijski N i P)', () {
      const raw = 'K:PR|V:01|C:1|R:845000000040484987|N:JP EPS BEOGRAD\n'
          'BALKANSKA 13|I:RSD3596,13|P:MRĐO MAČKATOVIĆ\n'
          'ŽUPSKA 13\n'
          'BEOGRAD 6|SF:189|S:UPLATA PO RAČUNU ZA EL. ENERGIJU|'
          'RO:97163220000111111111000';

      final data = IpsQrParser.tryParse(raw);
      expect(data, isNotNull);
      expect(data!.recipientAccount, '845000000040484987');
      expect(data.recipientName, 'JP EPS BEOGRAD\nBALKANSKA 13');
      expect(data.recipientFirstLine, 'JP EPS BEOGRAD');
      expect(data.currency, Currency.rsd);
      expect(data.amountMinor, 359613);
      expect(data.payerName, startsWith('MRĐO MAČKATOVIĆ'));
      expect(data.purpose, 'UPLATA PO RAČUNU ZA EL. ENERGIJU');
      expect(data.paymentCode, '189');
      expect(data.referenceNumber, '97163220000111111111000');
    });

    test('samo obavezna polja (bez P/SF/S/RO)', () {
      const raw = 'K:PR|V:01|C:1|R:845000000040484987|N:JP EPS|I:RSD100,00';
      final data = IpsQrParser.tryParse(raw);
      expect(data, isNotNull);
      expect(data!.amountMinor, 10000);
      expect(data.payerName, isNull);
      expect(data.purpose, isNull);
      expect(data.paymentCode, isNull);
      expect(data.referenceNumber, isNull);
    });

    test('iznos u en-US formatu takođe radi (tačka kao decimala)', () {
      const raw = 'K:PR|V:01|C:1|R:123|N:Firma|I:RSD1234.56';
      final data = IpsQrParser.tryParse(raw);
      expect(data!.amountMinor, 123456);
    });

    test('iznos sa hiljadama', () {
      const raw = 'K:PR|V:01|C:1|R:123|N:Firma|I:RSD1.234,56';
      final data = IpsQrParser.tryParse(raw);
      expect(data!.amountMinor, 123456);
    });

    test('nepoznata valuta pada na RSD', () {
      const raw = 'K:PR|V:01|C:1|R:123|N:Firma|I:XXX10,00';
      final data = IpsQrParser.tryParse(raw);
      expect(data!.currency, Currency.rsd);
      expect(data.amountMinor, 1000);
    });

    test('EUR se prepoznaje', () {
      const raw = 'K:PR|V:01|C:1|R:123|N:Firma|I:EUR10,00';
      final data = IpsQrParser.tryParse(raw);
      expect(data!.currency, Currency.eur);
    });

    test('fiskalni URL nije IPS → null', () {
      expect(
          IpsQrParser.tryParse('https://suf.purs.gov.rs/v/?vl=ABC'), isNull);
    });

    test('nedostaje obavezno polje (R) → null', () {
      expect(
          IpsQrParser.tryParse('K:PR|V:01|C:1|N:Firma|I:RSD10,00'), isNull);
    });

    test('pogrešan tip koda (K != PR) → null', () {
      expect(
          IpsQrParser.tryParse('K:XX|V:01|C:1|R:123|N:Firma|I:RSD10,00'),
          isNull);
    });

    test('nečitljiv iznos → null', () {
      expect(
          IpsQrParser.tryParse('K:PR|V:01|C:1|R:123|N:Firma|I:RSDabc'),
          isNull);
    });

    test('prazan string → null', () {
      expect(IpsQrParser.tryParse('   '), isNull);
    });
  });
}
