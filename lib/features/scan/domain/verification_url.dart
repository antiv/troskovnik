/// Validacija i parsiranje verifikacionog URL-a srpskog fiskalnog računa.
///
/// QR kod sadrži URL oblika:
///   `https://suf.purs.gov.rs/v/?vl=<TOKEN>`
/// gde je `<TOKEN>` Base64URL-kodirani potpisani zapis (TaxCore).
///
/// Ovaj sloj NE radi mrežu — samo validira oblik i izvlači token. Mrežno
/// preuzimanje je u ReceiptSource (sekcija 3).
library;

/// Hostovi koje prihvatamo kao validne verifikacione adrese.
///
/// Pored produkcionog `suf.purs.gov.rs`, TaxCore u praksi koristi i poddomene
/// (npr. `sandbox.suf.purs.gov.rs`), pa proveravamo da se host završava na
/// `suf.purs.gov.rs`.
const _verificationHostSuffix = 'suf.purs.gov.rs';

/// Rezultat validacije skeniranog sadržaja.
sealed class ScanValidation {
  const ScanValidation();
}

/// Sadržaj je validan verifikacioni URL.
class ValidVerificationUrl extends ScanValidation {
  const ValidVerificationUrl({
    required this.normalizedUrl,
    required this.token,
  });

  /// Normalizovan URL (https, bez fragmenta).
  final String normalizedUrl;

  /// Vrednost `vl` parametra (token), URL-dekodirana.
  final String token;
}

/// Sadržaj nije fiskalni verifikacioni URL.
class InvalidVerificationUrl extends ScanValidation {
  const InvalidVerificationUrl(this.reason);

  final InvalidReason reason;
}

enum InvalidReason {
  /// Nije validan URI uopšte.
  notaUrl,

  /// Host nije *.suf.purs.gov.rs.
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

    final host = uri.host.toLowerCase();
    final hostOk = host == _verificationHostSuffix ||
        host.endsWith('.$_verificationHostSuffix');
    if (!hostOk) {
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
    return ValidVerificationUrl(normalizedUrl: normalized, token: token);
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
