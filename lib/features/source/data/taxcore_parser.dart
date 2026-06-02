import '../../../core/db/enums.dart';
import '../domain/receipt_source.dart';
import 'journal_item_parser.dart';

/// Rule-based parser TaxCore odgovora (bez AI-ja).
///
/// PAŽNJA (sekcija 3, bold): tačan oblik HTML stranice i format izdvojenih
/// stavki (HTML vs JSON, nazivi polja) MORA se potvrditi nad realnim
/// fixture-ima. Ovde je skelet sa jasnim mestima za empirijsko popunjavanje;
/// implementacija selektora/regexa ide tek kad fixture-i postoje
/// (test/fixtures/*.html|json).
class TaxCoreParser {
  const TaxCoreParser({this.journalParser = const JournalItemParser()});

  final JournalItemParser journalParser;

  ParsedReceipt parse(RawPortalResponse raw) {
    // Trajno nevažeći / nepostojeći račun → invalid.
    // (Marker potvrditi nad realnim "invalid" fixture-om — sekcija 11 #4.)
    if (raw.statusCode == 404 || _looksInvalid(raw.body)) {
      return const ParsedReceipt(
        fetchStatus: FetchStatus.invalid,
        itemsStatus: ItemsStatus.none,
        itemsSource: ItemsSource.none,
      );
    }

    // TODO(fixtures): parsiraj zaglavlje iz raw.body (HTML).
    // TODO(fixtures): ako raw.specificationsBody != null → parsiraj strukturirano
    //   (fromSpecifications, complete).
    // TODO(fixtures): inače žurnal stavke (journalParser) → fromJournal/headerOnly;
    //   ako ni žurnal nema stavke → pendingServer (zakazati re-fetch).
    throw UnimplementedError(
      'Parser nije implementiran: prvo uhvatiti realne fixture-e '
      '(vidi tool/capture_fixtures.dart i instrukcije.md sekcija 3/11).',
    );
  }

  bool _looksInvalid(String body) {
    final lower = body.toLowerCase();
    // Kandidati za markere — POTVRDITI nad realnim "invalid" fixture-om.
    return lower.contains('nije pronađen') ||
        lower.contains('nije pronadjen') ||
        (lower.contains('invalid') && lower.contains('invoice'));
  }
}
