import '../domain/receipt_source.dart';

/// Parsira stavke iz PFR žurnal teksta (sekcija 6) — pravilima/regexom, bez AI.
///
/// Format žurnala je standardizovan ali ga potvrđujemo nad realnim fixture-ima
/// pre nego što zakucamo regexe. Stavke koje ne mogu da se isparsiraju vraćaju
/// se kao `ParsedLineItem.unparsed` umesto da ruše ceo račun.
class JournalItemParser {
  const JournalItemParser();

  /// Parsira blok stavki iz žurnala. `taxRatesByLabel` mapira poreske oznake
  /// (Ђ, Е, А, …) na stope iz zaglavlja/obračuna poreza.
  List<ParsedLineItem> parse(
    String journalText, {
    Map<String, double> taxRatesByLabel = const {},
  }) {
    // TODO(fixtures): izoluj sekciju stavki između markera zaglavlja i bloka
    // "Ukupan iznos / Oblici plaćanja"; parsiraj redove
    // "naziv (Ozn)\n  kolicina x jed_cena = ukupno" sa decimalama (zarez),
    // hiljadama i razmacima. Mapiraj oznaku → stopa preko taxRatesByLabel.
    throw UnimplementedError(
      'Žurnal parser nije implementiran: prvo uhvatiti realne fixture-e '
      '(instrukcije.md sekcija 6/11).',
    );
  }
}
