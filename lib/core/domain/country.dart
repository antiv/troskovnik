import 'currency.dart';

enum Country {
  serbia,
  republikaSrpska;

  /// Host verifikacionog TaxCore portala.
  String get portalHost => switch (this) {
        Country.serbia => 'suf.purs.gov.rs',
        Country.republikaSrpska => 'suf.poreskaupravars.org',
      };

  /// Valuta za ovu zemlju.
  Currency get currency => switch (this) {
        Country.serbia => Currency.rsd,
        Country.republikaSrpska => Currency.bam,
      };
}
