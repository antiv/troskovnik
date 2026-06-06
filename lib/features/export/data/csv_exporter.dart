import 'package:intl/intl.dart';

/// Pomoćnice za generisanje standardnog CSV-a (razdvajač `,`, decimalna tačka,
/// UTF-8 bez BOM) — pogodno za uvoz u alate/skripte/Excel.
class CsvExporter {
  CsvExporter._();

  /// Fiksna, snake_case zaglavlja (ne lokalizuju se radi stabilnog uvoza).
  /// Granularnost: jedan red po stavci računa.
  static const header = <String>[
    'datum',
    'prodavac',
    'pib',
    'id_kupca',
    'poslovni',
    'pfr_broj',
    'brojac',
    'tip',
    'nacin_placanja',
    'artikal',
    'kolicina',
    'jedinica',
    'jedinicna_cena',
    'ukupno_stavka',
    'poreska_oznaka',
    'poreska_stopa',
    'iznos_racuna',
    'verifikacioni_url',
  ];

  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Iznos iz para (1/100) u decimalni string sa tačkom, npr. 31520.00.
  static String money(int minor) => (minor / 100).toStringAsFixed(2);

  /// Datum u ISO-sličnom formatu; null → prazno.
  static String date(DateTime? dt) => dt == null ? '' : _dateFormat.format(dt);

  /// Sastavi CSV: zaglavlje + redovi. Ćelije koje sadrže razdvajač, navodnik
  /// ili novi red navode se pod navodnicima; unutrašnji `"` se duplira.
  static String encodeCsv(
    List<String> header,
    List<List<String>> rows, {
    String delimiter = ',',
  }) {
    final buffer = StringBuffer();
    void writeRow(List<String> cells) {
      buffer.writeln(cells.map((c) => _escape(c, delimiter)).join(delimiter));
    }

    writeRow(header);
    for (final row in rows) {
      writeRow(row);
    }
    return buffer.toString();
  }

  static String _escape(String value, String delimiter) {
    final needsQuoting = value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuoting) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
