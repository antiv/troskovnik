/// Parsiranje iznosa sa fiskalnih računa, neutralno na format separatora.
///
/// Različiti ESIR vendori štampaju brojeve u srpskom (`1.234,56`) ili en-US
/// (`1,234.56`) formatu. Pošto fiskalni iznosi uvek imaju decimale, decimalni
/// separator je onaj koji se pojavljuje POSLEDNJI; drugi je separator hiljada.
/// Npr. "1.234,56" -> 1234.56 ; "1,234.56" -> 1234.56 ; "530,00" -> 530.0.
library;

class SrNumber {
  SrNumber._();

  /// Parsira iznos (srpski ili en-US format) u double. Vraća null ako ne uspe.
  static double? tryParse(String raw) {
    final s = raw.trim().replaceAll(RegExp(r'\s| '), ''); // razmaci, nbsp
    if (s.isEmpty) return null;

    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');

    final String cleaned;
    if (lastDot == -1 && lastComma == -1) {
      cleaned = s;
    } else if (lastComma > lastDot) {
      // Zarez je decimalni separator → tačke su hiljade.
      cleaned = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Tačka je decimalni separator → zarezi su hiljade.
      cleaned = s.replaceAll(',', '');
    }
    return double.tryParse(cleaned);
  }

  /// Parsira iznos u para (1/100 RSD), zaokruženo. Vraća null ako ne uspe.
  static int? tryParseToMinor(String raw) {
    final v = tryParse(raw);
    if (v == null) return null;
    return (v * 100).round();
  }
}
