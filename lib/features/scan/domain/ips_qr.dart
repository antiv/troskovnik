/// Parsiranje IPS QR koda (NBS „Instrukcije za plaćanje" — instant plaćanja).
///
/// IPS kod NIJE fiskalni verifikacioni URL. Sadrži naloge za plaćanje u obliku
/// polja `TAG:VREDNOST` razdvojenih uspravnom crtom `|`. Primer (EPS):
///
///   K:PR|V:01|C:1|R:845000000040484987|N:JP EPS BEOGRAD
///   BALKANSKA 13|I:RSD3596,13|P:MRĐO MAČKATOVIĆ
///   ŽUPSKA 13
///   BEOGRAD 6|SF:189|S:UPLATA PO RAČUNU ZA EL. ENERGIJU|RO:97163220000111111111000
///
/// Obavezna polja: K (uvek „PR"), V, C, R, N, I. Opciona: P, SF, S, RO.
/// Vrednosti N i P mogu imati više linija (novi red je unutar vrednosti; polja
/// se razdvajaju samo sa `|`).
///
/// Referenca: NBS „Smernice — Generator/Validator IPS QR koda".
library;

import '../../../core/domain/currency.dart';
import '../../../core/utils/sr_number.dart';

/// Raščlanjen IPS nalog za plaćanje.
class IpsQrData {
  const IpsQrData({
    required this.recipientAccount,
    required this.recipientName,
    required this.currency,
    required this.amountMinor,
    this.payerName,
    this.purpose,
    this.paymentCode,
    this.referenceNumber,
    required this.rawCode,
  });

  /// Račun primaoca (polje R).
  final String recipientAccount;

  /// Naziv primaoca (polje N) — može biti više linija (naziv + adresa).
  final String recipientName;

  /// Valuta iz polja I. IPS je domaći sistem pa je praktično uvek RSD;
  /// nepoznata oznaka pada na [Currency.rsd].
  final Currency currency;

  /// Iznos iz polja I, u para (1/100 valute).
  final int amountMinor;

  /// Naziv/adresa platioca (polje P). Null kad nije prisutno.
  final String? payerName;

  /// Svrha plaćanja (polje S). Null kad nije prisutno.
  final String? purpose;

  /// Šifra plaćanja (polje SF, npr. „189"). Null kad nije prisutno.
  final String? paymentCode;

  /// Model i poziv na broj odobrenja (polje RO). Null kad nije prisutno.
  final String? referenceNumber;

  /// Ceo sirovi kod (za dijagnostiku / eventualno ponovno parsiranje).
  final String rawCode;

  /// Prva linija naziva primaoca (bez adrese) — pogodno za naziv prodavca.
  String get recipientFirstLine {
    final nl = recipientName.indexOf('\n');
    return nl < 0 ? recipientName : recipientName.substring(0, nl);
  }
}

/// Parser bez stanja: iz sirovog skeniranog stringa izvlači [IpsQrData].
class IpsQrParser {
  const IpsQrParser();

  /// Vraća [IpsQrData] ako je `raw` validan IPS kod, inače `null`
  /// (nedostaje obavezno polje, K nije „PR", ili iznos nije čitljiv).
  static IpsQrData? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Polja se razdvajaju sa `|`; vrednosti N/P mogu sadržati nove redove.
    final fields = <String, String>{};
    for (final segment in trimmed.split('|')) {
      final sep = segment.indexOf(':');
      if (sep < 0) continue;
      final tag = segment.substring(0, sep).trim().toUpperCase();
      final value = segment.substring(sep + 1);
      // Prvi put viđen tag ima prednost (ne gazi ga eventualni duplikat).
      fields.putIfAbsent(tag, () => value);
    }

    // Obavezna polja i identifikacija koda.
    if (fields['K']?.trim().toUpperCase() != 'PR') return null;
    final account = fields['R']?.trim();
    final name = fields['N'];
    final rawAmount = fields['I'];
    if (account == null || account.isEmpty) return null;
    if (name == null || name.trim().isEmpty) return null;
    if (rawAmount == null || rawAmount.trim().isEmpty) return null;

    final parsedAmount = _parseAmount(rawAmount);
    if (parsedAmount == null) return null;

    return IpsQrData(
      recipientAccount: account,
      recipientName: name.trim(),
      currency: parsedAmount.currency,
      amountMinor: parsedAmount.amountMinor,
      payerName: _clean(fields['P']),
      purpose: _clean(fields['S']),
      paymentCode: _clean(fields['SF']),
      referenceNumber: _clean(fields['RO']),
      rawCode: trimmed,
    );
  }

  /// Polje I: 3-slovna ISO valuta + iznos sa zarezom kao decimalom
  /// (npr. „RSD3596,13"). Vraća null ako iznos nije čitljiv.
  static ({Currency currency, int amountMinor})? _parseAmount(String raw) {
    final s = raw.trim();
    // Odvoji vodeći slovni deo (oznaka valute) od numeričkog dela.
    final match = RegExp(r'^([A-Za-z]{3})?\s*([\d.,]+)$').firstMatch(s);
    if (match == null) return null;

    final code = match.group(1)?.toUpperCase();
    final minor = SrNumber.tryParseToMinor(match.group(2)!);
    if (minor == null) return null;

    final currency = Currency.values.firstWhere(
      (c) => c.isoCode == code,
      orElse: () => Currency.rsd,
    );
    return (currency: currency, amountMinor: minor);
  }

  static String? _clean(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
