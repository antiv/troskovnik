import 'country.dart';

/// Vrsta kupca prepoznata iz identifikacije na fiskalnom računu.
enum BuyerKind {
  /// Domaće pravno lice ili preduzetnik sa PIB-om/JIB-om — „poslovni" račun.
  company,

  /// Strano pravno lice (strani poreski broj) — takođe „poslovni".
  foreignCompany,

  /// Fizičko lice identifikovano JMBG-om/JMB-om (ne računa se kao poslovni).
  person,

  /// Lični dokument (lična karta, pasoš, penzionerska kartica, ...).
  document,

  unknown,
}

/// Tumači sirovu identifikaciju kupca sa fiskalnog računa (`ReceiptRow.buyerId`).
///
/// - **Srbija i Republika Srpska (TaxCore):** „ИД купца" u obliku `kod:broj`.
///   Kodovi (šifarnik PU Srbije): `10` PIB, `11` JMBG, `12` PIB + JBKJS
///   (`12:PIB:JBKJS`), `13` penzionerska kartica, `14` BPG, `20`–`23` lični
///   dokumenti, `30`–`3x` strani dokumenti, `40` strani poreski broj.
///   Za RS zvanična lista kodova nije potvrđena, pa se dodatno gleda broj:
///   JIB pravnog lica ima 13 cifara i počinje sa `4`, a JMB počinje danom
///   rođenja (`0`–`3`).
/// - **Crna Gora (EFI):** `IDType:IDNum`, gde je `TIN` PIB (8 cifara), `ID`
///   lični broj, `PASS` pasoš, `VAT`/`TAX` PDV/poreski broj, `SOC` broj
///   socijalnog osiguranja.
class BuyerIdentity {
  const BuyerIdentity({
    required this.kind,
    required this.code,
    required this.number,
  });

  final BuyerKind kind;

  /// Kod tipa identifikacije (npr. "10", "11", "TIN").
  final String code;

  /// Broj identifikacije bez koda (za `12:PIB:JBKJS` samo PIB).
  final String number;

  /// Račun se automatski označava kao „poslovni" samo za firme.
  bool get isBusiness =>
      kind == BuyerKind.company || kind == BuyerKind.foreignCompany;

  /// Normalizovan poreski broj firme (ključ za analitiku po firmama), ili null
  /// kad kupac nije firma.
  String? get taxId => isBusiness ? number : null;

  static final _taxCore = RegExp(r'^\s*(\d{1,2})\s*:\s*([0-9A-Za-z]+)');
  static final _efi = RegExp(r'^\s*([A-Za-z]+)\s*:\s*(\S+)');

  /// Parsira sirov `buyerId` za datu zemlju. Null kad nema identifikacije.
  static BuyerIdentity? parse(String? raw, Country country) {
    if (raw == null || raw.trim().isEmpty) return null;
    return switch (country) {
      Country.montenegro => _parseEfi(raw),
      Country.serbia || Country.republikaSrpska => _parseTaxCore(raw, country),
    };
  }

  static BuyerIdentity _parseTaxCore(String raw, Country country) {
    final m = _taxCore.firstMatch(raw);
    if (m == null) {
      return BuyerIdentity(
          kind: BuyerKind.unknown, code: '', number: raw.trim());
    }
    final code = m.group(1)!;
    final number = m.group(2)!;
    final kind = switch (code) {
      '10' || '12' => _companyOrPerson(number, country),
      '11' => BuyerKind.person,
      '40' => BuyerKind.foreignCompany,
      '13' || '14' => BuyerKind.document,
      _ when code.startsWith('2') || code.startsWith('3') => BuyerKind.document,
      _ => BuyerKind.unknown,
    };
    return BuyerIdentity(kind: kind, code: code, number: number);
  }

  /// U RS se pod istim kodom može naći JMB fizičkog lica (13 cifara, počinje
  /// danom rođenja), dok JIB pravnog lica počinje sa `4`.
  static BuyerKind _companyOrPerson(String number, Country country) {
    if (country == Country.republikaSrpska &&
        number.length == 13 &&
        !number.startsWith('4')) {
      return BuyerKind.person;
    }
    return BuyerKind.company;
  }

  static BuyerIdentity _parseEfi(String raw) {
    final m = _efi.firstMatch(raw);
    if (m == null) {
      return BuyerIdentity(
          kind: BuyerKind.unknown, code: '', number: raw.trim());
    }
    final code = m.group(1)!.toUpperCase();
    final kind = switch (code) {
      'TIN' || 'VAT' || 'TAX' => BuyerKind.company,
      'ID' || 'SOC' => BuyerKind.person,
      'PASS' => BuyerKind.document,
      _ => BuyerKind.unknown,
    };
    return BuyerIdentity(kind: kind, code: code, number: m.group(2)!);
  }

  /// Naziv tipa broja za prikaz (PIB, JIB, JMBG, ...).
  String label(Country country) => switch (kind) {
        BuyerKind.company => country == Country.republikaSrpska ? 'JIB' : 'PIB',
        BuyerKind.foreignCompany => 'TIN',
        BuyerKind.person => country == Country.republikaSrpska ? 'JMB' : 'JMBG',
        BuyerKind.document || BuyerKind.unknown => code,
      };

  /// Broj za prikaz; lični brojevi se maskiraju osim poslednje 4 cifre.
  String get maskedNumber {
    if (isBusiness || number.length <= 4) return number;
    return '${'•' * (number.length - 4)}${number.substring(number.length - 4)}';
  }
}
