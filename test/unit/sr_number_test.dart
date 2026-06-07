import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/utils/sr_number.dart';

void main() {
  group('SrNumber.tryParse', () {
    test('serbian format (dot thousands, comma decimal)', () {
      expect(SrNumber.tryParse('530,00'), 530.0);
      expect(SrNumber.tryParse('1.234,56'), 1234.56);
      expect(SrNumber.tryParse('31.520,00'), 31520.0);
      expect(SrNumber.tryParse('0,578'), 0.578);
    });

    test('en-US format (comma thousands, dot decimal)', () {
      expect(SrNumber.tryParse('966.99'), 966.99);
      expect(SrNumber.tryParse('1,499.99'), 1499.99);
      expect(SrNumber.tryParse('4,600.74'), 4600.74);
      expect(SrNumber.tryParse('0.578'), 0.578);
    });

    test('integers and edge cases', () {
      expect(SrNumber.tryParse('1'), 1.0);
      expect(SrNumber.tryParse(''), isNull);
      expect(SrNumber.tryParse('abc'), isNull);
    });

    test('tryParseToMinor rounds to para', () {
      expect(SrNumber.tryParseToMinor('530,00'), 53000);
      expect(SrNumber.tryParseToMinor('4,600.74'), 460074);
      expect(SrNumber.tryParseToMinor('966.99'), 96699);
    });
  });
}
