/// Opseg perioda za izvoz računa u CSV.
library;

enum ExportRange { currentMonth, previousMonth, custom }

/// Granice perioda kao poluotvoreni interval `[from, to)`.
///
/// - currentMonth: ceo tekući mesec.
/// - previousMonth: ceo prethodni mesec (vodi računa o prelazu godine).
/// - custom: od [customFrom] (00:00) do uključivo [customTo] (kraj dana → +1 dan 00:00).
({DateTime from, DateTime to}) exportRangeBounds(
  ExportRange range, {
  required DateTime now,
  DateTime? customFrom,
  DateTime? customTo,
}) {
  switch (range) {
    case ExportRange.currentMonth:
      return (
        from: DateTime(now.year, now.month, 1),
        to: DateTime(now.year, now.month + 1, 1),
      );
    case ExportRange.previousMonth:
      return (
        from: DateTime(now.year, now.month - 1, 1),
        to: DateTime(now.year, now.month, 1),
      );
    case ExportRange.custom:
      final f = customFrom ?? now;
      final t = customTo ?? now;
      return (
        from: DateTime(f.year, f.month, f.day),
        // Uključi i krajnji dan: gornja granica je početak narednog dana.
        to: DateTime(t.year, t.month, t.day).add(const Duration(days: 1)),
      );
  }
}
