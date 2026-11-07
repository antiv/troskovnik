// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:troskovnik/core/normalization/item_normalizer.dart';
import 'package:troskovnik/core/normalization/seed_items_data.dart';
import 'package:troskovnik/core/normalization/token_set_matcher.dart';

/// Skripta za generisanje proširenog `assets/data/seed_items.json` i
/// `lib/core/normalization/seed_items_data.dart` kombinovanjem:
/// 1. Kuriranog regionalnog kataloga (SRB, MNE, BiH/RS) za prehranu, piće,
///    kućnu hemiju, kozmetiku, gorivo i pekaru (sa ERP skraćenicama sa traka).
/// 2. Javnih podataka sa Open Food Facts API-ja (`world.openfoodfacts.org`, ODbL)
///    za Srbiju, Bosnu i Hercegovinu i Crnu Goru, sortiranih po popularnosti.
///
/// Pokretanje:
///   .fvm/flutter_sdk/bin/dart run tool/generate_seed_items.dart
Future<void> main() async {
  print('1. Učitavanje baznog kuriranog kataloga za SRB / MNE / BiH...');
  final baseEntries = _buildComprehensiveRegionalCatalog();
  print('   Bazni katalog: ${baseEntries.length} kanonskih proizvoda.');

  final byCanonicalKey = <String, _MutableSeedEntry>{};

  void addOrMerge(String rawCanonicalKey, String displayName, List<String> rawAliases) {
    final normKey = ItemNormalizer.normalize(rawCanonicalKey).cleanedKey;
    final key = normKey.isNotEmpty ? normKey : rawCanonicalKey.trim().toLowerCase();
    if (key.isEmpty) return;

    final existing = byCanonicalKey[key];
    final target = existing ??
        byCanonicalKey.putIfAbsent(
          key,
          () => _MutableSeedEntry(canonicalKey: key, displayName: displayName),
        );

    target.aliases.add(key);
    final normDisplay = ItemNormalizer.normalize(displayName).cleanedKey;
    if (normDisplay.isNotEmpty) {
      target.aliases.add(normDisplay);
    }
    for (final a in rawAliases) {
      final na = ItemNormalizer.normalize(a).cleanedKey;
      if (na.isNotEmpty) {
        target.aliases.add(na);
      }
    }
  }

  for (final e in baseEntries) {
    addOrMerge(e.canonicalKey, e.displayName, e.aliases);
  }

  print('2. Preuzimanje najpopularnijih artikala sa Open Food Facts API-ja (SRB, BiH, MNE)...');
  final offEntries = await _fetchOpenFoodFactsRegional();
  print('   Preuzeto i filtrirano sa Open Food Facts-a: ${offEntries.length} kandidata.');

  var addedFromOff = 0;
  for (final off in offEntries) {
    final normKey = ItemNormalizer.normalize(off.canonicalKey).cleanedKey;
    if (normKey.isEmpty || normKey.length < 4) continue;
    if (byCanonicalKey.containsKey(normKey)) {
      byCanonicalKey[normKey]!.aliases.addAll(
            off.aliases
                .map((a) => ItemNormalizer.normalize(a).cleanedKey)
                .where((a) => a.isNotEmpty),
          );
      continue;
    }

    // Proveri da li već postoji veoma sličan kanonski artikal u katalogu.
    final candidates = [
      for (final e in byCanonicalKey.values)
        CanonicalCandidate(
          id: 1,
          canonicalKey: e.canonicalKey,
          displayName: e.displayName,
        ),
    ];
    final match = TokenSetMatcher.findBestMatch(normKey, candidates, threshold: 88);
    if (match != null) {
      final target = byCanonicalKey[match.candidate.canonicalKey]!;
      target.aliases.add(normKey);
      for (final a in off.aliases) {
        final na = ItemNormalizer.normalize(a).cleanedKey;
        if (na.isNotEmpty) target.aliases.add(na);
      }
    } else {
      addOrMerge(normKey, off.displayName, off.aliases);
      addedFromOff++;
    }
  }

  print('   Dodato novih kanonskih artikala iz Open Food Facts-a: $addedFromOff.');

  final finalEntries = byCanonicalKey.values.toList();
  final totalAliases =
      finalEntries.fold<int>(0, (sum, e) => sum + e.aliases.length);
  print('3. Ukupno: ${finalEntries.length} kanonskih artikala i $totalAliases alijasa.');

  // Upis u assets/data/seed_items.json
  final jsonMap = {
    'version': 2,
    'description':
        'Prošireni kanonski šifarnik artikala za Srbiju (SRB), Crnu Goru (MNE) i BiH / Republiku Srpsku (RS) — kurirani katalog + Open Food Facts (ODbL)',
    'items': [
      for (final e in finalEntries)
        {
          'canonicalKey': e.canonicalKey,
          'displayName': e.displayName,
          'aliases': (e.aliases.toList()..sort()),
        },
    ],
  };

  final jsonFile = File('assets/data/seed_items.json');
  await jsonFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(jsonMap)}\n',
  );
  print('   Sačuvan assets/data/seed_items.json (${await jsonFile.length()} bajtova).');

  // Upis u lib/core/normalization/seed_items_data.dart
  await _writeSeedItemsDartFile(finalEntries);
  print('   Sačuvan lib/core/normalization/seed_items_data.dart.');
}

class _MutableSeedEntry {
  _MutableSeedEntry({
    required this.canonicalKey,
    required this.displayName,
  });

  final String canonicalKey;
  final String displayName;
  final Set<String> aliases = <String>{};
}

/// Preuzima najčešće skenirane proizvode iz Open Food Facts baze za SRB, BiH i MNE.
Future<List<SeedItemEntry>> _fetchOpenFoodFactsRegional() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);
  final countries = ['serbia', 'bosnia-and-herzegovina', 'montenegro'];
  final results = <SeedItemEntry>[];

  for (final country in countries) {
    for (var page = 1; page <= 3; page++) {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/search'
        '?countries_tags_en=$country'
        '&sort_by=unique_scans_n'
        '&page_size=100'
        '&page=$page'
        '&fields=product_name,product_name_sr,product_name_bs,product_name_hr,brands',
      );
      try {
        final req = await client.getUrl(uri);
        req.headers.set(
          HttpHeaders.userAgentHeader,
          'TroskovnikApp/1.0 (https://github.com/antiv/troskovnik; OpenSource)',
        );
        final resp = await req.close().timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) break;
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>? ?? const [];
        if (products.isEmpty) break;

        for (final p in products) {
          final map = p as Map<String, dynamic>;
          final entry = _cleanOffProduct(map);
          if (entry != null) {
            results.add(entry);
          }
        }
      } catch (e) {
        print('   [Upozorenje] OFF zahtev za $country (str. $page) nije uspeo: $e');
        break;
      }
    }
  }
  client.close(force: true);
  return results;
}

/// Čisti i validira proizvod iz Open Food Facts baze (odbacuje strane jezike i šum).
SeedItemEntry? _cleanOffProduct(Map<String, dynamic> map) {
  final rawBrand = (map['brands'] as String? ?? '').split(',').first.trim();
  final rawNameSr = (map['product_name_sr'] as String? ?? '').trim();
  final rawNameBs = (map['product_name_bs'] as String? ?? '').trim();
  final rawNameHr = (map['product_name_hr'] as String? ?? '').trim();
  final rawNameDefault = (map['product_name'] as String? ?? '').trim();

  final chosenName = rawNameSr.isNotEmpty
      ? rawNameSr
      : (rawNameBs.isNotEmpty
          ? rawNameBs
          : (rawNameHr.isNotEmpty ? rawNameHr : rawNameDefault));

  if (chosenName.isEmpty) return null;

  // Odbaci strane nazive (francuski, nemački, španski, engleski marketing opisi iz OFF-a)
  final lowerCheck = '$rawBrand $chosenName'.toLowerCase();
  const foreignMarkers = [
    'saveur',
    'sans ',
    'sucre',
    'avec ',
    'boisson',
    'fromage',
    'lait ',
    'chocolat ',
    'biscuit ',
    'fresh baked',
    'flavour',
    'flavored',
    'sparkling',
    'roasted',
    'salted',
    'wholegrain',
    'sweetened',
    'kunststoff',
    'getränk',
    'geschmack',
    'sabor',
    'bebida',
    'gout ',
    'goût',
  ];
  for (final marker in foreignMarkers) {
    if (lowerCheck.contains(marker)) return null;
  }

  final normBrand = ItemNormalizer.normalize(rawBrand);
  final normName = ItemNormalizer.normalize(chosenName);
  if (normName.orderedTokens.isEmpty) return null;

  // Ako je naziv predugačak (> 4 tokena), preskoči jer je verovatno pun opis sastojaka
  if (normName.orderedTokens.length > 4) return null;

  // Ignoriši korporativne sufikse u brendu (npr. "AD PLANINKA", "COCA-COLA HBC")
  final brandTokens = normBrand.orderedTokens
      .where((t) =>
          t.length >= 3 &&
          !const {'srbija', 'beograd', 'doo', 'group', 'company', 'services', 'hbc', 'planinka', 'swisslion', 'atlantic', 'marbo', 'nestle', 'ferrero', 'mondelez', 'unilever', 'henkel', 'pepsico'}
              .contains(t))
      .take(2)
      .toList();

  final combinedTokens = <String>{
    ...brandTokens,
    ...normName.orderedTokens,
  }.toList();

  if (combinedTokens.isEmpty || combinedTokens.length > 5) return null;
  // Mora imati bar jedan specifičan (ne-generički) token
  final hasSpecific = combinedTokens
      .any((t) => !TokenSetMatcher.genericTokens.contains(t) && t.length >= 3);
  if (!hasSpecific) return null;

  final fullRaw = brandTokens.isNotEmpty &&
          !normName.cleanedKey.contains(brandTokens.first)
      ? '$rawBrand $chosenName'
      : chosenName;
  final normFull = ItemNormalizer.normalize(fullRaw);
  if (normFull.cleanedKey.isEmpty) return null;

  final display = normFull.suggestedDisplayName;
  if (display.length < 3 || display.length > 38) return null;

  final aliases = <String>{
    normFull.cleanedKey,
    normName.cleanedKey,
  };

  return SeedItemEntry(
    canonicalKey: normFull.cleanedKey,
    displayName: display,
    aliases: aliases.toList(),
  );
}

Future<void> _writeSeedItemsDartFile(List<_MutableSeedEntry> entries) async {
  final buf = StringBuffer()
    ..writeln("import 'dart:convert';")
    ..writeln()
    ..writeln('class SeedItemEntry {')
    ..writeln('  const SeedItemEntry({')
    ..writeln('    required this.canonicalKey,')
    ..writeln('    required this.displayName,')
    ..writeln('    this.aliases = const [],')
    ..writeln('  });')
    ..writeln()
    ..writeln('  final String canonicalKey;')
    ..writeln('  final String displayName;')
    ..writeln('  final List<String> aliases;')
    ..writeln()
    ..writeln('  factory SeedItemEntry.fromJson(Map<String, dynamic> json) {')
    ..writeln("    final rawAliases = json['aliases'] as List<dynamic>? ?? const [];")
    ..writeln('    return SeedItemEntry(')
    ..writeln("      canonicalKey: json['canonicalKey'] as String,")
    ..writeln("      displayName: json['displayName'] as String,")
    ..writeln('      aliases: [for (final a in rawAliases) a as String],')
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Učitava početni (seed) rečnik artikala (`assets/data/seed_items.json`).')
    ..writeln('class SeedItemsLoader {')
    ..writeln('  const SeedItemsLoader._();')
    ..writeln()
    ..writeln("  static const String assetPath = 'assets/data/seed_items.json';")
    ..writeln()
    ..writeln('  static Future<List<SeedItemEntry>> load() async {')
    ..writeln('    return defaultSeedEntries;')
    ..writeln('  }')
    ..writeln()
    ..writeln('  static List<SeedItemEntry> parseJson(String rawJson) {')
    ..writeln('    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;')
    ..writeln("    final list = decoded['items'] as List<dynamic>? ?? const [];")
    ..writeln('    return [')
    ..writeln('      for (final item in list)')
    ..writeln('        SeedItemEntry.fromJson(item as Map<String, dynamic>),')
    ..writeln('    ];')
    ..writeln('  }')
    ..writeln()
    ..writeln('  static const List<SeedItemEntry> defaultSeedEntries = [');

  for (final e in entries) {
    final sortedAliases = e.aliases.toList()..sort();
    buf
      ..writeln('    SeedItemEntry(')
      ..writeln('      canonicalKey: ${_dartStr(e.canonicalKey)},')
      ..writeln('      displayName: ${_dartStr(e.displayName)},')
      ..writeln('      aliases: [');
    for (final a in sortedAliases) {
      buf.writeln('        ${_dartStr(a)},');
    }
    buf
      ..writeln('      ],')
      ..writeln('    ),');
  }

  buf
    ..writeln('  ];')
    ..writeln('}');

  await File('lib/core/normalization/seed_items_data.dart')
      .writeAsString(buf.toString());
}

String _dartStr(String s) {
  final escaped = s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  return "'$escaped'";
}

/// Sveobuhvatni kurirani katalog za SRB, MNE i BiH/RS.
List<SeedItemEntry> _buildComprehensiveRegionalCatalog() {
  return [
    ...SeedItemsLoader.defaultSeedEntries,

    // =========================================================================
    // MLEČNI PROIZVODI (SRB, MNE, BiH)
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'imlek kravica maslac moja',
      displayName: 'Maslac Moja Kravica',
      aliases: ['kravica maslac', 'maslac moja kravica', 'imlek maslac', 'kravica puter'],
    ),
    const SeedItemEntry(
      canonicalKey: 'imlek kravica moja sir sitni',
      displayName: 'Sitni sir Moja Kravica',
      aliases: ['kravica sitni sir', 'moja kravica sitni sir', 'imlek sitni sir'],
    ),
    const SeedItemEntry(
      canonicalKey: 'bela imlek kravica moja sir',
      displayName: 'Beli sir Moja Kravica',
      aliases: ['kravica beli sir', 'moja kravica beli sir', 'kriška sira moja kravica'],
    ),
    const SeedItemEntry(
      canonicalKey: 'imlek kravica mleko moja cokoladno',
      displayName: 'Čokoladno mleko Moja Kravica',
      aliases: ['cokoladno kravica mleko', 'cokoladno kravica mleko moja', 'imlek cokoladno mleko'],
    ),
    const SeedItemEntry(
      canonicalKey: 'imlek kravica kuhinjica moja pavlaka',
      displayName: 'Pavlaka za kuvanje Moja Kravica',
      aliases: ['kravica pavlaka za kuvanje', 'kuhinjica pavlaka za kuvanje', 'moja kravica pavlaka za kuvanje'],
    ),
    const SeedItemEntry(
      canonicalKey: 'imlek jogurt Bello organic',
      displayName: 'Bello Organic Jogurt',
      aliases: ['bello jogurt', 'imlek bello jogurt'],
    ),
    const SeedItemEntry(
      canonicalKey: 'grekos imlek jogurt',
      displayName: 'Grekos Grčki jogurt',
      aliases: ['grekos jogurt', 'grcki jogurt grekos', 'imlek grekos'],
    ),
    const SeedItemEntry(
      canonicalKey: 'imlek kefir kravica moja',
      displayName: 'Kefir Moja Kravica',
      aliases: ['kravica kefir', 'moja kravica kefir', 'imlek kefir'],
    ),
    const SeedItemEntry(
      canonicalKey: 'flert imlek kafa',
      displayName: 'Flert Ledena kafa',
      aliases: ['flert ledena kafa', 'imlek flert'],
    ),
    const SeedItemEntry(
      canonicalKey: 'dukat mleko',
      displayName: 'Dukat Mleko',
      aliases: ['dukat mleko uht', 'dukat sveze mleko', 'dukat trajno mleko'],
    ),
    const SeedItemEntry(
      canonicalKey: 'dukat jogurt',
      displayName: 'Dukat Jogurt',
      aliases: ['dukat tekuci jogurt', 'dukat gusti jogurt'],
    ),
    const SeedItemEntry(
      canonicalKey: 'biser sir trapist',
      displayName: 'Sir Trapist Biser',
      aliases: ['biser trapist', 'trapist biser'],
    ),
    const SeedItemEntry(
      canonicalKey: 'gauda president sir',
      displayName: 'President Gauda sir',
      aliases: ['president gauda', 'gauda sir president'],
    ),
    const SeedItemEntry(
      canonicalKey: 'edamer president sir',
      displayName: 'President Edamer sir',
      aliases: ['president edamer', 'edamer sir president'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kajmak mlad zlatarski',
      displayName: 'Zlatarski sir / kajmak',
      aliases: ['zlatarski sir', 'zlatarski kajmak'],
    ),
    const SeedItemEntry(
      canonicalKey: 'ella sir',
      displayName: 'Ella Sir (Subotička mlekara)',
      aliases: ['ella posni sir', 'mlekara subotica ella sir', 'suboticka ella'],
    ),
    const SeedItemEntry(
      canonicalKey: 'ab kultura suboticka',
      displayName: 'AB Kultura Jogurt',
      aliases: ['ab jogurt', 'mlekara subotica ab jogurt'],
    ),
    const SeedItemEntry(
      canonicalKey: 'zdravo mleko suboticka',
      displayName: 'Zdravo! Mleko',
      aliases: ['zdravo mleko', 'zdravo jogurt'],
    ),
    const SeedItemEntry(
      canonicalKey: 'granice jogurt mlekara',
      displayName: 'Mlekara Granice Jogurt',
      aliases: ['granice jogurt', 'jogurt granice'],
    ),
    const SeedItemEntry(
      canonicalKey: 'granice mleko mlekara',
      displayName: 'Mlekara Granice Mleko',
      aliases: ['granice mleko', 'mleko granice'],
    ),
    const SeedItemEntry(
      canonicalKey: 'lazine jogurt mlekara',
      displayName: 'Lazine Jogurt (CG)',
      aliases: ['jogurt lazine', 'lazine kiselo mleko'],
    ),
    const SeedItemEntry(
      canonicalKey: 'lazine mleko mlekara',
      displayName: 'Lazine Mleko (CG)',
      aliases: ['mleko lazine'],
    ),
    const SeedItemEntry(
      canonicalKey: 'milgor mleko srna',
      displayName: 'Srna Mleko / Jogurt (CG)',
      aliases: ['srna jogurt', 'srna mleko'],
    ),
    const SeedItemEntry(
      canonicalKey: 'meggle mleko',
      displayName: 'Meggle Mleko',
      aliases: ['meggle mleko uht', 'meggle trajno mleko'],
    ),
    const SeedItemEntry(
      canonicalKey: 'meggle jogurt',
      displayName: 'Meggle Jogurt',
      aliases: ['meggle tekuci jogurt'],
    ),
    const SeedItemEntry(
      canonicalKey: 'meggle pavlaka',
      displayName: 'Meggle Pavlaka',
      aliases: ['meggle kisela pavlaka', 'meggle pavlaka za kuvanje'],
    ),
    const SeedItemEntry(
      canonicalKey: 'meggle maslac',
      displayName: 'Meggle Maslac',
      aliases: ['meggle puter', 'maslac meggle'],
    ),
    const SeedItemEntry(
      canonicalKey: 'vindija zbregov mleko',
      displayName: "'z bregov Mleko",
      aliases: ['zbregov mleko', 'vindija mleko', 'z bregov mleko'],
    ),
    const SeedItemEntry(
      canonicalKey: 'vindija zbregov jogurt',
      displayName: "'z bregov Jogurt",
      aliases: ['zbregov jogurt', 'vindija jogurt'],
    ),
    const SeedItemEntry(
      canonicalKey: 'vitalis jogurt vocni',
      displayName: 'Vitalis Voćni jogurt',
      aliases: ['vitalis jogurt', 'vocni jogurt vitalis'],
    ),
    const SeedItemEntry(
      canonicalKey: 'jogood jogurt vocni',
      displayName: 'Jogood Voćni jogurt',
      aliases: ['jogood imlek', 'imlek jogood', 'vocni jogurt jogood'],
    ),
    const SeedItemEntry(
      canonicalKey: 'pilos mleko',
      displayName: 'Pilos Mleko (Lidl)',
      aliases: ['pilos sveze mleko', 'pilos dugotrajno mleko', 'mleko pilos'],
    ),
    const SeedItemEntry(
      canonicalKey: 'pilos jogurt',
      displayName: 'Pilos Jogurt (Lidl)',
      aliases: ['jogurt pilos', 'pilos grcki jogurt'],
    ),
    const SeedItemEntry(
      canonicalKey: 'pilos pavlaka',
      displayName: 'Pilos Pavlaka (Lidl)',
      aliases: ['pavlaka pilos', 'pilos kisela pavlaka'],
    ),
    const SeedItemEntry(
      canonicalKey: 'pilos sir',
      displayName: 'Pilos Sir (Lidl)',
      aliases: ['sir pilos', 'pilos gauda', 'pilos edamer', 'pilos sitni sir', 'pilos beli sir'],
    ),
    const SeedItemEntry(
      canonicalKey: 'premia mleko',
      displayName: 'Premia Mleko (Maxi)',
      aliases: ['mleko premia', 'premia dugotrajno mleko'],
    ),
    const SeedItemEntry(
      canonicalKey: 'premia jogurt',
      displayName: 'Premia Jogurt (Maxi)',
      aliases: ['jogurt premia'],
    ),
    const SeedItemEntry(
      canonicalKey: 'k plus mleko',
      displayName: 'K Plus Mleko (Idea)',
      aliases: ['kplus mleko', 'mleko k plus'],
    ),

    // =========================================================================
    // PEKARA, HLEB I PECIVO
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'beli hleb rezani',
      displayName: 'Beli rezani hleb',
      aliases: ['hleb beli rezani', 'rezani beli hleb'],
    ),
    const SeedItemEntry(
      canonicalKey: 'hleb polubeli',
      displayName: 'Polubeli hleb',
      aliases: ['polubeli hleb'],
    ),
    const SeedItemEntry(
      canonicalKey: 'hleb integralni',
      displayName: 'Integralni hleb',
      aliases: ['integralni hleb', 'crni hleb'],
    ),
    const SeedItemEntry(
      canonicalKey: 'hleb kukuruzni',
      displayName: 'Kukuruzni hleb',
      aliases: ['kukuruzni hleb'],
    ),
    const SeedItemEntry(
      canonicalKey: 'baget francuski hleb',
      displayName: 'Francuski baget',
      aliases: ['baget', 'francuski hleb', 'hleb baget'],
    ),
    const SeedItemEntry(
      canonicalKey: 'lepinja somun',
      displayName: 'Somun / Lepinja',
      aliases: ['somun', 'lepinja', 'vruca lepinja', 'domaca lepinja'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kifla pecivo',
      displayName: 'Kifla',
      aliases: ['kifla', 'kifle', 'slana kifla', 'pekarska kifla'],
    ),
    const SeedItemEntry(
      canonicalKey: 'burek meso sa',
      displayName: 'Burek sa mesom',
      aliases: ['burek meso', 'burek s mesom'],
    ),
    const SeedItemEntry(
      canonicalKey: 'burek sa sirom',
      displayName: 'Burek sa sirom',
      aliases: ['burek sir', 'burek s sirom', 'pita sa sirom', 'sirnica'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kroasan pecivo',
      displayName: 'Kroasan',
      aliases: ['kroasan', 'croissant', 'kroasan cokolada', 'kroasan sunka sir'],
    ),
    const SeedItemEntry(
      canonicalKey: '7days kroasan',
      displayName: '7Days Kroasan',
      aliases: ['7 days kroasan', 'kroasan 7days', '7days kakao', '7days double'],
    ),
    const SeedItemEntry(
      canonicalKey: 'djevrek pecivo',
      displayName: 'Đevrek',
      aliases: ['djevrek', 'pekarski djevrek'],
    ),
    const SeedItemEntry(
      canonicalKey: 'pogacica cvarci',
      displayName: 'Pogačica / Žu-Žu',
      aliases: ['pogacica', 'zuzu pecivo', 'zu zu', 'lisnato pecivo'],
    ),
    const SeedItemEntry(
      canonicalKey: 'tortilja',
      displayName: 'Tortilja',
      aliases: ['tortilje', 'psenicna tortilja', 'mexican tortilja'],
    ),

    // =========================================================================
    // MESO, DELIKATES I RIBA
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'jetrena pasteta',
      displayName: 'Jetrena pašteta',
      aliases: ['pasteta jetrena'],
    ),
    const SeedItemEntry(
      canonicalKey: 'carnex cajna kobasica',
      displayName: 'Carnex Čajna kobasica',
      aliases: ['cajna kobasica carnex', 'carnex cajna'],
    ),
    const SeedItemEntry(
      canonicalKey: 'carnex virsle',
      displayName: 'Carnex Viršle',
      aliases: ['virsle carnex', 'carnex delikates virsle'],
    ),
    const SeedItemEntry(
      canonicalKey: 'carnex gotova jela pasulj',
      displayName: 'Carnex Gotovo jelo',
      aliases: ['carnex pasulj', 'carnex sarma', 'carnex gulas', 'carnex cufte'],
    ),
    const SeedItemEntry(
      canonicalKey: 'matijevic parizer',
      displayName: 'Matijević Parizer / Salamura',
      aliases: ['matijevic posebna', 'matijevic sunkarica', 'matijevic virsle'],
    ),
    const SeedItemEntry(
      canonicalKey: 'yuhor cajna kobasica',
      displayName: 'Yuhor Delikates / Kobasica',
      aliases: ['yuhor cajna', 'yuhor kulen', 'yuhor budimska', 'yuhor sunka'],
    ),
    const SeedItemEntry(
      canonicalKey: 'yuhor pasteta',
      displayName: 'Yuhor Pašteta',
      aliases: ['pasteta yuhor', 'yuhor jetrena pasteta', 'yuhor kokosija pasteta'],
    ),
    const SeedItemEntry(
      canonicalKey: 'neoplanta patelina pasteta',
      displayName: 'Patelina Pašteta (Neoplanta)',
      aliases: ['patelina pasteta', 'neoplanta pasteta', 'patelina kokosija'],
    ),
    const SeedItemEntry(
      canonicalKey: 'neoplanta delikates sunka',
      displayName: 'Neoplanta Delikates',
      aliases: ['neoplanta kulen', 'neoplanta cajna', 'neoplanta sunka', 'neoplanta kobasica'],
    ),
    const SeedItemEntry(
      canonicalKey: 'gavrilovic cajna pasteta',
      displayName: 'Gavrilović Pašteta / Zimska',
      aliases: ['gavrilovic pasteta', 'gavrilovic zimska', 'gavrilovic cajna', 'gavrilovic hrenovke'],
    ),
    const SeedItemEntry(
      canonicalKey: 'ovako parizer piletina',
      displayName: 'Ovako Piletina / Parizer (BiH)',
      aliases: ['ovako pileci parizer', 'ovako virsle', 'ovako pasteta', 'ovako piletina'],
    ),
    const SeedItemEntry(
      canonicalKey: 'goranovic kobasica sunka',
      displayName: 'Goranović Delikates (CG)',
      aliases: ['goranovic cajna', 'goranovic prsuta', 'goranovic slanina', 'goranovic parizer'],
    ),
    const SeedItemEntry(
      canonicalKey: 'martex prsuta',
      displayName: 'Martex Njeguška pršuta (CG)',
      aliases: ['njeguska prsuta', 'martex delikates'],
    ),
    const SeedItemEntry(
      canonicalKey: 'dimljena slanina panceta',
      displayName: 'Slanina / Pančeta',
      aliases: ['slanina', 'panceta', 'dimljena slanina', 'mesnata slanina'],
    ),
    const SeedItemEntry(
      canonicalKey: 'prsuta govedja svinjska',
      displayName: 'Pršuta / Pečenica',
      aliases: ['svinjska prsuta', 'govedja prsuta', 'pecenica', 'dimljena pecenica', 'suvi vrat'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kulen kobasica',
      displayName: 'Kulen',
      aliases: ['kulen', 'sremski kulen', 'domaci kulen'],
    ),
    const SeedItemEntry(
      canonicalKey: 'cajna kobasica',
      displayName: 'Čajna kobasica',
      aliases: ['cajna kobasica'],
    ),
    const SeedItemEntry(
      canonicalKey: 'sunka stisnjena pizza',
      displayName: 'Šunka u omotu / Pizza šunka',
      aliases: ['sunka u omotu', 'pizza sunka', 'stisnjena sunka', 'pileca prsa u omotu', 'cureca prsa'],
    ),
    const SeedItemEntry(
      canonicalKey: 'virsle hrenovke',
      displayName: 'Viršle / Hrenovke',
      aliases: ['virsle', 'pilece virsle', 'wudy virsle', 'perutnina ptuj virsle', 'poli virsle'],
    ),
    const SeedItemEntry(
      canonicalKey: 'parizer poli perutnina',
      displayName: 'Poli Pileći parizer',
      aliases: ['poli parizer', 'poli salama', 'perutnina poli'],
    ),
    const SeedItemEntry(
      canonicalKey: 'batak karabatak pileci',
      displayName: 'Pileći batak / karabatak',
      aliases: ['pileci batak', 'pileci karabatak', 'batak sa karabatakom', 'otkosteni batak'],
    ),
    const SeedItemEntry(
      canonicalKey: 'krilca pileca',
      displayName: 'Pileća krilca',
      aliases: ['pileca krilca', 'sveza pileca krilca'],
    ),
    const SeedItemEntry(
      canonicalKey: 'celo pile sveze',
      displayName: 'Sveže pile (celo)',
      aliases: ['sveze pile', 'pile gril', 'gril pile'],
    ),
    const SeedItemEntry(
      canonicalKey: 'krmenadla svinjska vrat',
      displayName: 'Svinjski vrat / Krmenadla',
      aliases: ['svinjski vrat', 'svinjska krmenadla', 'svinjska plecka', 'svinjska rebra'],
    ),
    const SeedItemEntry(
      canonicalKey: 'cevapi leskovacki sarajevski',
      displayName: 'Ćevapi / Pljeskavica',
      aliases: ['cevapi', 'cevapcici', 'pljeskavica', 'roštilj meso'],
    ),
    const SeedItemEntry(
      canonicalKey: 'eva sardina tunjevina',
      displayName: 'Eva Sardina / Tunjevina',
      aliases: ['eva sardine', 'eva tunjevina', 'podravka eva'],
    ),
    const SeedItemEntry(
      canonicalKey: 'calvo rio mare tunjevina',
      displayName: 'Rio Mare / Calvo Tunjevina',
      aliases: ['rio mare tunjevina', 'calvo tunjevina', 'tunjevina u ulju', 'tunjevina u salamuri', 'la perla tunjevina', 'il capitano tunjevina'],
    ),
    const SeedItemEntry(
      canonicalKey: 'oslic smrznuti riba',
      displayName: 'Smrznuti oslić / Fileti ribe',
      aliases: ['oslic bez glave', 'fileti oslica', 'oslic hoki'],
    ),

    // =========================================================================
    // VOĆE I POVRĆE (PIJACA / SUPERMARKET MERENJE)
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'banana voce',
      displayName: 'Banane',
      aliases: ['banana', 'banane', 'banana rinfuz'],
    ),
    const SeedItemEntry(
      canonicalKey: 'jabuka voce',
      displayName: 'Jabuke',
      aliases: ['jabuka', 'jabuke', 'jabuka ajdared', 'jabuka zlatni delises', 'jabuka grenismit', 'jabuka gala'],
    ),
    const SeedItemEntry(
      canonicalKey: 'limun voce',
      displayName: 'Limun',
      aliases: ['limun', 'limun rinfuz'],
    ),
    const SeedItemEntry(
      canonicalKey: 'pomorandza narandza',
      displayName: 'Pomorandže / Mandarine',
      aliases: ['pomorandza', 'pomorandze', 'narandza', 'mandarina', 'mandarine', 'klementina'],
    ),
    const SeedItemEntry(
      canonicalKey: 'krompir povrce',
      displayName: 'Krompir',
      aliases: ['krompir', 'beli krompir', 'crveni krompir', 'mladi krompir', 'krompir rinfuz'],
    ),
    const SeedItemEntry(
      canonicalKey: 'crni luk povrce',
      displayName: 'Crni / Beli luk',
      aliases: ['crni luk', 'luk crni', 'beli luk', 'mladi luk', 'crveni luk'],
    ),
    const SeedItemEntry(
      canonicalKey: 'paradajz povrce',
      displayName: 'Paradajz',
      aliases: ['paradajz', 'paradajz rinfuz', 'ceri paradajz', 'cherry paradajz', 'pink paradajz'],
    ),
    const SeedItemEntry(
      canonicalKey: 'krastavac povrce',
      displayName: 'Krastavac',
      aliases: ['krastavac', 'krastavci', 'salatni krastavac', 'kornisoni'],
    ),
    const SeedItemEntry(
      canonicalKey: 'paprika povrce',
      displayName: 'Paprika',
      aliases: ['paprika', 'paprika babura', 'paprika crvena', 'paprika silja', 'ljuta paprika'],
    ),
    const SeedItemEntry(
      canonicalKey: 'sargarepa mrkva',
      displayName: 'Šargarepa',
      aliases: ['sargarepa', 'mrkva', 'sargarepa rinfuz'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kupus zelena salata',
      displayName: 'Kupus / Zelena salata',
      aliases: ['kupus', 'mladi kupus', 'kiseli kupus', 'zelena salata', 'iceberg salata'],
    ),
    const SeedItemEntry(
      canonicalKey: 'sampinjoni pecurke',
      displayName: 'Šampinjoni',
      aliases: ['sampinjoni', 'pecurke sampinjoni'],
    ),

    // =========================================================================
    // OSNOVNE NAMIRNICE, TESTENINA, ZAČINI I ZIMNICA
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'danubius testenina makarone',
      displayName: 'Danubius Testenina',
      aliases: ['danubius spagete', 'danubius makarone', 'danubius rezanci', 'testenina danubius'],
    ),
    const SeedItemEntry(
      canonicalKey: 'barilla spagete testenina',
      displayName: 'Barilla Testenina / Špagete',
      aliases: ['barilla spagete', 'barilla penne', 'barilla fusilli', 'testenina barilla'],
    ),
    const SeedItemEntry(
      canonicalKey: 'klas brasno zlatni puder',
      displayName: 'Klas Brašno / Zlatni puder (BiH)',
      aliases: ['zlatni puder brasno', 'klas brasno', 'klas t500', 'klas t400'],
    ),
    const SeedItemEntry(
      canonicalKey: 'bimal suncokretovo ulje',
      displayName: 'Bimal Ulje (BiH)',
      aliases: ['bimal ulje', 'ulje bimal'],
    ),
    const SeedItemEntry(
      canonicalKey: 'maslinovo ulje',
      displayName: 'Maslinovo ulje',
      aliases: ['maslinovo ulje extra devičansko', 'monini maslinovo ulje'],
    ),
    const SeedItemEntry(
      canonicalKey: 'pirinac riza',
      displayName: 'Pirinač / Riža',
      aliases: ['pirinac', 'riza', 'pirinac okruglo zrno', 'pirinac dugo zrno', 'benlian pirinac'],
    ),
    const SeedItemEntry(
      canonicalKey: 'pasulj tetovac gradištanac',
      displayName: 'Pasulj',
      aliases: ['pasulj', 'beli pasulj', 'pasulj tetovac'],
    ),
    const SeedItemEntry(
      canonicalKey: 'aleva crvena paprika',
      displayName: 'Aleva Paprika / Začin',
      aliases: ['aleva paprika', 'slatka aleva paprika', 'kulinat aleva'],
    ),
    const SeedItemEntry(
      canonicalKey: 'podravka supa kokosija govedja',
      displayName: 'Podravka / Maggi Supa iz kesice',
      aliases: ['podravka supa', 'maggi supa', 'kokosija supa', 'govedja supa', 'alpska supa', 'yumis supa', 'c supa'],
    ),
    const SeedItemEntry(
      canonicalKey: 'c prasak za pecivo vanilin secer',
      displayName: 'C Prašak za pecivo / Vanilin šećer / Puding',
      aliases: ['prasak za pecivo', 'vanilin secer', 'c puding', 'dr oetker puding', 'dr oetker prasak za pecivo', 'suvi kvasac'],
    ),
    const SeedItemEntry(
      canonicalKey: 'senf c dijamant polimark',
      displayName: 'Senf',
      aliases: ['senf', 'c senf', 'dijamant senf', 'polimark senf', 'thommy senf'],
    ),
    const SeedItemEntry(
      canonicalKey: 'paradajz pelat pasirani tomatino',
      displayName: 'Pasirani paradajz / Tomatino',
      aliases: ['tomatino', 'tomatello', 'pasirani paradajz', 'paradajz pire', 'pelat paradajz'],
    ),
    const SeedItemEntry(
      canonicalKey: 'ajvar bakina tajna dijamant',
      displayName: 'Ajvar',
      aliases: ['ajvar', 'domaci ajvar', 'bakina tajna ajvar', 'dijamant ajvar', 'podravka ajvar', 'blagi ajvar', 'ljuti ajvar'],
    ),
    const SeedItemEntry(
      canonicalKey: 'frikom grasak kukuruz povrce',
      displayName: 'Frikom Smrznuto povrće / Pomfrit',
      aliases: ['frikom grasak', 'frikom kukuruz', 'frikom zlatna mesavina', 'frikom ruska salata', 'frikom pomfrit', 'frikom lisnato testo'],
    ),
    const SeedItemEntry(
      canonicalKey: 'frikom sladoled macho king',
      displayName: 'Frikom Sladoled',
      aliases: ['frikom sladoled', 'sladoled macho', 'sladoled king', 'sladoled kapri', 'sladoled rumenko', 'sladoled snesko', 'sladoled quattro'],
    ),

    // =========================================================================
    // SLATKIŠI, KEKS I GRICKALICE (SRB, MNE, BiH, HR)
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'bananica cokoladna stark',
      displayName: 'Štark Čoko Bananica',
      aliases: ['bananica', 'coko bananica', 'stark bananica', 'krem bananica'],
    ),
    const SeedItemEntry(
      canonicalKey: 'najlepse stark zelje cokolada',
      displayName: 'Najlepše Želje Čokolada',
      aliases: ['najlepse zelje', 'stark najlepse zelje', 'cokolada najlepse zelje'],
    ),
    const SeedItemEntry(
      canonicalKey: 'prima slani stapici stark',
      displayName: 'Prima Slani štapići',
      aliases: ['prima stapici', 'stark prima', 'slani stapici prima', 'stapici sa kikirikijem'],
    ),
    const SeedItemEntry(
      canonicalKey: 'bambi josh ribice krekere',
      displayName: 'Bambi Josh! Ribice / Krekeri',
      aliases: ['josh ribice', 'bambi josh', 'slane ribice', 'tak krekeri'],
    ),
    const SeedItemEntry(
      canonicalKey: 'bambi wellness keks',
      displayName: 'Bambi Wellness Keks',
      aliases: ['wellness keks', 'bambi wellness'],
    ),
    const SeedItemEntry(
      canonicalKey: 'zlatni pek keks bambi',
      displayName: 'Zlatni Pek Keks',
      aliases: ['zlatni pek', 'bambi zlatni pek'],
    ),
    const SeedItemEntry(
      canonicalKey: 'medeno srce pionir',
      displayName: 'Pionir Medeno Srce',
      aliases: ['medeno srce', 'pionir medeno srce'],
    ),
    const SeedItemEntry(
      canonicalKey: 'galeb cokolada pionir',
      displayName: 'Galeb Čokolada (Pionir)',
      aliases: ['galeb cokolada', 'pionir galeb', 'negro bombona', 'pionir negro'],
    ),
    const SeedItemEntry(
      canonicalKey: 'krem cipiripi eurokrem',
      displayName: 'Eurokrem / Cipiripi',
      aliases: ['eurokrem', 'swisslion eurokrem', 'euroblok', 'cipiripi', 'linolada'],
    ),
    const SeedItemEntry(
      canonicalKey: 'nutella krem',
      displayName: 'Nutella Krem',
      aliases: ['nutella', 'ferrero nutella'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kinder bueno jaje cokolada',
      displayName: 'Kinder Surprise / Bueno / Čokolada',
      aliases: ['kinder jaje', 'kinder surprise', 'kinder bueno', 'kinder chocolate', 'kinder pingui', 'kinder maxi'],
    ),
    const SeedItemEntry(
      canonicalKey: 'mars snickers twix bounty',
      displayName: 'Snickers / Mars / Twix / Bounty',
      aliases: ['snickers', 'mars cokoladica', 'twix', 'bounty', 'kit kat', 'lion cokoladica'],
    ),
    const SeedItemEntry(
      canonicalKey: 'dorina kras cokolada',
      displayName: 'Kraš Dorina / Bajadera / Domaćica',
      aliases: ['dorina cokolada', 'kras dorina', 'kras domacica', 'domacica keks', 'kras napolitanke', 'bronhi', 'ki ki bombone'],
    ),
    const SeedItemEntry(
      canonicalKey: 'medela strudla smokva',
      displayName: 'Medela Štrudla',
      aliases: ['medela strudle', 'strudla sa smokvom', 'strudla medela'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kikiriki gudmark fun',
      displayName: 'Pečeni kikiriki / Semenke',
      aliases: ['kikiriki', 'peceni kikiriki', 'slani kikiriki', 'gud kikiriki', 'dietaplus kikiriki', 'suncokret semenke', 'badem', 'lesnik', 'orah'],
    ),
    const SeedItemEntry(
      canonicalKey: 'orbit zvake',
      displayName: 'Orbit / Airwaves Žvake',
      aliases: ['orbit', 'zvake orbit', 'airwaves zvake', 'five zvake'],
    ),

    // =========================================================================
    // VODA, SOKOVI, PIVO, KAFE I ČAJEVI (SRB, MNE, BiH)
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'vrnjci voda mineralna',
      displayName: 'Voda Vrnjci',
      aliases: ['voda vrnjci', 'vrnjci gazirana', 'vrnjci negazirana'],
    ),
    const SeedItemEntry(
      canonicalKey: 'heba voda mineralna',
      displayName: 'Heba Voda',
      aliases: ['heba voda', 'voda heba'],
    ),
    const SeedItemEntry(
      canonicalKey: 'jazak voda',
      displayName: 'Jazak Voda',
      aliases: ['voda jazak'],
    ),
    const SeedItemEntry(
      canonicalKey: 'gorska suza voda',
      displayName: 'Suza / Rada Voda (CG)',
      aliases: ['voda suza', 'gorska voda', 'rada voda', 'aqua bianca'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kiseljak sarajevski voda',
      displayName: 'Sarajevski Kiseljak / Vitinka (BiH)',
      aliases: ['sarajevski kiseljak', 'vitinka voda', 'voda vivia', 'tesanjski kiseljak', 'oaza voda'],
    ),
    const SeedItemEntry(
      canonicalKey: 'fanta sok',
      displayName: 'Fanta',
      aliases: ['fanta orange', 'fanta shokata', 'sok fanta'],
    ),
    const SeedItemEntry(
      canonicalKey: 'sprite sok',
      displayName: 'Sprite',
      aliases: ['sok sprite', 'sprite gazirani'],
    ),
    const SeedItemEntry(
      canonicalKey: 'schweppes bitter lemon tonic',
      displayName: 'Schweppes',
      aliases: ['schweppes bitter lemon', 'schweppes tonic', 'schweppes tangerine'],
    ),
    const SeedItemEntry(
      canonicalKey: 'cockta sok',
      displayName: 'Cockta',
      aliases: ['cockta original', 'sok cockta', 'kokta'],
    ),
    const SeedItemEntry(
      canonicalKey: 'knjaz milos remix guarana',
      displayName: 'Guarana / Remix Knjaz',
      aliases: ['guarana', 'energetsko pice guarana', 'remix knjaz', 'red bull', 'monster energy', 'hell energy', 'ultra energy'],
    ),
    const SeedItemEntry(
      canonicalKey: 'cedevita napitak',
      displayName: 'Cedevita',
      aliases: ['cedevita narandza', 'cedevita limun'],
    ),
    const SeedItemEntry(
      canonicalKey: 'fruvita sok',
      displayName: 'Fruvita / Rauch / Bravo Sok',
      aliases: ['fruvita', 'bravo sok', 'rauch happy day', 'takovo sok', 'župski sok', 'vita sok'],
    ),
    const SeedItemEntry(
      canonicalKey: 'heineken pivo',
      displayName: 'Heineken Pivo',
      aliases: ['pivo heineken'],
    ),
    const SeedItemEntry(
      canonicalKey: 'tuborg pivo',
      displayName: 'Tuborg Pivo',
      aliases: ['pivo tuborg', 'carlsberg pivo'],
    ),
    const SeedItemEntry(
      canonicalKey: 'staropramen pivo',
      displayName: 'Staropramen / Stella Artois Pivo',
      aliases: ['pivo staropramen', 'stella artois', 'bavaria pivo', 'amstel pivo', 'birra moretti'],
    ),
    const SeedItemEntry(
      canonicalKey: 'valjevsko jagodinsko nisko pivo',
      displayName: 'Valjevsko / Niško Pivo',
      aliases: ['valjevsko pivo', 'nisko pivo', 'banjalucko pivo', 'tuzlansko pivo'],
    ),
    const SeedItemEntry(
      canonicalKey: 'bonito kafa',
      displayName: 'Bonito / C Kafa',
      aliases: ['bonito kafa', 'c kafa', 'kafa bonito'],
    ),
    const SeedItemEntry(
      canonicalKey: 'vispak zlatna dzezva kafa',
      displayName: 'Zlatna Džezva Kafa (BiH)',
      aliases: ['zlatna dzezva', 'vispak kafa', 'kafa zlatna dzezva'],
    ),
    const SeedItemEntry(
      canonicalKey: 'fruktonal milford caj',
      displayName: 'Fructus / Milford Čaj',
      aliases: ['fructus caj', 'milford caj', 'caj kamilica', 'caj nana', 'caj hibiskus', 'zeleni caj', 'podravka caj'],
    ),

    // =========================================================================
    // KUĆNA HEMIJA, PAPIRNA GALANTERIJA I LIČNA HIGIJENA
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'ariel deterdzent kapsule tecni',
      displayName: 'Ariel Deterdžent za veš',
      aliases: ['ariel prasak', 'ariel tecni deterdzent', 'ariel kapsule', 'ariel pods'],
    ),
    const SeedItemEntry(
      canonicalKey: 'persil deterdzent',
      displayName: 'Persil / Perwoll Deterdžent',
      aliases: ['persil prasak', 'persil gel', 'persil kapsule', 'perwoll deterdzent', 'rubel deterdzent', 'bonux deterdzent', 'tide deterdzent'],
    ),
    const SeedItemEntry(
      canonicalKey: 'lenor omeksivac silan',
      displayName: 'Lenor / Silan / Ornel Omekšivač',
      aliases: ['lenor omeksivac', 'silan omeksivac', 'ornel omeksivac', 'bohor omeksivac', 'violeta omeksivac'],
    ),
    const SeedItemEntry(
      canonicalKey: 'somat finish tablete za masinu',
      displayName: 'Finish / Somat Tablete za sudomašinu',
      aliases: ['finish tablete', 'somat tablete', 'finish quantum', 'somat gold', 'sjaj za sudomasinu', 'so za sudomasinu'],
    ),
    const SeedItemEntry(
      canonicalKey: 'domestos cif bref sredstvo',
      displayName: 'Domestos / Cif / Bref Hemija',
      aliases: ['domestos', 'cif krem', 'bref wc', 'ajax sredstvo', 'mr proper', 'clin za staklo', ' pronto ', 'sanitar wc'],
    ),
    const SeedItemEntry(
      canonicalKey: 'zewa paloma violeta toalet papir',
      displayName: 'Zewa / Paloma / Violeta Toalet papir',
      aliases: ['zewa toalet papir', 'paloma toalet papir', 'violeta toalet papir', 'ubrusi kuhinjski', 'papirne maramice', 'vlazne maramice', 'becutan vlazne maramice'],
    ),
    const SeedItemEntry(
      canonicalKey: 'colgate aquafresh sensodyne pasta za zube',
      displayName: 'Colgate / Sensodyne Pasta za zube',
      aliases: ['colgate pasta', 'sensodyne pasta', 'aquafresh pasta', 'blend a med', 'parodontax', 'pasta za zube', 'cetkica za zube'],
    ),
    const SeedItemEntry(
      canonicalKey: 'nivea dove palmolive kupka sapun',
      displayName: 'Nivea / Dove / Palmolive Higijena',
      aliases: ['nivea gel za tusiranje', 'nivea dezodorans', 'nivea krema', 'dove sapun', 'dove kupka', 'palmolive kupka', 'palmolive sapun', 'fa kupka', 'old spice', 'rexona dezodorans', 'kosili kupka'],
    ),
    const SeedItemEntry(
      canonicalKey: 'head shoulders pantene sampon',
      displayName: 'Šampon za kosu (H&S / Pantene / Wash&Go)',
      aliases: ['head shoulders sampon', 'pantene sampon', 'wash go sampon', 'schauma sampon', 'gliss sampon', 'syoss sampon', 'afrodita sampon', 'sampon od koprive'],
    ),
    const SeedItemEntry(
      canonicalKey: 'always libero pampers pelene ulosci',
      displayName: 'Always Ulošci / Pampers Pelene',
      aliases: ['always ulosci', 'libresse ulosci', 'pampers pelene', 'violeta pelene', 'babylove pelene'],
    ),
    const SeedItemEntry(
      canonicalKey: 'kesa tregerica biorazgradiva',
      displayName: 'Kesa (plastična / biorazgradiva)',
      aliases: ['kesa', 'biorazgradiva kesa', 'kesa tregerica', 'velika kesa', 'kesa za smece', 'alu folija', 'providna folija', 'papir za pecenje'],
    ),

    // =========================================================================
    // GORIVO, BENZINSKE STANICE I USLUGE (NIS, OMV, EKO, PETROL, LUKOIL)
    // =========================================================================
    const SeedItemEntry(
      canonicalKey: 'dizel evro gorivo',
      displayName: 'Evro dizel (Gorivo)',
      aliases: ['evro dizel', 'euro diesel', 'eurodizel', 'g drive diesel', 'g-drive dizel', 'ectodiesel', 'ultra d', 'maxmotion diesel', 'q max diesel'],
    ),
    const SeedItemEntry(
      canonicalKey: 'benzin bmb95 evro premijum',
      displayName: 'Evro Premijum BMB 95 (Benzin)',
      aliases: [
        'evro premijum bmb 95',
        'bmb 95',
        'bmb95',
        'omv ep bmb 95',
        'evo ep bmb 95',
        'eurosuper 95',
        'g drive 100',
        'bmb 100',
        'maxmotion 100',
      ],
    ),
    const SeedItemEntry(
      canonicalKey: 'auto gas tng lpg',
      displayName: 'TNG / Auto-gas (LPG)',
      aliases: ['tng', 'auto gas', 'autogas', 'tecni naftni gas', 'lpg'],
    ),
    const SeedItemEntry(
      canonicalKey: 'tecnost za stakla vetrobran',
      displayName: 'Tečnost za vetrobransko staklo',
      aliases: ['tecnost za stakla', 'zimska tecnost za stakla', 'letnja tecnost za stakla', 'adeblue', 'adblue'],
    ),
    const SeedItemEntry(
      canonicalKey: 'dostava usluga',
      displayName: 'Dostava (Usluga dostave)',
      aliases: [
        'dostava',
        'usluga dostave',
        'troskovi dostave',
        'doplata za dostavu',
        'usluge mp usluga dostava robe',
        'delivery_item',
      ],
    ),
    const SeedItemEntry(
      canonicalKey: 'parkiranje usluga',
      displayName: 'Usluga parkiranja',
      aliases: ['parkiranje', 'usluga parkiranja', 'parking karta'],
    ),
  ];
}
