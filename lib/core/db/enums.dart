/// Domain enums shared across the data model and the receipt source.
///
/// Imena (snake_case u bazi) i vrednosti enuma su na engleskom po konvenciji
/// iz instrukcije.md (sekcija 4), čak i kad je izvorni pojam na srpskom.
library;

/// Status preuzimanja celog računa (instrukcije.md, sekcija 5).
enum FetchStatus {
  /// Još nije uspešno preuzeto (nema mreže ili račun još nije na serveru).
  pending,

  /// Zaglavlje/žurnal preuzeti, ali bez izdvojenih stavki.
  headerOnly,

  /// Zaglavlje + stavke preuzeti.
  complete,

  /// Račun ne postoji / otkazan / token neispravan (trajno).
  invalid,
}

/// Status stavki (instrukcije.md, sekcija 5).
enum ItemsStatus {
  /// Nema stavki (još).
  none,

  /// Račun postoji ali izdvojene stavke još nisu na serveru -> re-fetch.
  pendingServer,

  /// Stavke parsirane iz žurnal teksta (niža pouzdanost, prikazati indikator).
  fromJournal,

  /// Strukturirane stavke sa servera (puna pouzdanost).
  fromSpecifications,
}

/// Izvor stavki (mapira se i na line_items.source).
enum ItemsSource {
  none,
  journal,
  specifications,
}

/// Tip računa.
enum InvoiceType {
  normal,
  proforma, // Predračun
  copy, // Kopija
  training, // Obuka
}

/// Tip transakcije.
enum TransactionType {
  sale, // Promet prodaja
  refund, // Refundacija
}
