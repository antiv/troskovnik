import 'currency.dart';

enum Country {
  serbia,
  republikaSrpska,
  montenegro;

  /// Host verifikacionog portala.
  String get portalHost => switch (this) {
        Country.serbia => 'suf.purs.gov.rs',
        Country.republikaSrpska => 'suf.poreskaupravars.org',
        Country.montenegro => 'mapr.tax.gov.me',
      };

  /// Valuta za ovu zemlju.
  Currency get currency => switch (this) {
        Country.serbia => Currency.rsd,
        Country.republikaSrpska => Currency.bam,
        Country.montenegro => Currency.eur,
      };
}
