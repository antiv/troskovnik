import 'package:intl/intl.dart';

import '../domain/currency.dart';

/// Formatiranje novčanih iznosa u minor jedinicama (para/feninga, 1/100 osnovne).
///
/// Iznosi su čuvani kao int da bi se izbegli floating-point problemi. Simbol i
/// locale biraju se po valuti računa.
class MoneyFormat {
  MoneyFormat._();

  static final _formatters = <Currency, NumberFormat>{};

  static NumberFormat _fmt(Currency currency) =>
      _formatters.putIfAbsent(
        currency,
        () => NumberFormat.currency(
          locale: currency.locale,
          symbol: currency.symbol,
          decimalDigits: 2,
        ),
      );

  /// Formatira minor jedinice (para/fening) npr. "1.234,56 RSD" ili "1.234,56 KM".
  static String fromMinor(int minorUnits, [Currency currency = Currency.rsd]) =>
      _fmt(currency).format(minorUnits / 100.0);

  /// Formatira decimalni iznos već u osnovnoj jedinici.
  static String fromDouble(double amount, [Currency currency = Currency.rsd]) =>
      _fmt(currency).format(amount);
}
