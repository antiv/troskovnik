enum Currency {
  rsd,
  bam,
  eur;

  /// ISO 4217 kod.
  String get isoCode => switch (this) {
        Currency.rsd => 'RSD',
        Currency.bam => 'BAM',
        Currency.eur => 'EUR',
      };

  /// Simbol koji se prikazuje korisniku.
  String get symbol => switch (this) {
        Currency.rsd => 'RSD',
        Currency.bam => 'KM',
        Currency.eur => 'EUR',
      };

  /// Intl locale za formatiranje.
  String get locale => switch (this) {
        Currency.rsd => 'sr_RS',
        Currency.bam => 'sr_RS',
        Currency.eur => 'hr',
      };
}
