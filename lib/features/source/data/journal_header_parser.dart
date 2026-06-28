import 'dart:convert';

import '../../../core/db/enums.dart';
import '../../../core/utils/sr_number.dart';
import '../domain/receipt_source.dart';
import 'journal_item_parser.dart';

/// Parsira zaglavlje + obračun poreza iz PFR žurnala (sekcija 6).
///
/// Format potvrđen nad realnim računom (test/fixtures/complete.journal.anon.txt).
class JournalHeaderParser {
  const JournalHeaderParser();

  // RS PIB je 13 cifara, srpski 9 (ili 8 za stare); oba oblika prihvatamo.
  static final _pibLine = RegExp(r'^\s*(\d{8,13})\s*$');
  // ИД купца (PIB/ID kupca): npr. "ИД купца:        10:104318304".
  // Grupa 1 = tip ("10" = PIB firme), grupa 2 = broj.
  static final _buyerId =
      RegExp(r'ИД\s+купца\s*:?\s*(\d{1,2})\s*:\s*(\d{6,})', unicode: true);
  static final _cashier = RegExp(r'Касир\s*:?\s*(.*)$', unicode: true);
  static final _esir = RegExp(r'ЕСИР\s+број\s*:?\s*(.*)$', unicode: true);
  static final _pfrTime =
      RegExp(r'ПФР\s+вр(?:иј)?еме\s*:?\s*(.+)$', unicode: true);
  static final _pfrNumber =
      RegExp(r'ПФР\s+број\s+рачуна\s*:?\s*(\S+)', unicode: true);
  static final _counter =
      RegExp(r'Бројач\s+рачуна\s*:?\s*(\S+)', unicode: true);
  static final _totalAmount = RegExp(
        r'(Укупан\s+износ|Укупна\s+рефундација)\s*:?\s*([\d][\d.,]*)',
        unicode: true,
      );
  static final _saleType = RegExp(r'ПРОМЕТ\s+ПРОДАЈА', unicode: true);
  static final _refundType = RegExp(r'ПРОМЕТ\s+РЕФУНДАЦИЈ', unicode: true);

  // Red obračuna poreza: "Ђ  О-ПДВ  20,00%  21,67" (ili en-US "20.00%  21.67").
  static final _taxRow = RegExp(
    r'^\s*(\S{1,3})\s+(\S+)\s+([\d][\d.,]*)\s*%\s+([\d][\d.,]*)\s*$',
    unicode: true,
  );

  // Oblik plaćanja: red posle "Укупан износ" do bloka poreza, npr "Готовина: 530,00".
  // Grupa 1 = naziv (zvanične oznake fiskalizacije), grupa 2 = iznos (može biti
  // više linija — kombinovano plaćanje).
  static final _payment = RegExp(
    r'^\s*(Готовина|Платна картица|Картица|Чек|Пренос на рачун|Инстант плаћање|Ваучер|Друго безготовинско плаћање|Друго безготовинско|Друго)\s*:\s*([\d][\d.,]*)?',
    unicode: true,
  );

  ReceiptHeader parse(String journalText) {
    final lines = const LineSplitter().convert(journalText);

    String tin = '';
    String? buyerId;
    final nameParts = <String>[];
    String? locationName;
    String? address;
    DateTime? pfrTime;
    String? pfrNumber;
    String? invoiceCounter;
    int totalAmount = 0;
    String? paymentMethod;
    final payments = <String, int>{};
    var transactionType = TransactionType.sale;

    final taxRates = parseTaxRates(journalText);

    // Zaglavlje: posle PIB-a slede nazivi/adresa do "Касир".
    var pibIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      if (_pibLine.hasMatch(lines[i])) {
        tin = _pibLine.firstMatch(lines[i])!.group(1)!;
        pibIndex = i;
        break;
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (_refundType.hasMatch(line)) {
        transactionType = TransactionType.refund;
      } else if (_saleType.hasMatch(line)) {
        transactionType = TransactionType.sale;
      }

      final pfrT = _pfrTime.firstMatch(line);
      if (pfrT != null) pfrTime = _parsePfrTime(pfrT.group(1)!.trim());

      final pfrN = _pfrNumber.firstMatch(line);
      if (pfrN != null) pfrNumber = pfrN.group(1);

      final cnt = _counter.firstMatch(line);
      if (cnt != null) invoiceCounter = cnt.group(1);

      final tot = _totalAmount.firstMatch(line);
      if (tot != null && totalAmount == 0) {
        totalAmount = SrNumber.tryParseToMinor(tot.group(2)!) ?? 0;
      }

      final pay = _payment.firstMatch(line);
      if (pay != null) {
        final method = pay.group(1)!;
        paymentMethod ??= method; // prvi/primarni način (granica za nameParts)
        final amount = SrNumber.tryParseToMinor(pay.group(2) ?? '');
        if (amount != null) {
          payments[method] = (payments[method] ?? 0) + amount;
        }
      }

      final buyer = _buyerId.firstMatch(line);
      if (buyer != null && buyerId == null) {
        buyerId = '${buyer.group(1)}:${buyer.group(2)}';
      }

      // Naziv/adresa: linije između PIB-a i "Касир", koje nisu separatori.
      if (pibIndex >= 0 &&
          i > pibIndex &&
          !_cashier.hasMatch(line) &&
          !_esir.hasMatch(line) &&
          !_buyerId.hasMatch(line) &&
          trimmed.isNotEmpty &&
          !_isSeparator(trimmed) &&
          nameParts.length < 6 &&
          paymentMethod == null &&
          totalAmount == 0) {
        // Prekini kad stigne do tipa prometa.
        if (_saleType.hasMatch(line) || _refundType.hasMatch(line)) {
          // ne dodaji
        } else {
          nameParts.add(trimmed);
        }
      }
    }

    // Heuristika: prve linije = naziv, poslednje = lokacija/adresa.
    final merchantName =
        nameParts.isNotEmpty ? nameParts.take(2).join(' ').trim() : '';
    if (nameParts.length >= 3) address = nameParts[nameParts.length - 2];
    if (nameParts.length >= 4) locationName = nameParts.last;

    return ReceiptHeader(
      merchantName: merchantName,
      merchantTin: tin,
      buyerId: buyerId,
      locationName: locationName,
      address: address,
      pfrNumber: pfrNumber,
      pfrTime: pfrTime,
      invoiceCounter: invoiceCounter,
      transactionType: transactionType,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentsJson: payments.isEmpty ? null : jsonEncode(payments),
      taxJson: taxRates.isEmpty
          ? null
          : jsonEncode(taxRates.map((k, v) => MapEntry(k, v))),
    );
  }

  /// Mapira poreske oznake na stope iz obračuna poreza u žurnalu.
  /// Npr. {"Ђ": 20.0, "Е": 10.0}.
  Map<String, double> parseTaxRates(String journalText) {
    final lines = const LineSplitter().convert(journalText);
    final map = <String, double>{};
    for (final line in lines) {
      final m = _taxRow.firstMatch(line);
      if (m != null) {
        final label = m.group(1)!;
        final rate = SrNumber.tryParse(m.group(3)!);
        if (rate != null) map[label] = rate;
      }
    }
    return map;
  }

  DateTime? _parsePfrTime(String raw) {
    // Format: "02.06.2026. 8:36:49"
    final m = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})\.?\s+(\d{1,2}):(\d{2}):(\d{2})')
        .firstMatch(raw);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }

  bool _isSeparator(String line) =>
      RegExp(r'^[=\-]{3,}$').hasMatch(line.replaceAll(' ', '')) ||
      RegExp(r'^[=\- ]+$').hasMatch(line) && line.contains(RegExp(r'[=\-]'));
}
