import 'package:intl/intl.dart';

/// Formatting helpers for Serbian dinar (RSD) amounts.
///
/// Amounts are stored as integer minor units (para, 1/100 RSD) to avoid
/// floating-point rounding, and formatted with the `sr_RS` locale
/// (space thousands separator, comma decimal).
class MoneyFormat {
  MoneyFormat._();

  static final NumberFormat _rsd = NumberFormat.currency(
    locale: 'sr_RS',
    symbol: 'RSD',
    decimalDigits: 2,
  );

  /// Formats minor units (para) as e.g. "1.234,56 RSD".
  static String fromMinor(int minorUnits) =>
      _rsd.format(minorUnits / 100.0);

  /// Formats a decimal amount already in RSD.
  static String fromDouble(double amount) => _rsd.format(amount);
}
