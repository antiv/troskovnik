import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/features/source/data/specifications_parser.dart';
import 'package:troskovnik/features/source/data/taxcore_parser.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';

void main() {
  const parser = TaxCoreParser();

  group('SpecificationsParser', () {
    const sp = SpecificationsParser();

    test('parses success JSON into items (amounts -> para)', () {
      const body = '{"success":true,"items":[{"name":"Mleko",'
          '"quantity":2,"unitPrice":99.0,"total":198.0,"label":"Ђ",'
          '"labelRate":20.0}]}';
      final items = sp.tryParse(body);
      expect(items, hasLength(1));
      expect(items!.first.unitPrice, 9900);
      expect(items.first.total, 19800);
      expect(items.first.taxLabel, 'Ђ');
      expect(items.first.taxRate, 20.0);
      expect(items.first.source, ItemsSource.specifications);
    });

    test('returns null on {success:false}', () {
      expect(sp.tryParse('{"success":false}'), isNull);
    });

    test('returns null on empty/garbage', () {
      expect(sp.tryParse(null), isNull);
      expect(sp.tryParse(''), isNull);
      expect(sp.tryParse('not json'), isNull);
    });
  });

  group('TaxCoreParser pipeline', () {
    test('extracts journal from <pre> and removes embedded image', () {
      const htmlBody =
          '<html><body><pre>line1<br/>line2<img src="data:image/gif;base64,AAAA"></pre></body></html>';
      final journal = parser.extractJournal(htmlBody);
      expect(journal, contains('line1'));
      expect(journal, contains('line2'));
      expect(journal, isNot(contains('base64')));
    });

    test('invalid page -> FetchStatus.invalid', () {
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 404,
        body: '',
      );
      expect(parser.parse(raw).fetchStatus, FetchStatus.invalid);
    });

    test('page without <pre> -> pendingServer', () {
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 200,
        body: '<html><body>no journal here</body></html>',
      );
      final r = parser.parse(raw);
      expect(r.fetchStatus, FetchStatus.pending);
      expect(r.itemsStatus, ItemsStatus.pendingServer);
    });

    test('specifications win over journal when present', () {
      const specs =
          '{"success":true,"items":[{"name":"X","quantity":1,"unitPrice":1.0,"total":1.0,"label":"Ђ"}]}';
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 200,
        body: '<pre>============ ФИСКАЛНИ РАЧУН ============\n'
            '100000001\nПРОДАВНИЦА\n'
            '-------------ПРОМЕТ ПРОДАЈА-------------\n'
            'Назив   Цена         Кол.         Укупно\n'
            'A (kom) (Ђ)\n  10,00   1   10,00\n'
            'Укупан износ:                      10,00</pre>',
        specificationsBody: specs,
      );
      final r = parser.parse(raw);
      expect(r.itemsStatus, ItemsStatus.fromSpecifications);
      expect(r.items, hasLength(1));
      expect(r.items.first.name, 'X');
    });
  });

  group('full real page (local fixture, not committed)', () {
    final pageFile = File('test/fixtures/complete.page.html');

    test('parses captured page into journal-sourced receipt', () {
      if (!pageFile.existsSync()) {
        markTestSkipped('no local complete.page.html (capture first)');
        return;
      }
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 200,
        body: pageFile.readAsStringSync(),
        specificationsBody: '{"success":false}',
      );
      final r = parser.parse(raw);
      expect(r.fetchStatus, FetchStatus.complete);
      expect(r.itemsStatus, ItemsStatus.fromJournal);
      expect(r.items, hasLength(4));
      expect(r.header, isNotNull);
      expect(r.header!.totalAmount, 53000);
    });
  });
}
