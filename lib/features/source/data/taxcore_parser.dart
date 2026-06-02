import 'package:html/parser.dart' as html_parser;

import '../../../core/db/enums.dart';
import '../domain/receipt_source.dart';
import 'journal_header_parser.dart';
import 'journal_item_parser.dart';
import 'specifications_parser.dart';

/// Rule-based parser TaxCore odgovora (bez AI-ja).
///
/// Empirijski potvrđeno (vidi memory: taxcore-portal-structure): ceo žurnal je
/// server-renderovan u `<pre>` bloku verifikacione stranice i to je pouzdan,
/// uvek-prisutan izvor. Izdvojene stavke (AJAX `/specifications`) su enhancement
/// i mogu biti nedostupne (`{"success":false}`) i za kompletan račun.
class TaxCoreParser {
  const TaxCoreParser({
    this.headerParser = const JournalHeaderParser(),
    this.journalParser = const JournalItemParser(),
    this.specsParser = const SpecificationsParser(),
  });

  final JournalHeaderParser headerParser;
  final JournalItemParser journalParser;
  final SpecificationsParser specsParser;

  ParsedReceipt parse(RawPortalResponse raw) {
    // Trajno nevažeći / nepostojeći račun → invalid.
    if (raw.statusCode == 404 || _looksInvalid(raw.body)) {
      return const ParsedReceipt(
        fetchStatus: FetchStatus.invalid,
        itemsStatus: ItemsStatus.none,
        itemsSource: ItemsSource.none,
      );
    }

    final journal = extractJournal(raw.body);
    if (journal == null || journal.trim().isEmpty) {
      // Stranica je tu ali bez žurnala → još nije proknjiženo na serveru.
      return const ParsedReceipt(
        fetchStatus: FetchStatus.pending,
        itemsStatus: ItemsStatus.pendingServer,
        itemsSource: ItemsSource.none,
      );
    }

    final header = headerParser.parse(journal);
    final taxRates = headerParser.parseTaxRates(journal);

    // 1) Probaj strukturirane specifikacije (puna pouzdanost).
    final specItems = specsParser.tryParse(raw.specificationsBody);
    if (specItems != null && specItems.isNotEmpty) {
      return ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromSpecifications,
        itemsSource: ItemsSource.specifications,
        header: header,
        items: specItems,
        journalText: journal,
      );
    }

    // 2) Padni na stavke iz žurnala.
    final journalItems =
        journalParser.parse(journal, taxRatesByLabel: taxRates);
    if (journalItems.isNotEmpty) {
      return ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromJournal,
        itemsSource: ItemsSource.journal,
        header: header,
        items: journalItems,
        journalText: journal,
      );
    }

    // 3) Imamo zaglavlje ali nema stavki ni u žurnalu → pendingServer.
    return ParsedReceipt(
      fetchStatus: FetchStatus.headerOnly,
      itemsStatus: ItemsStatus.pendingServer,
      itemsSource: ItemsSource.none,
      header: header,
      journalText: journal,
    );
  }

  /// Izvlači tekst žurnala iz `<pre>` bloka stranice. `<br/>` postaje novi red,
  /// embedded `<img>` (QR/barkod) se uklanja.
  String? extractJournal(String htmlBody) {
    if (htmlBody.isEmpty) return null;
    final doc = html_parser.parse(htmlBody);
    final pre = doc.querySelector('pre');
    if (pre == null) return null;
    // Ukloni slike (QR/barkod gif) pre uzimanja teksta.
    for (final img in pre.querySelectorAll('img')) {
      img.remove();
    }
    // innerHtml čuva <br>, pa ih pretvaramo u nove redove; tekst dekodira entitete.
    final withBreaks = pre.innerHtml.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    final fragment = html_parser.parseFragment(withBreaks);
    return fragment.text;
  }

  bool _looksInvalid(String body) {
    final lower = body.toLowerCase();
    return lower.contains('nije pronađen') ||
        lower.contains('nije pronadjen') ||
        (lower.contains('invalid') && lower.contains('invoice'));
  }
}
