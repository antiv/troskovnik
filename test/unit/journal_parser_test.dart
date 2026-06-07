import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/core/db/enums.dart';
import 'package:troskovnik/features/source/data/journal_header_parser.dart';
import 'package:troskovnik/features/source/data/journal_item_parser.dart';

void main() {
  final journal =
      File('test/fixtures/complete.journal.anon.txt').readAsStringSync();

  group('JournalHeaderParser', () {
    const parser = JournalHeaderParser();

    test('extracts tin, total, payment, pfr time/number, counter', () {
      final h = parser.parse(journal);
      expect(h.merchantTin, '100000001');
      expect(h.totalAmount, 53000); // 530,00 RSD u para
      expect(h.paymentMethod, 'Готовина');
      expect(h.pfrNumber, 'TESTTEST-TESTTEST-00001');
      expect(h.invoiceCounter, '00001/00001ПП');
      expect(h.transactionType, TransactionType.sale);
      expect(h.pfrTime, DateTime(2026, 6, 2, 8, 36, 49));
      expect(h.merchantName, isNotEmpty);
    });

    test('single payment: paymentsJson holds method+amount', () {
      final h = parser.parse(journal);
      expect(h.paymentMethod, 'Готовина');
      final map = jsonDecode(h.paymentsJson!) as Map<String, dynamic>;
      expect(map, {'Готовина': 53000});
    });

    test('combined payment: all methods with amounts captured', () {
      const combinedJournal = '''
============ ФИСКАЛНИ РАЧУН ============
               100000001
        PRODAVNICA DOO
-------------ПРОМЕТ ПРОДАЈА-------------
========================================
Укупан износ:                     530,00
Готовина:                         200,00
Картица:                          330,00
========================================
ПФР време:           02.06.2026. 8:36:49
ПФР број рачуна: TESTTEST-TESTTEST-00001
Бројач рачуна:             00001/00001ПП
========================================
''';
      final h = parser.parse(combinedJournal);
      // Prvi/primarni način ostaje radi kompatibilnosti.
      expect(h.paymentMethod, 'Готовина');
      final map = jsonDecode(h.paymentsJson!) as Map<String, dynamic>;
      expect(map, {'Готовина': 20000, 'Картица': 33000});
    });

    test('en-US number format + Платна картица payment', () {
      const usJournal = '''
============ ФИСКАЛНИ РАЧУН ============
               100000001
        PRODAVNICA DOO
-------------ПРОМЕТ ПРОДАЈА-------------
Артикли
========================================
Назив   Цена         Кол.         Укупно
Banana /KG (Е)
       189.99          1.21          229.89
Usluga dostave /KOM (Ђ)
       199.00          1          199.00
----------------------------------------
Укупан износ:                   4,600.74
Платна картица:                 4,600.74
========================================
Ознака       Име      Стопа        Порез
Е           П-ПДВ   10.00%         159.76
Ђ           О-ПДВ   20.00%         473.90
----------------------------------------
Укупан износ пореза:               633.66
========================================
ПФР време:           04.06.2026. 01:10:23
ПФР број рачуна: 8JS84EVT-8JS84EVT-188792
Бројач рачуна:             183155/188792ПП
========================================
''';
      final h = parser.parse(usJournal);
      expect(h.totalAmount, 460074); // 4.600,74 RSD u para
      expect(h.paymentMethod, 'Платна картица');
      final pay = jsonDecode(h.paymentsJson!) as Map<String, dynamic>;
      expect(pay, {'Платна картица': 460074});
      // Poreske stope iz en-US formata.
      final rates = parser.parseTaxRates(usJournal);
      expect(rates['Е'], 10.0);
      expect(rates['Ђ'], 20.0);

      // Stavke iz en-US žurnala.
      final items = const JournalItemParser().parse(usJournal, taxRatesByLabel: rates);
      final banana = items.firstWhere((it) => it.name.contains('Banana'));
      expect(banana.quantity, closeTo(1.21, 0.001));
      expect(banana.total, 22989); // 229,89
      expect(banana.unitPrice, 18999); // 189,99
    });

    test('all 7 official payment methods are recognized', () {
      String journalWith(String paymentLine) => '''
============ ФИСКАЛНИ РАЧУН ============
               100000001
        PRODAVNICA DOO
-------------ПРОМЕТ ПРОДАЈА-------------
========================================
Укупан износ:                     100,00
$paymentLine
========================================
ПФР време:           02.06.2026. 8:36:49
ПФР број рачуна: T-T-1
Бројач рачуна:             1/1ПП
========================================
''';
      // Zvanični nazivi (Pravilnik, član 6) kako stoje u žurnalu (ćirilica).
      final methods = <String, String>{
        'Готовина': 'Готовина:                         100,00',
        'Платна картица': 'Платна картица:                   100,00',
        'Чек': 'Чек:                              100,00',
        'Пренос на рачун': 'Пренос на рачун:                  100,00',
        'Ваучер': 'Ваучер:                           100,00',
        'Инстант плаћање': 'Инстант плаћање:                  100,00',
        'Друго безготовинско плаћање':
            'Друго безготовинско плаћање:      100,00',
      };
      methods.forEach((expected, line) {
        final h = parser.parse(journalWith(line));
        expect(h.paymentMethod, expected, reason: 'naziv: $expected');
        final map = jsonDecode(h.paymentsJson!) as Map<String, dynamic>;
        expect(map[expected], 10000, reason: 'iznos za: $expected');
      });
    });

    test('B2C fixture has no buyer id', () {
      final h = parser.parse(journal);
      expect(h.buyerId, isNull);
    });

    test('extracts buyer id (ИД купца) and keeps it out of merchant fields',
        () {
      const b2bJournal = '''
============ ФИСКАЛНИ РАЧУН ============
               100833134
        OLIVA 1286772-Restoran OLIVA
        "Омладинских бригада 86ј" 3"
          БЕОГРАД (НОВИ БЕОГРАД)
ИД купца:                    10:104318304
Касир:                          Milica
ЕСИР број:                       1060/1.2
-------------ПРОМЕТ ПРОДАЈА-------------
========================================
Укупан износ:                  31.520,00
Пренос на рачун:               31.520,00
========================================
ПФР време:          04.06.2026. 14:52:31
ПФР број рачуна: 28AEXETL-28AEXETL-46977
Бројач рачуна:             46929/46977ПП
========================================
''';
      final h = parser.parse(b2bJournal);
      expect(h.merchantTin, '100833134');
      expect(h.buyerId, '10:104318304');
      // PIB kupca ne sme da iscuri u naziv/adresu/lokaciju prodavca.
      expect(h.merchantName, isNot(contains('купца')));
      expect(h.address ?? '', isNot(contains('купца')));
      expect(h.locationName ?? '', isNot(contains('купца')));
    });

    test('maps tax labels to rates', () {
      final rates = parser.parseTaxRates(journal);
      expect(rates['Ђ'], 20.0);
      expect(rates['Е'], 10.0);
    });
  });

  group('JournalItemParser', () {
    const parser = JournalItemParser();

    test('parses all four items with name, qty, prices, tax label', () {
      final rates = const JournalHeaderParser().parseTaxRates(journal);
      final items = parser.parse(journal, taxRatesByLabel: rates);

      expect(items, hasLength(4));

      final cola = items.firstWhere((i) => i.name.contains('Coca Cola'));
      expect(cola.unitPrice, 13000); // 130,00
      expect(cola.quantity, 1.0);
      expect(cola.total, 13000);
      expect(cola.taxLabel, 'Ђ');
      expect(cola.taxRate, 20.0);
      expect(cola.unit, 'kom');
      expect(cola.source, ItemsSource.journal);

      final kiflice = items.firstWhere((i) => i.name.contains('Kiflica'));
      expect(kiflice.quantity, 3.0);
      expect(kiflice.unitPrice, 6000); // 60,00
      expect(kiflice.total, 18000); // 180,00
      expect(kiflice.taxLabel, 'Е');
      expect(kiflice.taxRate, 10.0);
    });

    test('item totals sum to receipt total', () {
      final items = parser.parse(journal);
      final sum = items.fold<int>(0, (a, i) => a + i.total);
      expect(sum, 53000);
    });

    test('no unparsed rows for clean fixture', () {
      final items = parser.parse(journal);
      expect(items.any((i) => i.isUnparsed), isFalse);
    });
  });
}
