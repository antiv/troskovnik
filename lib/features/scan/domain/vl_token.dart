/// Best-effort dekodiranje `vl` tokena za OFFLINE zaglavlje (sekcija 3, korak 2;
/// sekcija 11, otvoreno pitanje #2).
///
/// VAŽNO: tačan binarni raspored tokena je TaxCore-specifičan i mora se
/// potvrditi nad realnim računima pre nego što se na njega oslonimo. Zato ovaj
/// dekoder NIKAD ne baca grešku i sve „izvučeno" označava kao nepouzdano dok se
/// ne validira nad fixture-ima. Ako dekodiranje ne uspe, vraća se token koji je
/// i dalje upotrebljiv za mrežni poziv (token je primarni izvor istine).
library;

import 'dart:convert';
import 'dart:typed_data';

/// Rezultat pokušaja dekodiranja `vl` tokena.
class DecodedVlToken {
  const DecodedVlToken({
    required this.rawBytesLength,
    this.requestedBy,
    this.signedBy,
    this.totalCounter,
    this.transactionTypeCounter,
    this.unverified = true,
  });

  /// Dužina dekodiranog binarnog sadržaja (sanity check).
  final int rawBytesLength;

  /// PIB izdavaoca (ako se pouzdano izvuče) — inače null.
  final String? requestedBy;
  final String? signedBy;

  /// Brojači iz tokena (kandidati; potvrditi nad realnim podacima).
  final int? totalCounter;
  final int? transactionTypeCounter;

  /// True dok god mapiranje polja nije empirijski potvrđeno.
  final bool unverified;
}

class VlTokenDecoder {
  const VlTokenDecoder();

  /// Pokušava da Base64URL-dekodira token u bajtove. Tolerantan na nedostajući
  /// padding i na standardni Base64 alfabet.
  Uint8List? tryDecodeBytes(String token) {
    final normalized = token.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(
      (normalized.length + 3) & ~3,
      '=',
    );
    try {
      return base64.decode(padded);
    } catch (_) {
      try {
        return base64Url.decode(token.padRight((token.length + 3) & ~3, '='));
      } catch (_) {
        return null;
      }
    }
  }

  /// Vraća strukturu sa onim što se moglo izvući. Polja su `unverified: true`
  /// dok se raspored ne potvrdi nad fixture-ima — tada ovde dodajemo stvarno
  /// parsiranje (offset-i, kodiranja). Za sada izlažemo samo dužinu.
  DecodedVlToken decodeHeader(String token) {
    final bytes = tryDecodeBytes(token);
    return DecodedVlToken(rawBytesLength: bytes?.length ?? 0);
  }
}
