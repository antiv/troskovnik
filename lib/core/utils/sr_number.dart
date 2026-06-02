/// Parsiranje brojeva u srpskom formatu: tačka = hiljade, zarez = decimale.
/// Npr. "1.234,56" -> 1234.56 ; "530,00" -> 530.0
library;

class SrNumber {
  SrNumber._();

  /// Parsira srpski formatiran broj u double. Vraća null ako ne uspe.
  static double? tryParse(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[\s ]'), '') // razmaci, nbsp
        .replaceAll('.', '') // hiljade
        .replaceAll(',', '.'); // decimale
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Parsira srpski iznos u para (1/100 RSD), zaokruženo. Vraća null ako ne uspe.
  static int? tryParseToMinor(String raw) {
    final v = tryParse(raw);
    if (v == null) return null;
    return (v * 100).round();
  }
}
