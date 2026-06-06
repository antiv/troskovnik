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
