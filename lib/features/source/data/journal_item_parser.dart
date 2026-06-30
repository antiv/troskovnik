import '../../../core/db/enums.dart';
import '../../../core/utils/sr_number.dart';
import '../domain/receipt_source.dart';

/// Parsira stavke iz PFR žurnal teksta (sekcija 6) — pravilima/regexom, bez AI.
///
/// Format potvrđen nad realnim računom (vidi test/fixtures/complete.journal.anon.txt):
/// sekcija stavki je između reda "Артикли" / zaglavlja tabele i reda
/// "Укупан износ:". Svaka stavka su DVA reda:
///   1) "Naziv (jedinica) (Oznaka)"   — naziv + opciono (jedinica) + (poreska oznaka)
///   2) "   cena    količina    ukupno" — tri broja u srpskom formatu
/// Stavke koje ne mogu da se isparsiraju vraćaju se kao
/// `ParsedLineItem.unparsed` umesto da ruše ceo račun.
class JournalItemParser {
  const JournalItemParser();

  // Marker linije (rade i sa ćirilicom i sa razmacima/crticama oko teksta).
  static final _itemsStart = RegExp(r'Артикли', unicode: true);
  // "Цена" (Srbija/Ekavski) ili "Цијена" (RS/Ijekavski): Ц(?:иј)?ена.
  static final _tableHeader = RegExp(r'Назив.*Ц(?:иј)?ена.*Кол', unicode: true);
  // Kraj stavki: normalna suma ili RS рефундација.
  static final _totalLine = RegExp(
    r'(Укупан\s+износ|Укупна\s+рефундација)\s*:',
    unicode: true,
  );

  // Naziv stavke: hvata trailing zagrade na kraju kao (jedinica) i (oznaka).
  // Poreska oznaka je jedan ćirilićni/latinični karakter u poslednjoj zagradi.
  static final _trailingParen =
      RegExp(r'\(([^()]*)\)\s*$', unicode: true);

  // Red sa vrednostima: tri broja razdvojena razmacima (srpski ili en-US
  // format — SrNumber sam prepoznaje decimalni separator).
  // Treći broj (ukupno) može biti negativan kod refundacija.
  static final _valuesLine = RegExp(
    r'^\s*([\d][\d.,]*)\s+([\d][\d.,]*)\s+(-?[\d][\d.,]*)\s*$',
    unicode: true,
  );

  /// Parsira blok stavki iz žurnala. `taxRatesByLabel` mapira poreske oznake
  /// (Ђ, Е, А, …) na stope iz zaglavlja/obračuna poreza.
  List<ParsedLineItem> parse(
    String journalText, {
    Map<String, double> taxRatesByLabel = const {},
  }) {
    final lines = const LineSplitter().convert(journalText);

    // Pronađi početak sekcije stavki (red posle zaglavlja tabele, ili posle "Артикли").
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      if (_tableHeader.hasMatch(lines[i])) {
        start = i + 1;
        break;
      }
    }
    if (start < 0) {
      for (var i = 0; i < lines.length; i++) {
        if (_itemsStart.hasMatch(lines[i])) {
          start = i + 1;
          break;
        }
      }
    }
    if (start < 0) return const [];

    // Pronađi kraj (red "Укупан износ:").
    var end = lines.length;
    for (var i = start; i < lines.length; i++) {
      if (_totalLine.hasMatch(lines[i])) {
        end = i;
        break;
      }
    }

    final items = <ParsedLineItem>[];
    var i = start;
    while (i < end) {
      final nameLine = lines[i].trim();
      if (nameLine.isEmpty || _isSeparator(nameLine)) {
        i++;
        continue;
      }

      // Sledeći neprazni red treba da bude red sa vrednostima.
      var j = i + 1;
      while (j < end && lines[j].trim().isEmpty) {
        j++;
      }
      final valuesMatch =
          j < end ? _valuesLine.firstMatch(lines[j]) : null;

      if (valuesMatch == null) {
        // Možda naziv prelazi na sljedeći red (dugački nazivi se prelome).
        // Pogledaj još jedan red naprijed: ako je on values, spoji oba u naziv.
        var k = j + 1;
        while (k < end && lines[k].trim().isEmpty) { k++; }
        if (k < end) {
          final valuesMatchK = _valuesLine.firstMatch(lines[k]);
          if (valuesMatchK != null) {
            final wrappedName = '${nameLine.trim()} ${lines[j].trim()}';
            items.add(_buildItem(wrappedName, valuesMatchK, taxRatesByLabel));
            i = k + 1;
            continue;
          }
        }
        // Naziv bez vrednosti → neparsiran, ali samo ako linija nije prazna/separator.
        items.add(ParsedLineItem.unparsed(nameLine, ItemsSource.journal));
        i++;
        continue;
      }

      final parsed = _buildItem(nameLine, valuesMatch, taxRatesByLabel);
      items.add(parsed);
      i = j + 1;
    }
    return items;
  }

  ParsedLineItem _buildItem(
    String nameLine,
    RegExpMatch values,
    Map<String, double> taxRatesByLabel,
  ) {
    // Izvuci poreske oznake i jedinicu iz trailing zagrada.
    var name = nameLine;
    String? taxLabel;
    String? unit;

    // Poslednja zagrada = poreska oznaka (jedan kratak token).
    final lastParen = _trailingParen.firstMatch(name);
    if (lastParen != null) {
      final content = lastParen.group(1)!.trim();
      name = name.substring(0, lastParen.start).trim();
      if (content.length <= 3) {
        taxLabel = content;
      } else {
        unit = content; // duža zagrada je verovatno jedinica
      }
    }
    // Pretposlednja zagrada = jedinica mere, ako postoji.
    final unitParen = _trailingParen.firstMatch(name);
    if (unitParen != null) {
      final content = unitParen.group(1)!.trim();
      // Jedinica je kratka reč (kom, kg, l, m, ком...).
      if (content.length <= 5 && unit == null) {
        unit = content;
        name = name.substring(0, unitParen.start).trim();
      }
    }

    final unitPrice = SrNumber.tryParseToMinor(values.group(1)!) ?? 0;
    final quantity = SrNumber.tryParse(values.group(2)!) ?? 1.0;
    final total = SrNumber.tryParseToMinor(values.group(3)!) ?? 0;
    final taxRate = taxLabel != null ? taxRatesByLabel[taxLabel] : null;

    return ParsedLineItem(
      name: name,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      total: total,
      taxLabel: taxLabel,
      taxRate: taxRate,
      source: ItemsSource.journal,
    );
  }

  bool _isSeparator(String line) =>
      RegExp(r'^[=\-]{3,}$').hasMatch(line.replaceAll(' ', ''));
}

/// Minimalni line splitter (izbegava import dart:convert u domenu).
class LineSplitter {
  const LineSplitter();
  List<String> convert(String s) => s.split(RegExp(r'\r\n|\r|\n'));
}
