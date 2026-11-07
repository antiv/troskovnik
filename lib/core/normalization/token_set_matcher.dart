import 'dart:math' as math;

/// Kandidat iz tabele kanonskih artikala za algoritamsko poređenje (Sloj 3).
class CanonicalCandidate {
  CanonicalCandidate({
    required this.id,
    required this.canonicalKey,
    required this.displayName,
    this.defaultCategoryId,
  }) : tokens = canonicalKey.isEmpty ? const [] : canonicalKey.split(' ');

  final int id;
  final String canonicalKey;
  final String displayName;
  final int? defaultCategoryId;
  final List<String> tokens;
}

/// Rezultat poređenja novog artikla sa kanonskim šifarnikom.
class TokenMatchResult {
  const TokenMatchResult({
    required this.candidate,
    required this.score,
  });

  final CanonicalCandidate candidate;
  final int score;
}

/// Implementacija `token_set_ratio` algoritma sa Levenshtein tolerancijom na
/// slovne greške (Sloj 3).
class TokenSetMatcher {
  const TokenSetMatcher._();

  /// Podrazumevani prag pouzdanosti (0..100) za automatsko spajanje artikala.
  static const int defaultThreshold = 85;

  /// Generičke imenice i pridevi koji sami za sebe (bez poklapanja brenda ili
  /// specifičnog naziva) ne smeju izazvati spajanje dva različita artikla
  /// (npr. "dukat mleko" i "imlek mleko" dele samo reč "mleko").
  static const Set<String> genericTokens = {
    'mleko',
    'jogurt',
    'hleb',
    'voda',
    'sok',
    'pivo',
    'kafa',
    'cokolada',
    'cokoladna',
    'mlecna',
    'ulje',
    'secer',
    'brasno',
    'psenicno',
    'sir',
    'keks',
    'cips',
    'flips',
    'sapun',
    'sampon',
    'deterdzent',
    'omeksivac',
    'pavlaka',
    'maslac',
    'puter',
    'margarin',
    'jaja',
    'kokosija',
    'meso',
    'pecivo',
    'kifla',
    'burek',
    'sladoled',
    'krem',
    'caj',
    'vino',
    'rakija',
    'testenina',
    'makarone',
    'spagete',
    'pirinac',
    'so',
    'kuhinjska',
    'zacin',
    'dodatak',
    'jelima',
    'kecap',
    'majonez',
    'senf',
    'kisela',
    'mineralna',
    'gazirani',
    'gazirana',
    'negazirana',
    'prirodna',
    'beli',
    'crni',
    'sveze',
    'svezi',
    'dugotrajno',
    'uht',
    'suncokretovo',
    'jestivo',
    'mlevena',
    'mleveno',
    'instant',
    'classic',
    'original',
    'svetlo',
    'tamno',
    'pasteta',
    'pileci',
    'svinjski',
    'juneci',
    'file',
    'but',
    'toalet',
    'papir',
    'za',
    'ves',
    'sudove',
    'usluga',
    'troskovi',
    'doplata',
    'robe',
    'mp',
    'tip',
    'napitak',
    'kapsule',
    'tecni',
    'sa',
  };

  /// Reči koje označavaju distinktnu varijantu proizvoda (npr. Coca-Cola vs Coca-Cola Zero,
  /// Brašno T-400 vs T-500) i sprečavaju podskupno spajanje ($S_0 = S_1$).
  static const Set<String> variantDiscriminators = {
    'zero',
    'light',
    'max',
    'free',
    'bez',
    'tip400',
    'tip500',
    'tip850',
    'integralni',
    'integralno',
    'crni',
    'beli',
    'ljuti',
    'blagi',
    'decaffeinato',
    'soja',
    'trosak',
  };

  /// Izračunava `token_set_ratio` skor u opsegu `[0, 100]` između dva
  /// prethodno očišćena naziva (`cleanedKey`).
  static int tokenSetRatio(String cleanedA, String cleanedB) {
    final a = cleanedA.trim();
    final b = cleanedB.trim();
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 100;

    final listA = a.split(' ').where((t) => t.isNotEmpty).toList();
    final listB = b.split(' ').where((t) => t.isNotEmpty).toList();
    return _tokenSetRatioFromLists(a, listA, b, listB);
  }

  static int _tokenSetRatioFromLists(
    String a,
    List<String> listA,
    String b,
    List<String> listB,
  ) {
    if (listA.isEmpty || listB.isEmpty) return 0;

    // Formiranje preseka A ∩ B uz toleranciju na slovne greške (Levenshtein <= 1
    // za tokene duže od 4 karaktera).
    final matchedA = <int>{};
    final matchedB = <int>{};
    final intersection = <String>[];

    // 1. Egzaktna poklapanja tokena.
    for (var i = 0; i < listA.length; i++) {
      final tokA = listA[i];
      for (var j = 0; j < listB.length; j++) {
        if (matchedB.contains(j)) continue;
        if (tokA == listB[j]) {
          matchedA.add(i);
          matchedB.add(j);
          intersection.add(tokA);
          break;
        }
      }
    }

    // 2. Fuzzy poklapanja tokena (dužina > 4 i Levenshtein distanca <= 1,
    // npr. "kravca" -> "kravica").
    for (var i = 0; i < listA.length; i++) {
      if (matchedA.contains(i)) continue;
      final tokA = listA[i];
      final lenA = tokA.length;
      if (lenA <= 4) continue;
      final a0 = tokA.codeUnitAt(0);
      final a1 = tokA.codeUnitAt(1);

      for (var j = 0; j < listB.length; j++) {
        if (matchedB.contains(j)) continue;
        final tokB = listB[j];
        final lenB = tokB.length;
        if (lenB <= 4 || (lenA - lenB).abs() > 1) continue;
        // Brza provera po Dirihleovom principu: za Levenshtein <= 1 bar jedan od prva 2 znaka mora da se poklapa.
        final b0 = tokB.codeUnitAt(0);
        final b1 = tokB.codeUnitAt(1);
        if (a0 != b0 && a1 != b1 && a0 != b1 && a1 != b0) continue;

        // Ne spajaj različite tipove brašna (tip400 vs tip500) ili goriva (bmb95 vs bmb100).
        if (tokA.startsWith('tip') && tokB.startsWith('tip')) continue;
        if (tokA.startsWith('bmb') && tokB.startsWith('bmb')) continue;

        if (levenshteinDistance(tokA, tokB, maxDistance: 1) <= 1) {
          matchedA.add(i);
          matchedB.add(j);
          intersection.add(tokB); // kanonski oblik iz B
          break;
        }
      }
    }

    if (intersection.isEmpty) {
      // Ako su oba po jedan dugačak token i veoma slična, vrati karakternu sličnost.
      if (listA.length == 1 && listB.length == 1 && (a.length - b.length).abs() <= 2) {
        return similarityRatio(a, b);
      }
      return 0;
    }

    final remainderA = <String>[
      for (var i = 0; i < listA.length; i++)
        if (!matchedA.contains(i)) listA[i],
    ];
    final remainderB = <String>[
      for (var j = 0; j < listB.length; j++)
        if (!matchedB.contains(j)) listB[j],
    ];

    // Ako su oba skupa tokena identična (nakon fuzzy korekcije slovne greške).
    if (remainderA.isEmpty && remainderB.isEmpty) {
      return 100;
    }

    // Zaštita od spajanja na osnovu samo generičkih reči (npr. "mleko", "sok", "voda"):
    // Ako presek čine isključivo generičke reči, a barem jedan naziv ima dodatne
    // specifične reči (brend/proizvođač), ne dozvoli automatsko spajanje.
    final specificIntersection =
        intersection.where((t) => !genericTokens.contains(t)).toList();
    if (specificIntersection.isEmpty) {
      return 0;
    }

    // Provera da li ostatak sadrži diskriminator varijante (npr. "zero", "tip400").
    final hasVariantConflict =
        remainderA.any(variantDiscriminators.contains) ||
        remainderB.any(variantDiscriminators.contains);

    intersection.sort();
    remainderA.sort();
    remainderB.sort();

    final s0 = intersection.join(' ');
    final s1 = remainderA.isEmpty ? s0 : '$s0 ${remainderA.join(' ')}';
    final s2 = remainderB.isEmpty ? s0 : '$s0 ${remainderB.join(' ')}';

    final r12 = similarityRatio(s1, s2);
    if (hasVariantConflict) {
      return math.min(r12, defaultThreshold - 1);
    }

    // Specifični (negenerički) tokeni u ostacima A \ B i B \ A.
    final specificRemA =
        remainderA.where((t) => !genericTokens.contains(t)).toList();
    final specificRemB =
        remainderB.where((t) => !genericTokens.contains(t)).toList();

    // Ako OBE strane imaju sopstvene specifične tokene van preseka
    // (npr. "Sladoled Grom Mango" vs "Sladoled Grom Jagoda",
    // "Supa Bečka Podravka" vs "Supa Tirolska Podravka",
    // "Palačinke sa nutelom" vs "Palačinke sa džemom"),
    // dozvoli spajanje samo ako je reč o ERP skraćivanju prefiksa (npr. "sipur" vs "sipurak").
    if (specificRemA.isNotEmpty && specificRemB.isNotEmpty) {
      final isPrefixTruncation = specificRemA.every(
        (ta) => specificRemB.any((tb) => _sharesPrefix(ta, tb, minPrefix: 4)),
      );
      if (!isPrefixTruncation) {
        return math.min(r12, defaultThreshold - 1);
      }
      return r12;
    }

    // Ako jedna strana ima dodatne specifične tokene (podskupna relacija),
    // dozvoli podskupno spajanje samo kada:
    // - uopšte nema dodatnih specifičnih tokena (svi dodatni su generički: npr. "Rosa" -> "Mineralna negazirana voda Rosa"), ILI
    // - presek već sadrži barem 2 specifična tokena, a ostatak najviše 1 token (npr. "Moja Kravica Mleko" -> "Imlek Moja Kravica Mleko").
    final maxSpecificRem = math.max(specificRemA.length, specificRemB.length);
    if (maxSpecificRem > 0) {
      if (specificIntersection.length >= 2 && maxSpecificRem == 1) {
        return math.max(r01Score(s0, s1, s2), r12);
      }
      return math.min(r12, defaultThreshold - 1);
    }

    final r01 = similarityRatio(s0, s1);
    final r02 = similarityRatio(s0, s2);

    return math.max(r01, math.max(r02, r12));
  }

  static int r01Score(String s0, String s1, String s2) {
    return math.max(similarityRatio(s0, s1), similarityRatio(s0, s2));
  }

  static bool _sharesPrefix(String a, String b, {required int minPrefix}) {
    final minLen = math.min(a.length, b.length);
    if (minLen < minPrefix) return false;
    return a.substring(0, minLen) == b.substring(0, minLen);
  }

  /// Pronalazi najboljeg kandidata iz liste kanonskih artikala čiji je skor
  /// veći ili jednak [threshold].
  static TokenMatchResult? findBestMatch(
    String cleanedKey,
    Iterable<CanonicalCandidate> candidates, {
    int threshold = defaultThreshold,
  }) {
    final a = cleanedKey.trim();
    if (a.isEmpty) return null;
    final listA = a.split(' ').where((t) => t.isNotEmpty).toList();
    if (listA.isEmpty) return null;

    CanonicalCandidate? bestCandidate;
    var bestScore = -1;

    for (final candidate in candidates) {
      final score = _tokenSetRatioFromLists(
        a,
        listA,
        candidate.canonicalKey,
        candidate.tokens,
      );
      if (score >= threshold && score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
        if (score == 100) break;
      }
    }

    if (bestCandidate == null) return null;
    return TokenMatchResult(candidate: bestCandidate, score: bestScore);
  }

  /// Normalizovana sličnost dva stringa u opsegu `[0, 100]` zasnovana na
  /// Levenshtein distanci: `round((len1 + len2 - dist) / (len1 + len2) * 100)`.
  static int similarityRatio(String s1, String s2) {
    if (s1 == s2) return 100;
    if (s1.isEmpty || s2.isEmpty) return 0;

    final dist = levenshteinDistance(s1, s2);
    final sumLen = s1.length + s2.length;
    final ratio = ((sumLen - dist) / sumLen) * 100.0;
    return ratio.round().clamp(0, 100);
  }

  /// Izračunava Levenshtein distancu između dva stringa u $O(\min(m, n))$ memorije.
  /// Ako je zadat [maxDistance], prekida izvršavanje čim minimalna moguća distanca
  /// u redu pređe zadatu granicu.
  static int levenshteinDistance(String s, String t, {int? maxDistance}) {
    if (s == t) return 0;
    var a = s;
    var b = t;
    if (a.length > b.length) {
      final tmp = a;
      a = b;
      b = tmp;
    }

    final m = a.length;
    final n = b.length;
    if (maxDistance != null && (n - m) > maxDistance) {
      return maxDistance + 1;
    }
    if (m == 0) return n;

    var prev = List<int>.generate(m + 1, (i) => i);
    var curr = List<int>.filled(m + 1, 0);

    for (var j = 1; j <= n; j++) {
      curr[0] = j;
      var rowMin = curr[0];
      final bChar = b.codeUnitAt(j - 1);

      for (var i = 1; i <= m; i++) {
        final cost = a.codeUnitAt(i - 1) == bChar ? 0 : 1;
        final deletion = prev[i] + 1;
        final insertion = curr[i - 1] + 1;
        final substitution = prev[i - 1] + cost;
        final val = math.min(deletion, math.min(insertion, substitution));
        curr[i] = val;
        if (val < rowMin) rowMin = val;
      }

      if (maxDistance != null && rowMin > maxDistance) {
        return maxDistance + 1;
      }

      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[m];
  }
}
