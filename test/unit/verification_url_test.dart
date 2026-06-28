import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/domain/country.dart';
import 'package:troskovnik/core/domain/currency.dart';
import 'package:troskovnik/features/scan/domain/verification_url.dart';
import 'package:troskovnik/features/scan/domain/vl_token.dart';

void main() {
  const v = VerificationUrlValidator();

  group('VerificationUrlValidator', () {
    test('accepts canonical suf.purs.gov.rs URL and extracts token', () {
      final r = v.validate('https://suf.purs.gov.rs/v/?vl=ABC123token');
      expect(r, isA<ValidVerificationUrl>());
      r as ValidVerificationUrl;
      expect(r.token, 'ABC123token');
    });

    test('accepts subdomain (sandbox.suf.purs.gov.rs)', () {
      final r = v.validate('https://sandbox.suf.purs.gov.rs/v/?vl=XYZ');
      expect(r, isA<ValidVerificationUrl>());
    });

    test('upgrades http to https in normalized url', () {
      final r = v.validate('http://suf.purs.gov.rs/v/?vl=T') as ValidVerificationUrl;
      expect(r.normalizedUrl, startsWith('https://'));
    });

    test('trims surrounding whitespace', () {
      final r = v.validate('  https://suf.purs.gov.rs/v/?vl=T  ');
      expect(r, isA<ValidVerificationUrl>());
    });

    test('extracts token from fragment when query is empty', () {
      final r = v.validate('https://suf.purs.gov.rs/v/#/v/?vl=FRAGTOKEN');
      expect(r, isA<ValidVerificationUrl>());
      expect((r as ValidVerificationUrl).token, 'FRAGTOKEN');
    });

    test('rejects non-url content', () {
      final r = v.validate('just some text');
      expect(r, isA<InvalidVerificationUrl>());
      expect((r as InvalidVerificationUrl).reason, InvalidReason.notaUrl);
    });

    test('rejects wrong host', () {
      final r = v.validate('https://evil.example.com/v/?vl=T');
      expect((r as InvalidVerificationUrl).reason, InvalidReason.wrongHost);
    });

    test('rejects lookalike host (suffix spoof)', () {
      final r = v.validate('https://suf.purs.gov.rs.evil.com/v/?vl=T');
      expect((r as InvalidVerificationUrl).reason, InvalidReason.wrongHost);
    });

    test('rejects missing vl token', () {
      final r = v.validate('https://suf.purs.gov.rs/v/?foo=bar');
      expect((r as InvalidVerificationUrl).reason, InvalidReason.missingToken);
    });

    test('rejects empty vl token', () {
      final r = v.validate('https://suf.purs.gov.rs/v/?vl=');
      expect((r as InvalidVerificationUrl).reason, InvalidReason.missingToken);
    });

    test('Serbian URL returns Country.serbia', () {
      final r = v.validate('https://suf.purs.gov.rs/v/?vl=T') as ValidVerificationUrl;
      expect(r.country, Country.serbia);
    });

    test('RS URL accepted and returns Country.republikaSrpska', () {
      final r = v.validate('https://suf.poreskaupravars.org/v/?vl=RSTOKEN');
      expect(r, isA<ValidVerificationUrl>());
      expect((r as ValidVerificationUrl).country, Country.republikaSrpska);
    });

    test('RS subdomain accepted', () {
      final r = v.validate('https://test.suf.poreskaupravars.org/v/?vl=T');
      expect(r, isA<ValidVerificationUrl>());
      expect((r as ValidVerificationUrl).country, Country.republikaSrpska);
    });

    test('RS lookalike host rejected', () {
      final r = v.validate('https://suf.poreskaupravars.org.evil.com/v/?vl=T');
      expect((r as InvalidVerificationUrl).reason, InvalidReason.wrongHost);
    });
  });

  group('Country → Currency mapping', () {
    test('Serbia maps to RSD', () {
      expect(Country.serbia.currency, Currency.rsd);
    });

    test('Republika Srpska maps to BAM', () {
      expect(Country.republikaSrpska.currency, Currency.bam);
    });

    test('BAM symbol is KM', () {
      expect(Currency.bam.symbol, 'KM');
    });

    test('RSD ISO code is RSD', () {
      expect(Currency.rsd.isoCode, 'RSD');
    });
  });

  group('VlTokenDecoder', () {
    const d = VlTokenDecoder();

    test('decodes base64url bytes tolerant of missing padding', () {
      // "Hello" -> base64url "SGVsbG8" (no padding)
      final bytes = d.tryDecodeBytes('SGVsbG8');
      expect(bytes, isNotNull);
      expect(String.fromCharCodes(bytes!), 'Hello');
    });

    test('never throws on garbage; returns null bytes', () {
      expect(d.tryDecodeBytes('@@@not base64@@@'), isNull);
    });

    test('decodeHeader marks fields unverified', () {
      final h = d.decodeHeader('SGVsbG8');
      expect(h.unverified, isTrue);
      expect(h.rawBytesLength, 5);
    });
  });
}
