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

    // `vl` može biti u query-ju ili u fragmentu (neki QR generatori ga stavljaju
    // posle #). Prvo probaj standardni query.
    var token = uri.queryParameters['vl'];
    if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
      token = _extractVlFromFragment(uri.fragment);
    }
    if (token == null || token.isEmpty) {
      return const InvalidVerificationUrl(InvalidReason.missingToken);
    }

    // Normalizuj na https i izbaci fragment.
    final normalized = uri.replace(scheme: 'https', fragment: '').toString();
    return ValidVerificationUrl(
        normalizedUrl: normalized, token: token, country: country);
  }

  static String? _extractVlFromFragment(String fragment) {
    // Fragment može izgledati kao "/v/?vl=TOKEN" ili "vl=TOKEN".
    final qIndex = fragment.indexOf('?');
    final query = qIndex >= 0 ? fragment.substring(qIndex + 1) : fragment;
    for (final pair in query.split('&')) {
      final eq = pair.indexOf('=');
      if (eq < 0) continue;
      if (pair.substring(0, eq) == 'vl') {
        return Uri.decodeComponent(pair.substring(eq + 1));
      }
    }
    return null;
  }
}
