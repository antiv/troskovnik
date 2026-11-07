/// Deterministički normalizator naziva artikala sa fiskalnih računa (Sloj 1).
///
/// Izvršava se u čistom Dart-u bez spoljnih zavisnosti:
/// 1. Konverzija u mala slova i preslovljavanje srpske ćirilice u latinicu.
/// 2. Svođenje dijakritičkih znakova (č, ć, ž, š, đ) na ASCII ekvivalente.
/// 3. Regularna ekstrakcija i kanonizacija jedinica mere (1L, 0.5L, 500g, 2.8%mm).
/// 4. Uklanjanje internih PLU/SKU šifara trgovaca, interpunkcije i fiskalnih stop-reči.
/// 5. Ekspanzija ERP skraćenica i unifikacija ekavskih/ijekavskih oblika.
library;

class NormalizedItemResult {
  const NormalizedItemResult({
    required this.rawName,
    required this.cleanedKey,
    required this.orderedTokens,
    required this.suggestedDisplayName,
    this.extractedMeasure,
    this.allMeasures = const [],
  });

  /// Originalni neizmenjeni naziv sa fiskalnog računa.
  final String rawName;

  /// Kanonski ključ: abecedno sortirani, očišćeni ASCII tokeni spojeni razmakom
  /// (npr. `"imlek kravica mleko"`).
  final String cleanedKey;

  /// Očišćeni tokeni u prirodnom redosledu pojavljivanja.
  final List<String> orderedTokens;

  /// Predloženi čitljiv naziv za prikaz u UI-ju (npr. `"Imlek Mleko Kravica"`).
  final String suggestedDisplayName;

  /// Primarna izdvojena mera pakovanja (npr. `"1l"`, `"0.5l"`, `"500g"`),
  /// koristi se za razdvajanje gramaža kod praćenja cena i inflacije.
  final String? extractedMeasure;

  /// Sve izdvojene kvantitativne oznake (uključujući i % mlečne masti, npr. `["2.8%mm", "1l"]`).
  final List<String> allMeasures;
}

class ItemNormalizer {
  const ItemNormalizer._();

  /// Mapa za preslovljavanje srpske ćirilice u ASCII latinicu (mala slova).
  static const Map<String, String> _cyrillicToAscii = {
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'g',
    'д': 'd',
    'ђ': 'dj',
    'е': 'e',
    'ж': 'z',
    'з': 'z',
    'и': 'i',
    'ј': 'j',
    'к': 'k',
    'л': 'l',
    'љ': 'lj',
    'м': 'm',
    'н': 'n',
    'њ': 'nj',
    'о': 'o',
    'п': 'p',
    'р': 'r',
    'с': 's',
    'т': 't',
    'ћ': 'c',
    'у': 'u',
    'ф': 'f',
    'х': 'h',
    'ц': 'c',
    'ч': 'c',
    'џ': 'dz',
    'ш': 's',
  };

  /// Mapa za svođenje latiničnih dijakritika na ASCII.
  static const Map<String, String> _diacriticsToAscii = {
    'č': 'c',
    'ć': 'c',
    'ž': 'z',
    'š': 's',
    'đ': 'dj',
  };

  /// Regularni izraz za uklanjanje fiskalnih poreskih oznaka u zagradama, npr. "(Ђ)", "(Е)", "(А)".
  static final RegExp _fiscalTaxLabelRegex = RegExp(
    r'\(\s*[абвгдђежзијклљмнњопрстћуфхцчџшa-z]\s*\)',
    caseSensitive: false,
  );

  /// Regularni izraz za izdvajanje kvantitativnih atributa (zapremina, težina, % masti, komadi/slojevi).
  /// Podržava i višestruka pakovanja poput `6x0.5l`, spojene mere poput `Water1,25l` ili `2,5lx`,
  /// kao i pojedinačne mere `1l`, `500g`, `2.8%mm`, `60kom`, `3sl`.
  static final RegExp _measureRegex = RegExp(
    r'(?:(\d+)\s*[xX*]\s*)?(\d+(?:[.,]\d+)?)\s*(l|ml|dl|cl|kg|g|gr|mg|%\s*mm|%|kom|sl)(?:[xX]\b|\b)',
    caseSensitive: false,
  );

  /// Decimalne zapremine pića na računima kafića/restorana/prodavnica bez upisanog "l"
  /// (npr. "Rosa 0,75", "Coca Cola Zero 0.25", "Limunada 0,3", "Coca-Cola 1,5").
  static final RegExp _bareLiterVolumeRegex = RegExp(
    r'\b(0[.,](?:03|05|1|15|2|20|25|3|30|33|35|4|5|50|7|70|75)|1[.,](?:25|5|50|75)|2[.,](?:0|25|5|50))\b',
  );

  /// Alfanumeričke interne šifre artikala sa 4 ili više cifara (npr. "K000010000002", "38511_GRN").
  static final RegExp _alphaNumSkuRegex = RegExp(r'\b[a-z]*\d{4,}[a-z0-9_]*\b');

  /// Višecifrene interne PLU/SKU ili EAN šifre trgovaca (3 ili više cifara).
  static final RegExp _pluCodeRegex = RegExp(r'\b\d{3,}\b');

  /// Samostalni brojevi ili oznake komada (npr. "1x", "01", "2").
  static final RegExp _standaloneNumberRegex = RegExp(r'\b\d+[xX]?\b');

  /// Fiskalne stop-reči koje ne nose semantičku vrednost za identifikaciju artikla.
  static const Set<String> stopWords = {
    'pet',
    'lim',
    'limenka',
    'tt',
    'tetra',
    'tetrapak',
    'tb',
    'pct',
    'pak',
    'pakovanje',
    'kom',
    'komad',
    'por',
    'porcija',
    'kg',
    'gr',
    'mg',
    'ml',
    'dl',
    'cl',
    'rinfuz',
    'rinf',
    'rfz',
    'akcija',
    'akc',
    'popust',
    'artikal',
    'art',
    'pov',
    'povratna',
    'staklo',
    'st',
    'stk',
    'kesica',
    'kut',
    'kutija',
    'fl',
    'flasa',
    'boca',
    'pvc',
    'folija',
    'amb',
    'ambalaza',
    'gratis',
    'novo',
    'xxl',
    'promo',
    'cena',
    'redovna',
    'osnovna',
    'nep',
    'nepovratna',
    'doz',
    'dozna',
    'tegla',
    'casa',
    'kantica',
    'od',
    'za',
    'u',
    'na',
    'po',
    'do',
    'iz',
    'i',
  };

  /// Statička mapa ERP skraćenica i ekavsko-ijekavskih varijacija u kanonski oblik.
  static const Map<String, String> abbreviationAndDialectMap = {
    // Mlečni proizvodi
    'ml': 'mleko',
    'mlk': 'mleko',
    'mlijeko': 'mleko',
    'mljeko': 'mleko',
    'dug': 'dugotrajno',
    'svj': 'sveze',
    'svjeze': 'sveze',
    'svjezi': 'sveze',
    'svjeza': 'sveze',
    'jog': 'jogurt',
    'jogrt': 'jogurt',
    'jogurta': 'jogurt',
    'pavl': 'pavlaka',
    'kis': 'kisela',
    'kiselo': 'kisela',
    'masl': 'maslac',
    'marg': 'margarin',
    'kravi': 'kravica',
    'olymp': 'olympus',
    // Pekara i osnovne namirnice
    'hljeb': 'hleb',
    'hlb': 'hleb',
    'bijeli': 'beli',
    'bijelo': 'beli',
    'crn': 'crni',
    'bras': 'brasno',
    'sec': 'secer',
    'ulj': 'ulje',
    'sunc': 'suncokretovo',
    'suncokret': 'suncokretovo',
    'barill': 'barilla',
    'ekstr': 'ekstra',
    // Slatkiši i grickalice
    'cok': 'cokolada',
    'cokol': 'cokolada',
    'cokolad': 'cokolada',
    'mlijecna': 'mlecna',
    'mljecna': 'mlecna',
    'ljesnik': 'lesnik',
    'ljesnjak': 'lesnik',
    'star': 'stark',
    // Pića i kafa
    'gaz': 'gazirani',
    'gazirano': 'gazirani',
    'negaz': 'negazirana',
    'negazirano': 'negazirana',
    'ng': 'negazirana',
    'min': 'mineralna',
    'mineral': 'mineralna',
    'vod': 'voda',
    'koka': 'coca',
    'kola': 'cola',
    'kava': 'kafa',
    'kafe': 'kafa',
    'kapsula': 'kapsule',
    'ins': 'instant',
    'inst': 'instant',
    'clas': 'classic',
    'schweppess': 'schweppes',
    'mlj': 'mlevena',
    'mljev': 'mlevena',
    'mljevena': 'mlevena',
    'svijetlo': 'svetlo',
    // Meso, voće i povrće
    'pil': 'pileci',
    'pilece': 'pileci',
    'pileca': 'pileci',
    'svinj': 'svinjski',
    'svinjsko': 'svinjski',
    'svinjska': 'svinjski',
    'jun': 'juneci',
    'junece': 'juneci',
    'juneca': 'juneci',
    'mljeveno': 'mleveno',
    'past': 'pasteta',
    'tikvice': 'tikvica',
    // Kućna hemija, kozmetika i usluge
    'det': 'deterdzent',
    'deterdz': 'deterdzent',
    'omeks': 'omeksivac',
    'toal': 'toalet',
    'toaletni': 'toalet',
    'pap': 'papir',
    'samp': 'sampon',
    'sap': 'sapun',
    'tec': 'tecni',
    'tac': 'tecni',
    'dostave': 'dostava',
    'dostavu': 'dostava',
    'parkiranja': 'parkiranje',
    'usluge': 'usluga',
  };

  /// Rečnik za lepo formatiranje poznatih reči sa dijakriticima u `suggestedDisplayName`.
  static const Map<String, String> _prettyWordMap = {
    'cokolada': 'Čokolada',
    'cokoladna': 'Čokoladna',
    'mlecna': 'Mlečna',
    'secer': 'Šećer',
    'brasno': 'Brašno',
    'psenicno': 'Pšenično',
    'sveze': 'Sveže',
    'pileci': 'Pileći',
    'juneci': 'Juneći',
    'pasteta': 'Pašteta',
    'kecap': 'Kečap',
    'zacin': 'Začin',
    'deterdzent': 'Deterdžent',
    'omeksivac': 'Omekšivač',
    'sampon': 'Šampon',
    'tecni': 'Tečni',
    'lesnik': 'Lešnik',
    'stark': 'Štark',
    'knjaz': 'Knjaz',
    'milos': 'Miloš',
    'zajecarsko': 'Zaječarsko',
    'niksicko': 'Nikšićko',
    'banjalucko': 'Banjalučko',
    'sabacka': 'Šabačka',
    'grcki': 'Grčki',
    'sopska': 'Šopska',
    'coca': 'Coca',
    'cola': 'Cola',
    'bmb95': 'BMB 95',
    'bmb98': 'BMB 98',
    'bmb100': 'BMB 100',
  };

  /// Pretvara string u mala ASCII slova (preslovljava ćirilicu i uklanja dijakritike).
  static String toAsciiLower(String input) {
    final lower = input.toLowerCase();
    final sb = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      final cyr = _cyrillicToAscii[ch];
      if (cyr != null) {
        sb.write(cyr);
        continue;
      }
      final dia = _diacriticsToAscii[ch];
      if (dia != null) {
        sb.write(dia);
        continue;
      }
      sb.write(ch);
    }
    return sb.toString();
  }

  /// Normalizuje sirovi naziv artikla sa računa.
  static NormalizedItemResult normalize(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return const NormalizedItemResult(
        rawName: '',
        cleanedKey: '',
        orderedTokens: [],
        suggestedDisplayName: '',
      );
    }

    // 0. Ukloni fiskalne poreske oznake u zagradama poput "(Ђ)", "(Е)", "(А)" pre preslovljavanja.
    final withoutTaxLabel = trimmed.replaceAll(_fiscalTaxLabelRegex, ' ');

    // 1. Konverzija u mala slova + ćirilica -> latinica + skidanje dijakritika.
    var work = toAsciiLower(withoutTaxLabel);

    // Specijalna normalizacija za brašno (tip 400/500/850), gorivo (BMB 95/100) i modele telefona (iPhone 17).
    work = work.replaceAllMapped(
      RegExp(r'\b(?:tip|t)[\s\-]*(400|500|850)\b'),
      (m) => 'tip${m.group(1)}',
    );
    work = work.replaceAllMapped(
      RegExp(r'\bbmb[\s\-]*(95|98|100)\b'),
      (m) => 'bmb${m.group(1)}',
    );
    work = work.replaceAllMapped(
      RegExp(r'\biphone[\s\-]*(\d{1,2})\b'),
      (m) => 'iphone${m.group(1)}',
    );

    // 2. Ekstrakcija kvantitativnih atributa (zapremina, masa, % masti, komadi).
    final allMeasures = <String>[];
    String? primaryPackageMeasure;

    work = work.replaceAllMapped(_measureRegex, (match) {
      final multStr = match.group(1);
      final valStr = match.group(2)!.replaceAll(',', '.');
      final rawUnit = match.group(3)!.replaceAll(RegExp(r'\s+'), '').toLowerCase();

      final canonicalMeasure = _canonicalizeMeasure(
        multiplier: multStr != null ? int.tryParse(multStr) : null,
        value: double.tryParse(valStr),
        rawValueStr: valStr,
        unit: rawUnit,
      );
      allMeasures.add(canonicalMeasure);

      final isSecondary = rawUnit.startsWith('%') || rawUnit == 'sl' || rawUnit == 'kom';
      if (!isSecondary && primaryPackageMeasure == null) {
        primaryPackageMeasure = canonicalMeasure;
      }
      return ' ';
    });

    // 2b. Ako nema eksplicitne jedinice mere, proveri decimalne zapremine pića (0.25, 0.33, 0.5, 0.75, 1.5...).
    work = work.replaceAllMapped(_bareLiterVolumeRegex, (match) {
      final valStr = match.group(1)!.replaceAll(',', '.');
      final canonicalMeasure = _canonicalizeMeasure(
        value: double.tryParse(valStr),
        rawValueStr: valStr,
        unit: 'l',
      );
      allMeasures.add(canonicalMeasure);
      primaryPackageMeasure ??= canonicalMeasure;
      return ' ';
    });

    // 3. Uklanjanje alfanumeričkih SKU šifara, višecifrenih PLU šifara i samostalnih brojeva.
    work = work.replaceAll(_alphaNumSkuRegex, ' ');
    work = work.replaceAll(_pluCodeRegex, ' ');
    work = work.replaceAll(_standaloneNumberRegex, ' ');

    // 4. Uklanjanje interpunkcije (sve što nije slovo ili cifra postaje razmak).
    work = work.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

    // 5. Tokenizacija, ekspanzija skraćenica/dijalekata i filtriranje stop-reči.
    final rawTokens = work
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final expandedTokens = <String>[];
    for (final token in rawTokens) {
      if (stopWords.contains(token)) continue;
      final mapped = abbreviationAndDialectMap[token] ?? token;
      if (stopWords.contains(mapped)) continue;
      // Preskoči jednoslovne šumove osim poznatih oznaka (npr. "c" za Začin C).
      if (mapped.length == 1 && mapped != 'c') continue;
      expandedTokens.add(mapped);
    }

    // Fallback ukoliko su svi tokeni bili stop-reči ili brojevi (npr. "KESA" ili "12345").
    if (expandedTokens.isEmpty) {
      final fallbackTokens = toAsciiLower(trimmed)
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      if (fallbackTokens.isEmpty) {
        return NormalizedItemResult(
          rawName: rawName,
          cleanedKey: trimmed.toLowerCase(),
          orderedTokens: [trimmed.toLowerCase()],
          suggestedDisplayName: trimmed,
          extractedMeasure: primaryPackageMeasure,
          allMeasures: allMeasures,
        );
      }
      expandedTokens.addAll(fallbackTokens);
    }

    // Deduplikacija uz očuvanje prirodnog redosleda za prikaz.
    final orderedUnique = <String>[];
    final seen = <String>{};
    for (final t in expandedTokens) {
      if (seen.add(t)) {
        orderedUnique.add(t);
      }
    }

    // Abecedno sortirani tokeni za kanonski ključ.
    final sortedTokens = [...orderedUnique]..sort();
    final cleanedKey = sortedTokens.join(' ');

    final displayName = _buildDisplayName(trimmed, orderedUnique);

    return NormalizedItemResult(
      rawName: rawName,
      cleanedKey: cleanedKey,
      orderedTokens: orderedUnique,
      suggestedDisplayName: displayName,
      extractedMeasure: primaryPackageMeasure,
      allMeasures: allMeasures,
    );
  }

  /// Kanonizuje jedinicu mere tako da se npr. `500ml`, `0,5l` i `0.50l` svode na `"0.5l"`,
  /// a `1000g` i `1000gr` na `"1kg"`.
  static String _canonicalizeMeasure({
    int? multiplier,
    double? value,
    required String rawValueStr,
    required String unit,
  }) {
    if (value == null) {
      return '$rawValueStr$unit';
    }

    var normVal = value;
    var normUnit = unit;

    if (normUnit == 'gr') {
      normUnit = 'g';
    } else if (normUnit == '%mm') {
      normUnit = '%mm';
    }

    // Konverzija ml/dl/cl u l za standardna pakovanja (>= 100ml).
    if (normUnit == 'ml' && normVal >= 100) {
      normVal = normVal / 1000.0;
      normUnit = 'l';
    } else if (normUnit == 'dl') {
      normVal = normVal / 10.0;
      normUnit = 'l';
    } else if (normUnit == 'cl') {
      normVal = normVal / 100.0;
      normUnit = 'l';
    } else if (normUnit == 'g' && normVal >= 1000 && normVal % 250 == 0) {
      normVal = normVal / 1000.0;
      normUnit = 'kg';
    }

    final formattedVal = _formatNumber(normVal);
    final prefix = (multiplier != null && multiplier > 1) ? '${multiplier}x' : '';
    return '$prefix$formattedVal$normUnit';
  }

  static String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    var s = val.toStringAsFixed(3);
    while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
      if (s.endsWith('.')) {
        s = s.substring(0, s.length - 1);
        break;
      }
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static String _buildDisplayName(String originalTrimmed, List<String> orderedTokens) {
    // Ako je ulaz već bio jednostavan čitljiv naziv (npr. "Mleko", "Hleb", "Sijalica")
    // sa mešovitim velikim/malim slovima i bez šuma, zadrži lepu formu.
    final prettyWords = orderedTokens.map((token) {
      final known = _prettyWordMap[token];
      if (known != null) return known;
      if (token.startsWith('tip') && token.length > 3) {
        return 'T-${token.substring(3)}';
      }
      return _capitalize(token);
    }).toList();

    if (prettyWords.isEmpty) return originalTrimmed;

    // Ako prva reč ima malo slovo u sredini rečenice, kapitalizuj samo prvu reč
    // ili brendove, a ostale ostavi prirodno. Za konzistentnost u listi artikala,
    // svaka reč u kanonskom nazivu počinje velikim slovom (Title Case) osim veznika.
    const connectors = {'za', 'u', 'sa', 'od', 'bez', 'i'};
    final result = <String>[];
    for (var i = 0; i < prettyWords.length; i++) {
      final w = prettyWords[i];
      final lower = w.toLowerCase();
      if (i > 0 && connectors.contains(lower)) {
        result.add(lower);
      } else {
        result.add(w);
      }
    }
    return result.join(' ');
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    if (s.length == 1) return s.toUpperCase();
    return s[0].toUpperCase() + s.substring(1);
  }
}
