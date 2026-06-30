/// Validacija i parsiranje verifikacionog URL-a fiskalnog računa (TaxCore).
///
/// QR kod sadrži URL oblika:
///   `https://suf.purs.gov.rs/v/?vl=<TOKEN>`       (Srbija)
///   `https://suf.poreskaupravars.org/v/?vl=<TOKEN>` (Republika Srpska)
/// gde je `<TOKEN>` Base64URL-kodirani potpisani zapis (TaxCore).
///
/// Ovaj sloj NE radi mrežu — samo validira oblik i izvlači token. Mrežno
/// preuzimanje je u ReceiptSource (sekcija 3).
library;

import '../../../core/domain/country.dart';

/// Rezultat validacije skeniranog sadržaja.
sealed class ScanValidation {
  const ScanValidation();
}

/// Sadržaj je validan verifikacioni URL.
class ValidVerificationUrl extends ScanValidation {
  const ValidVerificationUrl({
    required this.normalizedUrl,
    required this.token,
    required this.country,
  });

  /// Normalizovan URL (https, bez fragmenta).
  final String normalizedUrl;

  /// Vrednost `vl` parametra (token), URL-dekodirana.
  final String token;

  /// Zemlja prepoznata iz hosta portala.
  final Country country;
}

/// Sadržaj nije fiskalni verifikacioni URL.
class InvalidVerificationUrl extends ScanValidation {
  const InvalidVerificationUrl(this.reason);

  final InvalidReason reason;
}

enum InvalidReason {
  /// Nije validan URI uopšte.
  notaUrl,

  /// Host nije poznat TaxCore verifikacioni portal.
  wrongHost,

  /// Nema `vl` parametra ili je prazan.
  missingToken,
}

/// Servis bez stanja: validira skenirani string.
class VerificationUrlValidator {
  const VerificationUrlValidator();

  ScanValidation validate(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.isScheme('https') && !uri.isScheme('http')) {
      return const InvalidVerificationUrl(InvalidReason.notaUrl);
    }

    // Prepoznaj zemlju iz hosta (poddomeni su OK: sandbox.suf.purs.gov.rs).
    final host = uri.host.toLowerCase();
    Country? country;
    for (final c in Country.values) {
      final suffix = c.portalHost;
      if (host == suffix || host.endsWith('.$suffix')) {
        country = c;
        break;
      }
    }
    if (country == null) {
      return const InvalidVerificationUrl(InvalidReason.wrongHost);
    }

    // Crna Gora: SPA URL s hash rutingom (#/verify?iic=...&tin=...&crtd=...).
    // Nema `vl` tokena — koristimo `iic` kao jedinstveni identifikator.
    if (country == Country.montenegro) {
      final params = _fragmentParams(uri.fragment);
      final iic = params['iic'];
      if (iic == null || iic.isEmpty) {
        return const InvalidVerificationUrl(InvalidReason.missingToken);
      }
      // Čuvamo ceo URL (fragment je neophodan za MneClient koji izvlači params).
      return ValidVerificationUrl(
        normalizedUrl: uri.replace(scheme: 'https').toString(),
        token: iic,
        country: country,
      );
    }

    // TaxCore (Srbija, RS): `vl` može biti u query-ju ili fragmentu.
    var token = uri.queryParameters['vl'];
    if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
      token = _fragmentParams(uri.fragment)['vl'];
    }
    if (token == null || token.isEmpty) {
      return const InvalidVerificationUrl(InvalidReason.missingToken);
    }

    // Normalizuj na https i izbaci fragment.
    final normalized = uri.replace(scheme: 'https', fragment: '').toString();
    return ValidVerificationUrl(
        normalizedUrl: normalized, token: token, country: country);
  }

  /// Parsira query parametre iz fragmenta (npr. "/verify?iic=X&tin=Y" → {iic: X, tin: Y}).
  static Map<String, String> _fragmentParams(String fragment) {
    final qIndex = fragment.indexOf('?');
    if (qIndex < 0) return {};
    return Uri.splitQueryString(fragment.substring(qIndex + 1));
  }
}
