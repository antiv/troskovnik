import 'dart:convert';
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

  group('JSON API path (Accept: application/json)', () {
    const sampleJournal = '============ ФИСКАЛНИ РАЧУН ============\n'
        '100000001\n'
        'ТЕСТ ПРОДАВНИЦА\n'
        '-------------ПРОМЕТ ПРОДАЈА-------------\n'
        'Назив   Цена         Кол.         Укупно\n'
        'Производ А (kom) (Ђ)\n'
        '  50,00   2   100,00\n'
        'Укупан износ:                     100,00\n'
        '========================================\n';

    test('isValid:true + journal → complete fromJournal', () {
      final body = '{"isValid":true,"journal":${jsonEncode(sampleJournal)},'
          '"invoiceRequest":{"taxId":"100000001","businessName":"Тест"},'
          '"invoiceResult":{"totalAmount":100.0,"invoiceNumber":"ABC-123","sdcTime":"2026-03-05T10:00:00Z"}}';
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 200,
        body: body,
        contentType: 'application/json; charset=utf-8',
      );
      final r = parser.parse(raw);
      expect(r.fetchStatus, FetchStatus.complete);
      expect(r.itemsStatus, ItemsStatus.fromJournal);
      expect(r.items, isNotEmpty);
      expect(r.journalText, sampleJournal);
    });

    test('isValid:false → FetchStatus.invalid', () {
      const body = '{"isValid":false,"journal":null}';
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 200,
        body: body,
        contentType: 'application/json',
      );
      expect(parser.parse(raw).fetchStatus, FetchStatus.invalid);
    });

    test('isValid:true + null journal → pendingServer', () {
      const body = '{"isValid":true,"journal":null}';
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 200,
        body: body,
        contentType: 'application/json',
      );
      final r = parser.parse(raw);
      expect(r.fetchStatus, FetchStatus.pending);
      expect(r.itemsStatus, ItemsStatus.pendingServer);
    });

    test('malformed JSON → pendingServer (graceful fallback)', () {
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 200,
        body: 'not json at all',
        contentType: 'application/json',
      );
      expect(parser.parse(raw).fetchStatus, FetchStatus.pending);
    });

    test('HTML content-type → uses HTML path, not JSON path', () {
      // Bez contentType → pada na HTML path → nema <pre> → pending
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.purs.gov.rs/v/?vl=X',
        statusCode: 200,
        body: '{"isValid":true,"journal":"test"}',
      );
      // JSON body ali bez JSON content-type → HTML parser → nema <pre> → pending
      final r = parser.parse(raw);
      expect(r.fetchStatus, FetchStatus.pending);
    });
  });

  group('Republika Srpska (JSON API, ijekavski žurnal)', () {
    // Realni RS račun: PIB je 13 cifara, "вријеме" (ijekavski), BAM valuta.
    const rsJournal = '============ ФИСКАЛНИ РАЧУН ============\n'
        '             4401941690008              \n'
        '    "RDT SWISSLION" d.o.o. Trebinje     \n'
        '           Draženska gora bb            \n'
        '                Trebinje                \n'
        'Касир:                    Nada Kovacevic\n'
        'ЕСИР број:                        77/4.0\n'
        '-------------ПРОМЕТ ПРОДАЈА-------------\n'
        'Артикли\n'
        '========================================\n'
        'Назив   Цијена       Кол.         Укупно\n'
        'Porodicna karta /Kom (Е)\n'
        '       100,00          1          100,00\n'
        '----------------------------------------\n'
        'Укупан износ:                     100,00\n'
        'Платна картица:                   100,00\n'
        '========================================\n'
        'Ознака       Име      Стопа        Порез\n'
        'Е             ПДВ   17,00%         14,53\n'
        '----------------------------------------\n'
        'Укупан износила пореза:               14,53\n'
        '========================================\n'
        'ПФР вријеме:         28.6.2026. 10:22:50\n'
        'ПФР број рачуна:  8FENPZP8-8FENPZP8-1973\n'
        'Бројач рачуна:               1969/1973ПП\n'
        '========================================\n'
        '======== КРАЈ ФИСКАЛНОГ РАЧУНА =========\n';

    test('RS JSON response → complete fromJournal', () {
      final body = '{"isValid":true,"journal":${jsonEncode(rsJournal)}}';
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.poreskaupravars.org/v/?vl=X',
        statusCode: 200,
        body: body,
        contentType: 'application/json; charset=utf-8',
      );
      final r = parser.parse(raw);
      expect(r.fetchStatus, FetchStatus.complete);
      expect(r.itemsStatus, ItemsStatus.fromJournal);
      expect(r.items, isNotEmpty);
    });

    test('RS header: PIB 13 cifara, ijekavsko "вријеме", pfrNumber, counter',
        () {
      final body = '{"isValid":true,"journal":${jsonEncode(rsJournal)}}';
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.poreskaupravars.org/v/?vl=X',
        statusCode: 200,
        body: body,
        contentType: 'application/json',
      );
      final r = parser.parse(raw);
      expect(r.header, isNotNull);
      expect(r.header!.merchantTin, '4401941690008');
      expect(r.header!.pfrNumber, '8FENPZP8-8FENPZP8-1973');
      expect(r.header!.invoiceCounter, '1969/1973ПП');
      expect(r.header!.pfrTime, isNotNull);
      expect(r.header!.pfrTime!.day, 28);
      expect(r.header!.pfrTime!.month, 6);
      expect(r.header!.totalAmount, 10000); // 100,00 KM = 10000 para
      expect(r.header!.transactionType, TransactionType.sale);
    });

    test('RS refund: ПРОМЕТ РЕФУНДАЦИЈЕ → TransactionType.refund', () {
      const refundJournal = '============ ФИСКАЛНИ РАЧУН ============\n'
          '             4401941690008              \n'
          'Продавница RS\n'
          'Касир:                        Test\n'
          '----------ПРОМЕТ РЕФУНДАЦИЈЕ-----------\n'
          'Артикли\n'
          'Назив   Цијена       Кол.         Укупно\n'
          'Artikal A (Е)\n'
          '       50,00          1           50,00\n'
          'Укупан износ:                      50,00\n'
          'Готовина:                          50,00\n'
          'Е             ПДВ   17,00%          7,26\n'
          'ПФР вријеме:         15.6.2026. 15:21:37\n'
          'ПФР број рачуна:  AAAAAAAA-AAAAAAAA-1000\n'
          'Бројач рачуна:                1000/1001ПП\n';
      final body = '{"isValid":true,"journal":${jsonEncode(refundJournal)}}';
      final raw = RawPortalResponse(
        verificationUrl: 'https://suf.poreskaupravars.org/v/?vl=X',
        statusCode: 200,
        body: body,
        contentType: 'application/json',
      );
      final r = parser.parse(raw);
      expect(r.header!.transactionType, TransactionType.refund);
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
