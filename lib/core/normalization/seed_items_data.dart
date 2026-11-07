import 'dart:convert';

class SeedItemEntry {
  const SeedItemEntry({
    required this.canonicalKey,
    required this.displayName,
    this.aliases = const [],
  });

  final String canonicalKey;
  final String displayName;
  final List<String> aliases;

  factory SeedItemEntry.fromJson(Map<String, dynamic> json) {
    final rawAliases = json['aliases'] as List<dynamic>? ?? const [];
    return SeedItemEntry(
      canonicalKey: json['canonicalKey'] as String,
      displayName: json['displayName'] as String,
      aliases: [for (final a in rawAliases) a as String],
    );
  }
}

/// Učitava početni (seed) rečnik artikala (`assets/data/seed_items.json`).
class SeedItemsLoader {
  const SeedItemsLoader._();

  static const String assetPath = 'assets/data/seed_items.json';

  static Future<List<SeedItemEntry>> load() async {
    return defaultSeedEntries;
  }

  static List<SeedItemEntry> parseJson(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final list = decoded['items'] as List<dynamic>? ?? const [];
    return [
      for (final item in list)
        SeedItemEntry.fromJson(item as Map<String, dynamic>),
    ];
  }

  static const List<SeedItemEntry> defaultSeedEntries = [
    SeedItemEntry(
      canonicalKey: 'imlek kravica mleko moja',
      displayName: 'Mleko Moja Kravica',
      aliases: [
        'dugotrajno kravica mleko moja',
        'imlek kravica mleko',
        'imlek kravica mleko moja',
        'imlek kravica mleko sveze',
        'kravica mleko',
        'kravica mleko moja',
        'kravica mleko sveze',
        'kravica mleko uht',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'imlek jogurt kravica moja',
      displayName: 'Jogurt Moja Kravica',
      aliases: [
        'gusti jogurt kravica moja',
        'imlek jogurt kravica',
        'imlek jogurt kravica moja',
        'jogurt kravica',
        'jogurt kravica moja',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'balans imlek jogurt',
      displayName: 'Jogurt Balans+',
      aliases: [
        'balans imlek',
        'balans imlek jogurt',
        'balans jogurt',
        'balans jogurt plus',
        'balans jogurt probiotik',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'imlek kisela kravica moja pavlaka',
      displayName: 'Kisela pavlaka Moja Kravica',
      aliases: [
        'imlek kisela kravica moja pavlaka',
        'imlek kisela pavlaka',
        'kisela kravica moja pavlaka',
        'kravica moja pavlaka',
        'kravica pavlaka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dukat mleko',
      displayName: 'Mleko Dukat',
      aliases: [
        'cokoladno dukat mleko',
        'cokoladno mleko',
        'dugotrajno dukat mleko',
        'dukat mleko',
        'dukat mleko somboled',
        'dukat mleko sveze',
        'dukat mleko trajno',
        'dukat mleko uht',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'meggle mleko',
      displayName: 'Mleko Meggle',
      aliases: [
        'dugotrajno meggle mleko',
        'meggle mleko',
        'meggle mleko trajno',
        'meggle mleko uht',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mleko zbregov',
      displayName: 'Mleko Z\'bregov',
      aliases: [
        'bregov mleko',
        'dugotrajno mleko zbregov',
        'mleko vindija zbregov',
        'mleko zbregov',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'imlek maslac',
      displayName: 'Maslac Imlek',
      aliases: [
        'imlek kravica maslac moja',
        'imlek maslac',
        'imlek puter',
        'kravica maslac moja',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'president sir somboled',
      displayName: 'Sir President',
      aliases: [
        'mladi president sir',
        'president sir',
        'president sir sjenicki',
        'president sir somboled',
        'president somboled',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mlekara sabacka sir',
      displayName: 'Sir Šabačka mlekara',
      aliases: [
        'mediteraneo sir',
        'mlekara sabacka',
        'mlekara sabacka sir',
        'sabacka sir',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bela mlekara pavlaka subotica',
      displayName: 'Kisela pavlaka Mlekara Subotica',
      aliases: [
        'bela mlekara pavlaka subotica',
        'kisela mlekara pavlaka subotica',
        'mlekara pavlaka subotica',
        'pavlaka subotica',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'beli hleb sava',
      displayName: 'Hleb beli Sava',
      aliases: [
        'beli hleb rezani',
        'beli hleb sava',
        'beli hleb vekna',
        'hleb narodni',
        'hleb sava',
        'hleb tip500',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dijamant suncokretovo ulje',
      displayName: 'Ulje Dijamant',
      aliases: [
        'dijamant jestivo ulje',
        'dijamant suncokretovo ulje',
        'dijamant ulje',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'sunce suncokretovo ulje',
      displayName: 'Ulje Sunce',
      aliases: [
        'jestivo sunce ulje',
        'sunce suncokretovo ulje',
        'sunce ulje',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'suncokretovo ulje vital',
      displayName: 'Ulje Vital',
      aliases: [
        'jestivo ulje vital',
        'suncokretovo ulje vital',
        'ulje vital',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'iskon suncokretovo ulje',
      displayName: 'Ulje Iskon',
      aliases: [
        'iskon jestivo ulje',
        'iskon suncokretovo ulje',
        'iskon ulje',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bambi keks plazma',
      displayName: 'Plazma keks Bambi',
      aliases: [
        'bambi keks plazma',
        'bambi mlevena plazma',
        'bambi plazma',
        'keks plazma',
        'mlevena plazma',
        'plazma',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'flips smoki stark',
      displayName: 'Smoki Štark',
      aliases: [
        'flips smoki',
        'flips smoki stark',
        'smoki',
        'smoki soko stark',
        'smoki stark',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bananica cokoladna stark',
      displayName: 'Čokoladna bananica Štark',
      aliases: [
        'bananica',
        'bananica coko',
        'bananica coko stark',
        'bananica cokolada krem',
        'bananica cokoladna krem',
        'bananica cokoladna stark',
        'bananica krem',
        'bananica stark',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cokolada najlepse stark zelje',
      displayName: 'Čokolada Najlepše želje',
      aliases: [
        'cokolada najlepse stark zelje',
        'cokolada najlepse zelje',
        'mlecna najlepse stark zelje',
        'mlecna najlepse zelje',
        'najlepse stark zelje',
        'najlepse zelje',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cokolada milka',
      displayName: 'Čokolada Milka',
      aliases: [
        'cokolada milka',
        'cokolada milka mlecna',
        'lesnik milka',
        'milka',
        'milka noisette',
        'milka oreo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crvenka jaffa keks',
      displayName: 'Jaffa Cakes Crvenka',
      aliases: [
        'biscuit jaffa',
        'cakes crvenka jaffa',
        'crvenka jaffa keks',
        'jaffa',
        'jaffa keks',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crvenka jaffa munchmallow',
      displayName: 'Munchmallow',
      aliases: [
        'crvenka jaffa munchmallow',
        'crvenka munchmallow',
        'munchmallow',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'eurokrem krem swisslion takovo',
      displayName: 'Eurokrem Takovo',
      aliases: [
        'eurokrem',
        'eurokrem krem swisslion takovo',
        'eurokrem swisslion',
        'eurokrem takovo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'coca cola',
      displayName: 'Coca-Cola',
      aliases: [
        'coca cola',
        'coca cola gazirani pice',
        'coca cola gazirani sok',
        'coca cola hvala',
        'coca cola original',
        'coca cola original taste',
        'hvala',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'coca cola zero',
      displayName: 'Coca-Cola Zero',
      aliases: [
        'bez coca cola secera',
        'coca cola sugar zero',
        'coca cola zero',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cola pepsi',
      displayName: 'Pepsi',
      aliases: [
        'cola pepsi',
        'gazirani pepsi sok',
        'max pepsi',
        'pepsi',
        'pepsi twist',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cockta',
      displayName: 'Cockta',
      aliases: [
        'cockta',
        'cockta gazirani sok',
        'cockta original',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'fanta orange',
      displayName: 'Fanta',
      aliases: [
        'fanta',
        'fanta gazirani sok',
        'fanta orange',
        'fanta pomorandza',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kisela knjaz milos mineralna voda',
      displayName: 'Kisela voda Knjaz Miloš',
      aliases: [
        'gazirana knjaz milos voda',
        'kisela knjaz milos mineralna voda',
        'kisela knjaz milos voda',
        'kisela knjaz voda',
        'knjaz milos',
        'knjaz milos voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mineralna negazirana rosa voda',
      displayName: 'Voda Rosa',
      aliases: [
        'mineralna negazirana rosa voda',
        'negazirana rosa voda',
        'prirodna rosa voda',
        'rosa voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'aqua mineralna negazirana viva voda',
      displayName: 'Voda Aqua Viva',
      aliases: [
        'aqua mineralna negazirana viva voda',
        'aqua negazirana viva voda',
        'aqua viva',
        'aqua viva voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mineralna negazirana prolom voda',
      displayName: 'Voda Prolom',
      aliases: [
        'mineralna negazirana prolom voda',
        'prolom',
        'prolom voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'gazirana minaqua mineralna voda',
      displayName: 'Voda Minaqua',
      aliases: [
        'gazirana minaqua mineralna voda',
        'kisela minaqua voda',
        'minaqua',
        'minaqua voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'gold grand kafa mlevena',
      displayName: 'Kafa Grand Gold',
      aliases: [
        'gold grand kafa',
        'gold grand kafa mlevena',
        'grand kafa',
        'grand kafa mlevena',
        'grand kafa strong',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'doncafe kafa minas mlevena',
      displayName: 'Kafa Doncafé',
      aliases: [
        'doncaf kafa',
        'doncafe kafa',
        'doncafe kafa minas mlevena',
        'doncafe kafa mlevena',
        'doncafe minas',
        'doncafe moment',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'barcaffe kafa mlevena',
      displayName: 'Kafa Barcaffè',
      aliases: [
        'barcaff kafa',
        'barcaffe',
        'barcaffe kafa',
        'barcaffe kafa mlevena',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'classic instant kafa nescafe',
      displayName: 'Nescafé Classic',
      aliases: [
        'classic instant kafa nescafe',
        'classic nescaf',
        'classic nescafe',
        'gold nescafe',
        'instant kafa nescafe',
        'nescafe',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jelen pivo',
      displayName: 'Jelen pivo',
      aliases: [
        'apatinsko jelen pivo',
        'jelen',
        'jelen pivo',
        'jelen pivo svetlo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'lav pivo',
      displayName: 'Lav pivo',
      aliases: [
        'carlsberg lav pivo',
        'lav pivo',
        'lav pivo premium',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pivo zajecarsko',
      displayName: 'Zaječarsko pivo',
      aliases: [
        'pivo svetlo zajecarsko',
        'pivo zajecarsko',
        'zajecarsko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'niksicko pivo',
      displayName: 'Nikšićko pivo',
      aliases: [
        'niksicko',
        'niksicko pivo',
        'niksicko pivo svetlo',
        'niksicko pivo trebjesa',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'banjalucko pivo',
      displayName: 'Banjalučko pivo',
      aliases: [
        'banjalucka nektar pivara pivo',
        'banjalucko pivo',
        'nektar pivo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'carnex pasteta',
      displayName: 'Pašteta Carnex',
      aliases: [
        'cajna carnex pasteta',
        'carnex jetrena pasteta',
        'carnex pasteta',
        'carnex pasteta pileci',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'argeta pasteta',
      displayName: 'Pašteta Argeta',
      aliases: [
        'argeta junior pasteta',
        'argeta kokosija pasteta',
        'argeta pasteta',
        'argeta pasteta pileci',
        'argeta pasteta tuna',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'beli kristal secer sunoko',
      displayName: 'Šećer kristal',
      aliases: [
        'beli kristal secer sunoko',
        'beli secer',
        'crvenka secer',
        'kristal secer',
        'secer sunoko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'brasno psenicno tip400',
      displayName: 'Brašno pšenično T-400',
      aliases: [
        'brasno danubius tip400',
        'brasno fidelinka tip400',
        'brasno glatko tip400',
        'brasno psenicno tip400',
        'brasno sentella tip400',
        'brasno tip400',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'brasno psenicno tip500',
      displayName: 'Brašno pšenično T-500',
      aliases: [
        'brasno danubius tip500',
        'brasno fidelinka tip500',
        'brasno psenicno tip500',
        'brasno tip500',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kuhinjska so tuzlanska',
      displayName: 'Kuhinjska so Tuzlanska',
      aliases: [
        'kuhinjska so tuzlanska',
        'sitna so tuzlanska',
        'so tuzlanska',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kecap polimark',
      displayName: 'Kečap Polimark',
      aliases: [
        'blagi kecap polimark',
        'kecap ljuti polimark',
        'kecap pizza polimark',
        'kecap polimark',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dijamant majonez',
      displayName: 'Majonez Dijamant',
      aliases: [
        'classic dijamant majonez',
        'classic majonez',
        'dijamant majonez',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'majonez polimark',
      displayName: 'Majonez Polimark',
      aliases: [
        'classic majonez polimark',
        'majonez polimark',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'majonez thomy',
      displayName: 'Majonez Thomy',
      aliases: [
        'delikatess majonez thomy',
        'majonez thomy',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'c dodatak jelima zacin',
      displayName: 'Začin C',
      aliases: [
        'c dodatak jelima',
        'c dodatak jelima zacin',
        'c zacin',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dodatak jelima podravka vegeta',
      displayName: 'Vegeta Podravka',
      aliases: [
        'dodatak jelima podravka vegeta',
        'podravka vegeta',
        'vegeta',
        'vegeta zacin',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'deterdzent fairy sudove',
      displayName: 'Fairy deterdžent za sudove',
      aliases: [
        'deterdzent fairy',
        'deterdzent fairy sudove',
        'fairy',
        'fairy limun',
        'fairy sudove tecnost',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ariel deterdzent ves',
      displayName: 'Ariel deterdžent za veš',
      aliases: [
        'ariel deterdzent',
        'ariel deterdzent tecni',
        'ariel deterdzent ves',
        'ariel kapsule',
        'ariel prasak',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'papir perfex toalet',
      displayName: 'Toalet papir Perfex',
      aliases: [
        'papir perfex',
        'papir perfex toalet',
        'perfex',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'papir toalet zewa',
      displayName: 'Toalet papir Zewa',
      aliases: [
        'deluxe zewa',
        'papir toalet zewa',
        'papir zewa',
        'zewa',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'imlek kravica maslac moja',
      displayName: 'Maslac Moja Kravica',
      aliases: [
        'imlek kravica maslac moja',
        'imlek maslac',
        'kravica maslac',
        'kravica maslac moja',
        'kravica puter',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'imlek kravica moja sir sitni',
      displayName: 'Sitni sir Moja Kravica',
      aliases: [
        'imlek kravica moja sir sitni',
        'imlek sir sitni',
        'kravica moja sir sitni',
        'kravica sir sitni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bela imlek kravica moja sir',
      displayName: 'Beli sir Moja Kravica',
      aliases: [
        'bela imlek kravica moja sir',
        'beli kravica moja sir',
        'beli kravica sir',
        'kravica kriska moja sira',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cokoladno imlek kravica mleko moja',
      displayName: 'Čokoladno mleko Moja Kravica',
      aliases: [
        'cokoladno imlek kravica mleko moja',
        'cokoladno imlek mleko',
        'cokoladno kravica mleko',
        'cokoladno kravica mleko moja',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'imlek kravica kuhinjica moja pavlaka',
      displayName: 'Pavlaka za kuvanje Moja Kravica',
      aliases: [
        'imlek kravica kuhinjica moja pavlaka',
        'kravica kuvanje moja pavlaka',
        'kravica kuvanje pavlaka',
        'kuhinjica kuvanje pavlaka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bello imlek jogurt organic',
      displayName: 'Bello Organic Jogurt',
      aliases: [
        'bello imlek jogurt',
        'bello imlek jogurt organic',
        'bello jogurt',
        'bello jogurt organic',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'grekos imlek jogurt',
      displayName: 'Grekos Grčki jogurt',
      aliases: [
        'grcki grekos jogurt',
        'grekos imlek',
        'grekos imlek jogurt',
        'grekos jogurt',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'imlek kefir kravica moja',
      displayName: 'Kefir Moja Kravica',
      aliases: [
        'imlek kefir',
        'imlek kefir kravica moja',
        'kefir kravica',
        'kefir kravica moja',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'flert imlek kafa',
      displayName: 'Flert Ledena kafa',
      aliases: [
        'flert imlek',
        'flert imlek kafa',
        'flert kafa ledena',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dukat jogurt',
      displayName: 'Dukat Jogurt',
      aliases: [
        'dukat gusti jogurt',
        'dukat jogurt',
        'dukat jogurt tekuci',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'biser sir trapist',
      displayName: 'Sir Trapist Biser',
      aliases: [
        'biser sir trapist',
        'biser trapist',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'gauda president sir',
      displayName: 'President Gauda sir',
      aliases: [
        'gauda president',
        'gauda president sir',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'edamer president sir',
      displayName: 'President Edamer sir',
      aliases: [
        'edamer president',
        'edamer president sir',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kajmak mlad zlatarski',
      displayName: 'Zlatarski sir / kajmak',
      aliases: [
        'kajmak',
        'kajmak mlad zlatarski',
        'kajmak sir zlatarski',
        'kajmak zlatarski',
        'sir zlatarski',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ella sir',
      displayName: 'Ella Sir (Subotička mlekara)',
      aliases: [
        'ella mlekara sir subotica',
        'ella mlekara sir suboticka',
        'ella posni sir',
        'ella sir',
        'ella suboticka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ab kultura suboticka',
      displayName: 'AB Kultura Jogurt',
      aliases: [
        'ab jogurt',
        'ab jogurt kultura',
        'ab jogurt mlekara subotica',
        'ab kultura suboticka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mleko suboticka zdravo',
      displayName: 'Zdravo! Mleko',
      aliases: [
        'jogurt zdravo',
        'mleko suboticka zdravo',
        'mleko zdravo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'granice jogurt mlekara',
      displayName: 'Mlekara Granice Jogurt',
      aliases: [
        'granice jogurt',
        'granice jogurt mlekara',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'granice mlekara mleko',
      displayName: 'Mlekara Granice Mleko',
      aliases: [
        'granice mlekara mleko',
        'granice mleko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jogurt lazine mlekara',
      displayName: 'Lazine Jogurt (CG)',
      aliases: [
        'cg jogurt lazine',
        'jogurt lazine',
        'jogurt lazine mlekara',
        'kisela lazine mleko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'lazine mlekara mleko',
      displayName: 'Lazine Mleko (CG)',
      aliases: [
        'cg lazine mleko',
        'lazine mlekara mleko',
        'lazine mleko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'milgor mleko srna',
      displayName: 'Srna Mleko / Jogurt (CG)',
      aliases: [
        'cg jogurt mleko srna',
        'jogurt srna',
        'milgor mleko srna',
        'mleko srna',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jogurt meggle',
      displayName: 'Meggle Jogurt',
      aliases: [
        'jogurt meggle',
        'jogurt meggle tekuci',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'meggle pavlaka',
      displayName: 'Meggle Pavlaka',
      aliases: [
        'kisela meggle pavlaka',
        'kuvanje meggle pavlaka',
        'meggle pavlaka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'maslac meggle',
      displayName: 'Meggle Maslac',
      aliases: [
        'maslac meggle',
        'meggle puter',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mleko vindija zbregov',
      displayName: '\'z bregov Mleko',
      aliases: [
        'bregov mleko',
        'mleko vindija',
        'mleko vindija zbregov',
        'mleko zbregov',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jogurt vindija zbregov',
      displayName: '\'z bregov Jogurt',
      aliases: [
        'bregov jogurt',
        'jogurt vindija',
        'jogurt vindija zbregov',
        'jogurt zbregov',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jogurt vitalis vocni',
      displayName: 'Vitalis Voćni jogurt',
      aliases: [
        'jogurt vitalis',
        'jogurt vitalis vocni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jogood jogurt vocni',
      displayName: 'Jogood Voćni jogurt',
      aliases: [
        'imlek jogood',
        'jogood jogurt vocni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mleko pilos',
      displayName: 'Pilos Mleko (Lidl)',
      aliases: [
        'dugotrajno mleko pilos',
        'lidl mleko pilos',
        'mleko pilos',
        'mleko pilos sveze',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jogurt pilos',
      displayName: 'Pilos Jogurt (Lidl)',
      aliases: [
        'grcki jogurt pilos',
        'jogurt lidl pilos',
        'jogurt pilos',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pavlaka pilos',
      displayName: 'Pilos Pavlaka (Lidl)',
      aliases: [
        'kisela pavlaka pilos',
        'lidl pavlaka pilos',
        'pavlaka pilos',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pilos sir',
      displayName: 'Pilos Sir (Lidl)',
      aliases: [
        'beli pilos sir',
        'edamer pilos',
        'gauda pilos',
        'lidl pilos sir',
        'pilos sir',
        'pilos sir sitni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mleko premia',
      displayName: 'Premia Mleko (Maxi)',
      aliases: [
        'dugotrajno mleko premia',
        'maxi mleko premia',
        'mleko premia',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jogurt premia',
      displayName: 'Premia Jogurt (Maxi)',
      aliases: [
        'jogurt maxi premia',
        'jogurt premia',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mleko plus',
      displayName: 'K Plus Mleko (Idea)',
      aliases: [
        'idea mleko plus',
        'kplus mleko',
        'mleko plus',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'beli hleb rezani',
      displayName: 'Beli rezani hleb',
      aliases: [
        'beli hleb rezani',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'hleb polubeli',
      displayName: 'Polubeli hleb',
      aliases: [
        'hleb polubeli',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'hleb integralni',
      displayName: 'Integralni hleb',
      aliases: [
        'crni hleb',
        'hleb integralni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'hleb kukuruzni',
      displayName: 'Kukuruzni hleb',
      aliases: [
        'hleb kukuruzni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'baget francuski hleb',
      displayName: 'Francuski baget',
      aliases: [
        'baget',
        'baget francuski',
        'baget francuski hleb',
        'baget hleb',
        'francuski hleb',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'lepinja somun',
      displayName: 'Somun / Lepinja',
      aliases: [
        'domaca lepinja',
        'lepinja',
        'lepinja somun',
        'lepinja vruca',
        'somun',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kifla pecivo',
      displayName: 'Kifla',
      aliases: [
        'kifla',
        'kifla pecivo',
        'kifla pekarska',
        'kifla slana',
        'kifle',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'burek meso sa',
      displayName: 'Burek sa mesom',
      aliases: [
        'burek meso',
        'burek meso sa',
        'burek mesom',
        'burek mesom sa',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'burek sa sirom',
      displayName: 'Burek sa sirom',
      aliases: [
        'burek sa sirom',
        'burek sir',
        'burek sirom',
        'pita sa sirom',
        'sirnica',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kroasan pecivo',
      displayName: 'Kroasan',
      aliases: [
        'cokolada kroasan',
        'croissant',
        'kroasan',
        'kroasan pecivo',
        'kroasan sir sunka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: '7days kroasan',
      displayName: '7Days Kroasan',
      aliases: [
        '7days double',
        '7days kakao',
        '7days kroasan',
        'days kroasan',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'djevrek pecivo',
      displayName: 'Đevrek',
      aliases: [
        'djevrek',
        'djevrek pecivo',
        'djevrek pekarski',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cvarci pogacica',
      displayName: 'Pogačica / Žu-Žu',
      aliases: [
        'cvarci pogacica',
        'lisnato pecivo',
        'pecivo zuzu',
        'pogacica',
        'pogacica zu',
        'zu',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'tortilja',
      displayName: 'Tortilja',
      aliases: [
        'mexican tortilja',
        'psenicna tortilja',
        'tortilja',
        'tortilje',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jetrena pasteta',
      displayName: 'Jetrena pašteta',
      aliases: [
        'jetrena pasteta',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cajna carnex kobasica',
      displayName: 'Carnex Čajna kobasica',
      aliases: [
        'cajna carnex',
        'cajna carnex kobasica',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'carnex virsle',
      displayName: 'Carnex Viršle',
      aliases: [
        'carnex delikates virsle',
        'carnex virsle',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'carnex gotova jela pasulj',
      displayName: 'Carnex Gotovo jelo',
      aliases: [
        'carnex cufte',
        'carnex gotova jela pasulj',
        'carnex gotovo jelo',
        'carnex gulas',
        'carnex pasulj',
        'carnex sarma',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'matijevic parizer',
      displayName: 'Matijević Parizer / Salamura',
      aliases: [
        'matijevic parizer',
        'matijevic parizer salamura',
        'matijevic posebna',
        'matijevic sunkarica',
        'matijevic virsle',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cajna kobasica yuhor',
      displayName: 'Yuhor Delikates / Kobasica',
      aliases: [
        'budimska yuhor',
        'cajna kobasica yuhor',
        'cajna yuhor',
        'delikates kobasica yuhor',
        'kulen yuhor',
        'sunka yuhor',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pasteta yuhor',
      displayName: 'Yuhor Pašteta',
      aliases: [
        'jetrena pasteta yuhor',
        'kokosija pasteta yuhor',
        'pasteta yuhor',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'neoplanta pasteta patelina',
      displayName: 'Patelina Pašteta (Neoplanta)',
      aliases: [
        'kokosija patelina',
        'neoplanta pasteta',
        'neoplanta pasteta patelina',
        'pasteta patelina',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'delikates neoplanta sunka',
      displayName: 'Neoplanta Delikates',
      aliases: [
        'cajna neoplanta',
        'delikates neoplanta',
        'delikates neoplanta sunka',
        'kobasica neoplanta',
        'kulen neoplanta',
        'neoplanta sunka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cajna gavrilovic pasteta',
      displayName: 'Gavrilović Pašteta / Zimska',
      aliases: [
        'cajna gavrilovic',
        'cajna gavrilovic pasteta',
        'gavrilovic hrenovke',
        'gavrilovic pasteta',
        'gavrilovic pasteta zimska',
        'gavrilovic zimska',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ovako parizer piletina',
      displayName: 'Ovako Piletina / Parizer (BiH)',
      aliases: [
        'bih ovako parizer piletina',
        'ovako parizer pileci',
        'ovako parizer piletina',
        'ovako pasteta',
        'ovako piletina',
        'ovako virsle',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'goranovic kobasica sunka',
      displayName: 'Goranović Delikates (CG)',
      aliases: [
        'cajna goranovic',
        'cg delikates goranovic',
        'goranovic kobasica sunka',
        'goranovic parizer',
        'goranovic prsuta',
        'goranovic slanina',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'martex prsuta',
      displayName: 'Martex Njeguška pršuta (CG)',
      aliases: [
        'cg martex njeguska prsuta',
        'delikates martex',
        'martex prsuta',
        'njeguska prsuta',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dimljena panceta slanina',
      displayName: 'Slanina / Pančeta',
      aliases: [
        'dimljena panceta slanina',
        'dimljena slanina',
        'mesnata slanina',
        'panceta',
        'panceta slanina',
        'slanina',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'govedja prsuta svinjski',
      displayName: 'Pršuta / Pečenica',
      aliases: [
        'dimljena pecenica',
        'govedja prsuta',
        'govedja prsuta svinjski',
        'pecenica',
        'pecenica prsuta',
        'prsuta svinjski',
        'suvi vrat',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kobasica kulen',
      displayName: 'Kulen',
      aliases: [
        'domaci kulen',
        'kobasica kulen',
        'kulen',
        'kulen sremski',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cajna kobasica',
      displayName: 'Čajna kobasica',
      aliases: [
        'cajna kobasica',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pizza stisnjena sunka',
      displayName: 'Šunka u omotu / Pizza šunka',
      aliases: [
        'cureca prsa',
        'omotu pileci prsa',
        'omotu pizza sunka',
        'omotu sunka',
        'pizza stisnjena sunka',
        'pizza sunka',
        'stisnjena sunka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'hrenovke virsle',
      displayName: 'Viršle / Hrenovke',
      aliases: [
        'hrenovke virsle',
        'perutnina ptuj virsle',
        'pileci virsle',
        'poli virsle',
        'virsle',
        'virsle wudy',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'parizer perutnina poli',
      displayName: 'Poli Pileći parizer',
      aliases: [
        'parizer perutnina poli',
        'parizer pileci poli',
        'parizer poli',
        'perutnina poli',
        'poli salama',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'batak karabatak pileci',
      displayName: 'Pileći batak / karabatak',
      aliases: [
        'batak karabatak pileci',
        'batak karabatakom sa',
        'batak otkosteni',
        'batak pileci',
        'karabatak pileci',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'krilca pileci',
      displayName: 'Pileća krilca',
      aliases: [
        'krilca pileci',
        'krilca pileci sveza',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'celo pile sveze',
      displayName: 'Sveže pile (celo)',
      aliases: [
        'celo pile sveze',
        'gril pile',
        'pile sveze',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'krmenadla svinjski vrat',
      displayName: 'Svinjski vrat / Krmenadla',
      aliases: [
        'krmenadla svinjski',
        'krmenadla svinjski vrat',
        'plecka svinjski',
        'rebra svinjski',
        'svinjski vrat',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cevapi leskovacki sarajevski',
      displayName: 'Ćevapi / Pljeskavica',
      aliases: [
        'cevapcici',
        'cevapi',
        'cevapi leskovacki sarajevski',
        'cevapi pljeskavica',
        'meso rostilj',
        'pljeskavica',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'eva sardina tunjevina',
      displayName: 'Eva Sardina / Tunjevina',
      aliases: [
        'eva podravka',
        'eva sardina tunjevina',
        'eva sardine',
        'eva tunjevina',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'calvo mare rio tunjevina',
      displayName: 'Rio Mare / Calvo Tunjevina',
      aliases: [
        'calvo mare rio tunjevina',
        'calvo tunjevina',
        'capitano il tunjevina',
        'la perla tunjevina',
        'mare rio tunjevina',
        'salamuri tunjevina',
        'tunjevina ulju',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'oslic riba smrznuti',
      displayName: 'Smrznuti oslić / Fileti ribe',
      aliases: [
        'bez glave oslic',
        'fileti oslic ribe smrznuti',
        'fileti oslica',
        'hoki oslic',
        'oslic riba smrznuti',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'banana voce',
      displayName: 'Banane',
      aliases: [
        'banana',
        'banana voce',
        'banane',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jabuka voce',
      displayName: 'Jabuke',
      aliases: [
        'ajdared jabuka',
        'delises jabuka zlatni',
        'gala jabuka',
        'grenismit jabuka',
        'jabuka',
        'jabuka voce',
        'jabuke',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'limun voce',
      displayName: 'Limun',
      aliases: [
        'limun',
        'limun voce',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'narandza pomorandza',
      displayName: 'Pomorandže / Mandarine',
      aliases: [
        'klementina',
        'mandarina',
        'mandarine',
        'mandarine pomorandze',
        'narandza',
        'narandza pomorandza',
        'pomorandza',
        'pomorandze',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'krompir povrce',
      displayName: 'Krompir',
      aliases: [
        'beli krompir',
        'crveni krompir',
        'krompir',
        'krompir mladi',
        'krompir povrce',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crni luk povrce',
      displayName: 'Crni / Beli luk',
      aliases: [
        'beli crni luk',
        'beli luk',
        'crni luk',
        'crni luk povrce',
        'crveni luk',
        'luk mladi',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'paradajz povrce',
      displayName: 'Paradajz',
      aliases: [
        'ceri paradajz',
        'cherry paradajz',
        'paradajz',
        'paradajz pink',
        'paradajz povrce',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'krastavac povrce',
      displayName: 'Krastavac',
      aliases: [
        'kornisoni',
        'krastavac',
        'krastavac povrce',
        'krastavac salatni',
        'krastavci',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'paprika povrce',
      displayName: 'Paprika',
      aliases: [
        'babura paprika',
        'crvena paprika',
        'ljuta paprika',
        'paprika',
        'paprika povrce',
        'paprika silja',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mrkva sargarepa',
      displayName: 'Šargarepa',
      aliases: [
        'mrkva',
        'mrkva sargarepa',
        'sargarepa',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kupus salata zelena',
      displayName: 'Kupus / Zelena salata',
      aliases: [
        'iceberg salata',
        'kiseli kupus',
        'kupus',
        'kupus mladi',
        'kupus salata zelena',
        'salata zelena',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pecurke sampinjoni',
      displayName: 'Šampinjoni',
      aliases: [
        'pecurke sampinjoni',
        'sampinjoni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'danubius makarone testenina',
      displayName: 'Danubius Testenina',
      aliases: [
        'danubius makarone',
        'danubius makarone testenina',
        'danubius rezanci',
        'danubius spagete',
        'danubius testenina',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'barilla spagete testenina',
      displayName: 'Barilla Testenina / Špagete',
      aliases: [
        'barilla fusilli',
        'barilla penne',
        'barilla spagete',
        'barilla spagete testenina',
        'barilla testenina',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'brasno klas puder zlatni',
      displayName: 'Klas Brašno / Zlatni puder (BiH)',
      aliases: [
        'bih brasno klas puder zlatni',
        'brasno klas',
        'brasno klas puder zlatni',
        'brasno puder zlatni',
        'klas tip400',
        'klas tip500',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bimal suncokretovo ulje',
      displayName: 'Bimal Ulje (BiH)',
      aliases: [
        'bih bimal ulje',
        'bimal suncokretovo ulje',
        'bimal ulje',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'maslinovo ulje',
      displayName: 'Maslinovo ulje',
      aliases: [
        'devicansko extra maslinovo ulje',
        'maslinovo monini ulje',
        'maslinovo ulje',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pirinac riza',
      displayName: 'Pirinač / Riža',
      aliases: [
        'benlian pirinac',
        'dugo pirinac zrno',
        'okruglo pirinac zrno',
        'pirinac',
        'pirinac riza',
        'riza',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'gradistanac pasulj tetovac',
      displayName: 'Pasulj',
      aliases: [
        'beli pasulj',
        'gradistanac pasulj tetovac',
        'pasulj',
        'pasulj tetovac',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'aleva crvena paprika',
      displayName: 'Aleva Paprika / Začin',
      aliases: [
        'aleva crvena paprika',
        'aleva kulinat',
        'aleva paprika',
        'aleva paprika slatka',
        'aleva paprika zacin',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'govedja kokosija podravka supa',
      displayName: 'Podravka / Maggi Supa iz kesice',
      aliases: [
        'alpska supa',
        'c supa',
        'govedja kokosija podravka supa',
        'govedja supa',
        'kesice maggi podravka supa',
        'kokosija supa',
        'maggi supa',
        'podravka supa',
        'supa yumis',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'c pecivo prasak secer vanilin',
      displayName: 'C Prašak za pecivo / Vanilin šećer / Puding',
      aliases: [
        'c pecivo prasak puding secer vanilin',
        'c pecivo prasak secer vanilin',
        'c puding',
        'dr oetker pecivo prasak',
        'dr oetker puding',
        'kvasac suvi',
        'pecivo prasak',
        'secer vanilin',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'c dijamant polimark senf',
      displayName: 'Senf',
      aliases: [
        'c dijamant polimark senf',
        'c senf',
        'dijamant senf',
        'polimark senf',
        'senf',
        'senf thommy',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'paradajz pasirani pelat tomatino',
      displayName: 'Pasirani paradajz / Tomatino',
      aliases: [
        'paradajz pasirani',
        'paradajz pasirani pelat tomatino',
        'paradajz pasirani tomatino',
        'paradajz pelat',
        'paradajz pire',
        'tomatello',
        'tomatino',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ajvar bakina dijamant tajna',
      displayName: 'Ajvar',
      aliases: [
        'ajvar',
        'ajvar bakina dijamant tajna',
        'ajvar bakina tajna',
        'ajvar blagi',
        'ajvar dijamant',
        'ajvar domaci',
        'ajvar ljuti',
        'ajvar podravka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'frikom grasak kukuruz povrce',
      displayName: 'Frikom Smrznuto povrće / Pomfrit',
      aliases: [
        'frikom grasak',
        'frikom grasak kukuruz povrce',
        'frikom kukuruz',
        'frikom lisnato testo',
        'frikom mesavina zlatna',
        'frikom pomfrit',
        'frikom pomfrit povrce smrznuto',
        'frikom ruska salata',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'frikom king macho sladoled',
      displayName: 'Frikom Sladoled',
      aliases: [
        'frikom king macho sladoled',
        'frikom sladoled',
        'kapri sladoled',
        'king sladoled',
        'macho sladoled',
        'quattro sladoled',
        'rumenko sladoled',
        'sladoled snesko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'prima slani stapici stark',
      displayName: 'Prima Slani štapići',
      aliases: [
        'kikirikijem sa stapici',
        'prima slani stapici',
        'prima slani stapici stark',
        'prima stapici',
        'prima stark',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bambi josh krekere ribice',
      displayName: 'Bambi Josh! Ribice / Krekeri',
      aliases: [
        'bambi josh',
        'bambi josh krekere ribice',
        'bambi josh krekeri ribice',
        'josh ribice',
        'krekeri tak',
        'ribice slane',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bambi keks wellness',
      displayName: 'Bambi Wellness Keks',
      aliases: [
        'bambi keks wellness',
        'bambi wellness',
        'keks wellness',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bambi keks pek zlatni',
      displayName: 'Zlatni Pek Keks',
      aliases: [
        'bambi keks pek zlatni',
        'bambi pek zlatni',
        'keks pek zlatni',
        'pek zlatni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'medeno pionir srce',
      displayName: 'Pionir Medeno Srce',
      aliases: [
        'medeno pionir srce',
        'medeno srce',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cokolada galeb pionir',
      displayName: 'Galeb Čokolada (Pionir)',
      aliases: [
        'bombona negro',
        'cokolada galeb',
        'cokolada galeb pionir',
        'galeb pionir',
        'negro pionir',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cipiripi eurokrem krem',
      displayName: 'Eurokrem / Cipiripi',
      aliases: [
        'cipiripi',
        'cipiripi eurokrem',
        'cipiripi eurokrem krem',
        'euroblok',
        'eurokrem',
        'eurokrem swisslion',
        'linolada',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'krem nutella',
      displayName: 'Nutella Krem',
      aliases: [
        'ferrero nutella',
        'krem nutella',
        'nutella',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bueno cokolada jaje kinder',
      displayName: 'Kinder Surprise / Bueno / Čokolada',
      aliases: [
        'bueno cokolada jaje kinder',
        'bueno cokolada kinder surprise',
        'bueno kinder',
        'chocolate kinder',
        'jaje kinder',
        'kinder maxi',
        'kinder pingui',
        'kinder surprise',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bounty mars snickers twix',
      displayName: 'Snickers / Mars / Twix / Bounty',
      aliases: [
        'bounty',
        'bounty mars snickers twix',
        'cokoladica lion',
        'cokoladica mars',
        'kat kit',
        'snickers',
        'twix',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cokolada dorina kras',
      displayName: 'Kraš Dorina / Bajadera / Domaćica',
      aliases: [
        'bajadera domacica dorina kras',
        'bombone ki',
        'bronhi',
        'cokolada dorina',
        'cokolada dorina kras',
        'domacica keks',
        'domacica kras',
        'dorina kras',
        'kras napolitanke',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'medela smokva strudla',
      displayName: 'Medela Štrudla',
      aliases: [
        'medela smokva strudla',
        'medela strudla',
        'medela strudle',
        'sa smokvom strudla',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'fun gudmark kikiriki',
      displayName: 'Pečeni kikiriki / Semenke',
      aliases: [
        'badem',
        'dietaplus kikiriki',
        'fun gudmark kikiriki',
        'gud kikiriki',
        'kikiriki',
        'kikiriki peceni',
        'kikiriki peceni semenke',
        'kikiriki slani',
        'lesnik',
        'orah',
        'semenke suncokretovo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'orbit zvake',
      displayName: 'Orbit / Airwaves Žvake',
      aliases: [
        'airwaves orbit zvake',
        'airwaves zvake',
        'five zvake',
        'orbit',
        'orbit zvake',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mineralna voda vrnjci',
      displayName: 'Voda Vrnjci',
      aliases: [
        'gazirana vrnjci',
        'mineralna voda vrnjci',
        'negazirana vrnjci',
        'voda vrnjci',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'heba mineralna voda',
      displayName: 'Heba Voda',
      aliases: [
        'heba mineralna voda',
        'heba voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jazak voda',
      displayName: 'Jazak Voda',
      aliases: [
        'jazak voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'gorska suza voda',
      displayName: 'Suza / Rada Voda (CG)',
      aliases: [
        'aqua bianca',
        'cg rada suza voda',
        'gorska suza voda',
        'gorska voda',
        'rada voda',
        'suza voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kiseljak sarajevski voda',
      displayName: 'Sarajevski Kiseljak / Vitinka (BiH)',
      aliases: [
        'bih kiseljak sarajevski vitinka',
        'kiseljak sarajevski',
        'kiseljak sarajevski voda',
        'kiseljak tesanjski',
        'oaza voda',
        'vitinka voda',
        'vivia voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'fanta sok',
      displayName: 'Fanta',
      aliases: [
        'fanta',
        'fanta orange',
        'fanta shokata',
        'fanta sok',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'sok sprite',
      displayName: 'Sprite',
      aliases: [
        'gazirani sprite',
        'sok sprite',
        'sprite',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bitter lemon schweppes tonic',
      displayName: 'Schweppes',
      aliases: [
        'bitter lemon schweppes',
        'bitter lemon schweppes tonic',
        'schweppes',
        'schweppes tangerine',
        'schweppes tonic',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cockta sok',
      displayName: 'Cockta',
      aliases: [
        'cockta',
        'cockta original',
        'cockta sok',
        'kokta',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'guarana knjaz milos remix',
      displayName: 'Guarana / Remix Knjaz',
      aliases: [
        'bull red',
        'energetsko guarana pice',
        'energy hell',
        'energy monster',
        'energy ultra',
        'guarana',
        'guarana knjaz milos remix',
        'guarana knjaz remix',
        'knjaz remix',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cedevita napitak',
      displayName: 'Cedevita',
      aliases: [
        'cedevita',
        'cedevita limun',
        'cedevita napitak',
        'cedevita narandza',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'fruvita sok',
      displayName: 'Fruvita / Rauch / Bravo Sok',
      aliases: [
        'bravo fruvita rauch sok',
        'bravo sok',
        'day happy rauch',
        'fruvita',
        'fruvita sok',
        'sok takovo',
        'sok vita',
        'sok zupski',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'heineken pivo',
      displayName: 'Heineken Pivo',
      aliases: [
        'heineken pivo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pivo tuborg',
      displayName: 'Tuborg Pivo',
      aliases: [
        'carlsberg pivo',
        'pivo tuborg',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'pivo staropramen',
      displayName: 'Staropramen / Stella Artois Pivo',
      aliases: [
        'amstel pivo',
        'artois pivo staropramen stella',
        'artois stella',
        'bavaria pivo',
        'birra moretti',
        'pivo staropramen',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jagodinsko nisko pivo valjevsko',
      displayName: 'Valjevsko / Niško Pivo',
      aliases: [
        'banjalucko pivo',
        'jagodinsko nisko pivo valjevsko',
        'nisko pivo',
        'nisko pivo valjevsko',
        'pivo tuzlansko',
        'pivo valjevsko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bonito kafa',
      displayName: 'Bonito / C Kafa',
      aliases: [
        'bonito c kafa',
        'bonito kafa',
        'c kafa',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dzezva kafa vispak zlatna',
      displayName: 'Zlatna Džezva Kafa (BiH)',
      aliases: [
        'bih dzezva kafa zlatna',
        'dzezva kafa vispak zlatna',
        'dzezva kafa zlatna',
        'dzezva zlatna',
        'kafa vispak',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'caj fruktonal milford',
      displayName: 'Fructus / Milford Čaj',
      aliases: [
        'caj fructus',
        'caj fructus milford',
        'caj fruktonal milford',
        'caj hibiskus',
        'caj kamilica',
        'caj milford',
        'caj nana',
        'caj podravka',
        'caj zeleni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ariel deterdzent kapsule tecni',
      displayName: 'Ariel Deterdžent za veš',
      aliases: [
        'ariel deterdzent kapsule tecni',
        'ariel deterdzent tecni',
        'ariel deterdzent ves',
        'ariel kapsule',
        'ariel pods',
        'ariel prasak',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'deterdzent persil',
      displayName: 'Persil / Perwoll Deterdžent',
      aliases: [
        'bonux deterdzent',
        'deterdzent persil',
        'deterdzent persil perwoll',
        'deterdzent perwoll',
        'deterdzent rubel',
        'deterdzent tide',
        'gel persil',
        'kapsule persil',
        'persil prasak',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'lenor omeksivac silan',
      displayName: 'Lenor / Silan / Ornel Omekšivač',
      aliases: [
        'bohor omeksivac',
        'lenor omeksivac',
        'lenor omeksivac ornel silan',
        'lenor omeksivac silan',
        'omeksivac ornel',
        'omeksivac silan',
        'omeksivac violeta',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'finish masinu somat tablete',
      displayName: 'Finish / Somat Tablete za sudomašinu',
      aliases: [
        'finish masinu somat tablete',
        'finish quantum',
        'finish somat sudomasinu tablete',
        'finish tablete',
        'gold somat',
        'sjaj sudomasinu',
        'so sudomasinu',
        'somat tablete',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bref cif domestos sredstvo',
      displayName: 'Domestos / Cif / Bref Hemija',
      aliases: [
        'ajax sredstvo',
        'bref cif domestos hemija',
        'bref cif domestos sredstvo',
        'bref wc',
        'cif krem',
        'clin',
        'domestos',
        'mr proper',
        'pronto',
        'sanitar wc',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'paloma papir toalet violeta zewa',
      displayName: 'Zewa / Paloma / Violeta Toalet papir',
      aliases: [
        'becutan maramice vlazne',
        'kuhinjski ubrusi',
        'maramice papirne',
        'maramice vlazne',
        'paloma papir toalet',
        'paloma papir toalet violeta zewa',
        'papir toalet violeta',
        'papir toalet zewa',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'aquafresh colgate pasta sensodyne zube',
      displayName: 'Colgate / Sensodyne Pasta za zube',
      aliases: [
        'aquafresh colgate pasta sensodyne zube',
        'aquafresh pasta',
        'blend med',
        'cetkica zube',
        'colgate pasta',
        'colgate pasta sensodyne zube',
        'parodontax',
        'pasta sensodyne',
        'pasta zube',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dove kupka nivea palmolive sapun',
      displayName: 'Nivea / Dove / Palmolive Higijena',
      aliases: [
        'dezodorans nivea',
        'dezodorans rexona',
        'dove higijena nivea palmolive',
        'dove kupka',
        'dove kupka nivea palmolive sapun',
        'dove sapun',
        'fa kupka',
        'gel nivea tusiranje',
        'kosili kupka',
        'krema nivea',
        'kupka palmolive',
        'old spice',
        'palmolive sapun',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'head pantene sampon shoulders',
      displayName: 'Šampon za kosu (H&S / Pantene / Wash&Go)',
      aliases: [
        'afrodita sampon',
        'gliss sampon',
        'go kosu pantene sampon wash',
        'go sampon wash',
        'head pantene sampon shoulders',
        'head sampon shoulders',
        'koprive sampon',
        'pantene sampon',
        'sampon schauma',
        'sampon syoss',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'always libero pampers pelene ulosci',
      displayName: 'Always Ulošci / Pampers Pelene',
      aliases: [
        'always libero pampers pelene ulosci',
        'always pampers pelene ulosci',
        'always ulosci',
        'babylove pelene',
        'libresse ulosci',
        'pampers pelene',
        'pelene violeta',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'biorazgradiva tregerica',
      displayName: 'Kesa (plastična / biorazgradiva)',
      aliases: [
        'alu',
        'biorazgradiva',
        'biorazgradiva kesa plasticna',
        'biorazgradiva plasticna',
        'biorazgradiva tregerica',
        'kesa',
        'papir pecenje',
        'providna',
        'smece',
        'tregerica',
        'velika',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dizel evro gorivo',
      displayName: 'Evro dizel (Gorivo)',
      aliases: [
        'diesel drive',
        'diesel euro',
        'diesel max',
        'diesel maxmotion',
        'dizel drive',
        'dizel evro',
        'dizel evro gorivo',
        'ectodiesel',
        'eurodizel',
        'ultra',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'benzin bmb evro premijum',
      displayName: 'Evro Premijum BMB 95 / 100 (Benzin)',
      aliases: [
        'benzin bmb evro premijum',
        'benzin bmb95 evro premijum',
        'bmb',
        'bmb evro premijum',
        'bmb95',
        'drive',
        'eurosuper',
        'maxmotion',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'auto gas lpg tng',
      displayName: 'TNG / Auto-gas (LPG)',
      aliases: [
        'auto gas',
        'auto gas lpg tng',
        'autogas',
        'gas naftni tecni',
        'lpg',
        'tng',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'stakla tecnost vetrobran',
      displayName: 'Tečnost za vetrobransko staklo',
      aliases: [
        'adblue',
        'adeblue',
        'letnja stakla tecnost',
        'stakla tecnost',
        'stakla tecnost vetrobran',
        'stakla tecnost zimska',
        'tecnost vetrobransko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'nutela sokolad tecen',
      displayName: 'Tecen Sokolad Nutela',
      aliases: [
        'nutela sokolad tecen',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'barilla basilico',
      displayName: 'Barilla Basilico',
      aliases: [
        'barilla basilico',
        'barilla classico',
        'basilico',
        'classico',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'all barilla lasagne uovo',
      displayName: 'Barilla Lasagne All Uovo',
      aliases: [
        'all barilla lasagne uovo',
        'all lasagne uovo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'original wasa',
      displayName: 'Wasa Original',
      aliases: [
        'original',
        'original wasa',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kinder pingui',
      displayName: 'Kinder Pingui',
      aliases: [
        'kinder pingui',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cookies cream drink protein zott',
      displayName: 'Zott Protein Drink Cream Cookies',
      aliases: [
        'cookies cream drink protein',
        'cookies cream drink protein zott',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ferrero rocher',
      displayName: 'Ferrero Rocher',
      aliases: [
        'ferrero rocher',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'nesquik nestl',
      displayName: 'Nestl Nesquik',
      aliases: [
        'nesquik',
        'nesquik nestl',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'and cake choc milka',
      displayName: 'Milka Cake And Choc',
      aliases: [
        'and cake choc milka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'alpro badem kokos napitak',
      displayName: 'Alpro Napitak Kokos Badem',
      aliases: [
        'alpro badem kokos napitak',
        'badem kokos napitak',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'protein pudding zott',
      displayName: 'Zott Protein Pudding',
      aliases: [
        'protein pudding',
        'protein pudding zott',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ab barilla sesam sverige',
      displayName: 'Barilla Sverige Ab Sesam',
      aliases: [
        'ab barilla sesam sverige',
        'sesam',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'milka strawberry',
      displayName: 'Milka Strawberry',
      aliases: [
        'milka strawberry',
        'strawberry',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'integrale riso venere',
      displayName: 'Riso Integrale Venere',
      aliases: [
        'integrale riso venere',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'blagi kecap polimark',
      displayName: 'Polimark Kečap Blagi',
      aliases: [
        'blagi kecap',
        'blagi kecap polimark',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'jamnica mineralna voda',
      displayName: 'Jamnica Mineralna Voda',
      aliases: [
        'jamnica mineralna voda',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'divella ristorante spaghetti',
      displayName: 'Divella Spaghetti Ristorante',
      aliases: [
        'divella ristorante spaghetti',
        'ristorante spaghetti',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bambi cokolada wellness',
      displayName: 'Bambi Wellness Čokolada',
      aliases: [
        'bambi cokolada wellness',
        'cokolada wellness',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'divella penne rigate ziti',
      displayName: 'Divella Penne Ziti Rigate',
      aliases: [
        'divella penne rigate ziti',
        'penne rigate ziti',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'fresh milk oreo snack',
      displayName: 'Oreo Fresh Milk Snack',
      aliases: [
        'fresh milk oreo snack',
        'fresh milk snack',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'sitna so solana tuzla tuzlanska',
      displayName: 'Solana Tuzla Tuzlanska So Sitna',
      aliases: [
        'sitna so solana tuzla tuzlanska',
        'sitna so tuzlanska',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'can sprite',
      displayName: 'Sprite Can',
      aliases: [
        'can sprite',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cerealitalia corn flakes',
      displayName: 'Cerealitalia Corn Flakes',
      aliases: [
        'cerealitalia corn flakes',
        'corn flakes',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crvenka jaffa nutri ocake',
      displayName: 'Jaffa Crvenka Nutri Ocake',
      aliases: [
        'crvenka jaffa nutri ocake',
        'nutri ocake',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'divella fusilli',
      displayName: 'Divella Fusilli',
      aliases: [
        'divella fusilli',
        'fusilli',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'duo lada lino',
      displayName: 'Lino Lada Duo',
      aliases: [
        'duo lada lino',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kajmak mlekara namaz sabac',
      displayName: 'Mlekara Sabac Kajmak Namaz',
      aliases: [
        'kajmak mlekara namaz sabac',
        'kajmak namaz',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'fitnesa lab nutrino snack',
      displayName: 'Nutrino Lab Fitnesa Snack',
      aliases: [
        'fitnesa lab nutrino snack',
        'fitnesa snack',
        'fruit lab nutrino snack',
        'fruit snack',
        'lab nutrino power snack',
        'power snack',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'divella linguine',
      displayName: 'Divella Linguine',
      aliases: [
        'divella linguine',
        'linguine',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bakes belvita soft',
      displayName: 'Belvita Soft Bakes',
      aliases: [
        'bakes belvita soft',
        'bakes soft',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bar chocolate milk protein proteini si',
      displayName: 'Proteini Si Protein Bar Milk Chocolate',
      aliases: [
        'bar chocolate milk protein',
        'bar chocolate milk protein proteini si',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'alpro poj zov',
      displayName: 'Alpro Zov Poj',
      aliases: [
        'alpro poj zov',
        'poj zov',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'flips stobi vitaminka',
      displayName: 'Vitaminka Stobi Flips',
      aliases: [
        'flips stobi',
        'flips stobi vitaminka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'choc milk protein zbregov',
      displayName: 'Zbregov Protein Choc Milk',
      aliases: [
        'choc milk protein',
        'choc milk protein zbregov',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cocoa croissant days filling with',
      displayName: 'Days Croissant With Cocoa Filling',
      aliases: [
        'cocoa croissant days filling with',
        'cocoa croissant filling with',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'coffee ice landessa latte macchiato',
      displayName: 'Landessa Latte Macchiato Ice Coffee',
      aliases: [
        'coffee ice landessa latte macchiato',
        'coffee ice latte macchiato',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'delight fat less thomy',
      displayName: 'Thomy Delight Less Fat',
      aliases: [
        'delight fat less',
        'delight fat less thomy',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'chipsy domacinski kajmak',
      displayName: 'Chipsy Domacinski Kajmak',
      aliases: [
        'chipsy domacinski kajmak',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'chocolate dark kandit mix nuts',
      displayName: 'Kandit Dark Chocolate Mix Nuts',
      aliases: [
        'chocolate dark kandit mix nuts',
        'chocolate dark mix nuts',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'feta president somborska',
      displayName: 'President Somborska Feta',
      aliases: [
        'feta president somborska',
        'feta somborska',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'divella rigatoni',
      displayName: 'Divella Rigatoni',
      aliases: [
        'divella rigatoni',
        'rigatoni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'aia frankfurt hrenovke',
      displayName: 'Aia Hrenovke Frankfurt',
      aliases: [
        'aia frankfurt hrenovke',
        'frankfurt hrenovke',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'divella pastina stelline',
      displayName: 'Pastina Divella Stelline',
      aliases: [
        'divella pastina stelline',
        'stelline',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cokolino fit podravka',
      displayName: 'Podravka Cokolino Fit',
      aliases: [
        'cokolino fit',
        'cokolino fit podravka',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'istarska passata podravka rajcica',
      displayName: 'Podravka Passata Istarska Rajcica',
      aliases: [
        'istarska passata podravka rajcica',
        'istarska passata rajcica',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'nutribella',
      displayName: 'Nutribella',
      aliases: [
        'nutribella',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cips doritos doritps nacho',
      displayName: 'Doritos Cips Doritps Nacho',
      aliases: [
        'cips doritos doritps nacho',
        'cips doritps nacho',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'doritos taco',
      displayName: 'Doritos Taco',
      aliases: [
        'doritos taco',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'orangina original',
      displayName: 'Orangina Original',
      aliases: [
        'orangina original',
        'original',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'canelloni divella',
      displayName: 'Divella Canelloni',
      aliases: [
        'canelloni',
        'canelloni divella',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'in musli tekmar yoghurt',
      displayName: 'Tekmar Musli In Yoghurt',
      aliases: [
        'in musli tekmar yoghurt',
        'in musli yoghurt',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'divella vermicelli',
      displayName: 'Divella Vermicelli',
      aliases: [
        'divella vermicelli',
        'vermicelli',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'indomie noodles',
      displayName: 'Indomie Noodles',
      aliases: [
        'indomie noodles',
        'noodles',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'fit flakes fun oat',
      displayName: 'Fun Fit Oat Flakes',
      aliases: [
        'fit flakes fun oat',
        'flakes oat',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'carobnjaci takovo',
      displayName: 'Takovo Carobnjaci',
      aliases: [
        'carobnjaci',
        'carobnjaci takovo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bambi plus protein yes',
      displayName: 'Bambi Yes Protein Plus',
      aliases: [
        'bambi plus protein yes',
        'plus protein yes',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'mousse protein zott',
      displayName: 'Zott Protein Mousse',
      aliases: [
        'mousse protein',
        'mousse protein zott',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'argeta posna tuna',
      displayName: 'Argeta Posna Tuna',
      aliases: [
        'argeta posna tuna',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'fit mix mogyi',
      displayName: 'Mogyi Fit Mix',
      aliases: [
        'fit mix',
        'fit mix mogyi',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'delicatess mayonnaise nestl',
      displayName: 'Nestl Mayonnaise Delicatess',
      aliases: [
        'delicatess mayonnaise',
        'delicatess mayonnaise nestl',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'benedetto san still',
      displayName: 'San Benedetto Still',
      aliases: [
        'benedetto san still',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'butter go on peanut',
      displayName: 'Go On Peanut Butter',
      aliases: [
        'butter go on peanut',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kokos napitak proteinski zbregov',
      displayName: 'Zbregov Proteinski Napitak Kokos',
      aliases: [
        'kokos napitak proteinski',
        'kokos napitak proteinski zbregov',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'citrate magnesium now',
      displayName: 'Now Magnesium Citrate',
      aliases: [
        'citrate magnesium',
        'citrate magnesium now',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'humus',
      displayName: 'Humus',
      aliases: [
        'humus',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'chilli chipsy rebrasty',
      displayName: 'Chipsy Rebrasty Chilli',
      aliases: [
        'chilli chipsy rebrasty',
        'chilli rebrasty',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ceasar roleski sauce',
      displayName: 'Roleski Ceasar Sauce',
      aliases: [
        'ceasar roleski sauce',
        'ceasar sauce',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'lanom plocice sa tonus',
      displayName: 'Tonus Plocice sa Lanom',
      aliases: [
        'lanom plocice sa',
        'lanom plocice sa tonus',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'albeni bar cake lker',
      displayName: 'Lker Albeni Bar Cake',
      aliases: [
        'albeni bar cake',
        'albeni bar cake lker',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'heinz italian sauce',
      displayName: 'Heinz Italian Sauce',
      aliases: [
        'heinz italian sauce',
        'italian sauce',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'magnesium protein tekmar',
      displayName: 'Tekmar Protein Magnesium',
      aliases: [
        'magnesium protein',
        'magnesium protein tekmar',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'biorazgradiva kesa tregerica',
      displayName: 'Kesa (plastična / biorazgradiva)',
      aliases: [
        'alu',
        'biorazgradiva kesa',
        'biorazgradiva kesa plasticna',
        'biorazgradiva kesa tregerica',
        'kesa',
        'kesa smece',
        'kesa tregerica',
        'kesa velika',
        'papir pecenje',
        'providna',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'benzin bmb95 evro premijum',
      displayName: 'Evro Premijum BMB 95 (Benzin)',
      aliases: [
        'benzin bmb95 evro premijum',
        'bmb100',
        'bmb95',
        'bmb95 ep evo',
        'bmb95 ep omv',
        'bmb95 evro premijum',
        'drive',
        'eurosuper',
        'maxmotion',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dostava usluga',
      displayName: 'Dostava (Usluga dostave)',
      aliases: [
        'delivery item',
        'doplata dostava',
        'dostava',
        'dostava mp robe usluga',
        'dostava troskovi',
        'dostava usluga',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'parkiranje usluga',
      displayName: 'Usluga parkiranja',
      aliases: [
        'karta parking',
        'parkiranje',
        'parkiranje usluga',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'alesto cerneaux de noix',
      displayName: 'Alesto Cerneaux De Noix',
      aliases: [
        'alesto cerneaux de noix',
        'cerneaux de noix',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'alesto mjesavina orasastog voca',
      displayName: 'Alesto Mjesavina Orasastog Voca',
      aliases: [
        'alesto mjesavina orasastog voca',
        'mjesavina orasastog voca',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cocoa dark excellence intense lindt',
      displayName: 'Lindt Excellence Cocoa Intense Dark',
      aliases: [
        'cocoa dark excellence intense',
        'cocoa dark excellence intense lindt',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'buo cioccolato fondente',
      displayName: 'Buo Cioccolato Fondente',
      aliases: [
        'buo cioccolato fondente',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crispbread grain rye whole',
      displayName: 'Rye Crispbread Whole Grain',
      aliases: [
        'crispbread grain rye whole',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'chip choco galletas gullon zero',
      displayName: 'Galletas Gullon Zero Chip Choco',
      aliases: [
        'chip choco galletas gullon zero',
        'chip choco zero',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bueno kinder white',
      displayName: 'Kinder Bueno White',
      aliases: [
        'bueno kinder white',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'barilla penne rigate rigatoni',
      displayName: 'Barilla Rigatoni Penne Rigate',
      aliases: [
        'barilla penne rigate rigatoni',
        'penne rigate rigatoni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ketchup tomato',
      displayName: 'Tomato Ketchup',
      aliases: [
        'ketchup tomato',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'originale pringles',
      displayName: 'Pringles Originale',
      aliases: [
        'originale pringles',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crownfield knusper schoko sli',
      displayName: 'Crownfield Knusper Sli Schoko',
      aliases: [
        'crownfield knusper schoko sli',
        'knusper schoko sli',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'deluxe pistaziencreme',
      displayName: 'Deluxe Pistaziencreme',
      aliases: [
        'deluxe pistaziencreme',
        'pistaziencreme',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cocoa dark extra lidl',
      displayName: 'Lidl Extra Dark Cocoa',
      aliases: [
        'cocoa dark extra',
        'cocoa dark extra lidl',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cioccolato gusto lidl mousse proteica',
      displayName: 'Lidl Mousse Proteica Gusto Cioccolato',
      aliases: [
        'cioccolato gusto lidl mousse proteica',
        'cioccolato gusto mousse proteica',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crownfield pahuljice zobene',
      displayName: 'Crownfield Zobene Pahuljice',
      aliases: [
        'crownfield pahuljice zobene',
        'pahuljice zobene',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'grafschafter tortilla wraps',
      displayName: 'Grafschafter Tortilla Wraps',
      aliases: [
        'grafschafter tortilla wraps',
        'tortilla wraps',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'high lidl protein wraps',
      displayName: 'Lidl High Protein Wraps',
      aliases: [
        'high lidl protein wraps',
        'high protein wraps',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bianco galletas galletti mulino',
      displayName: 'Galletas Mulino Bianco Galletti',
      aliases: [
        'bianco galletas galletti mulino',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bio crownfield dki oveseni',
      displayName: 'Crownfield Bio Oveseni Dki',
      aliases: [
        'bio crownfield dki oveseni',
        'bio dki oveseni',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'classic pilos protein skyr',
      displayName: 'Pilos Skyr Classic Protein',
      aliases: [
        'classic pilos protein skyr',
        'classic protein skyr',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'tofu vemondo',
      displayName: 'Tofu Vemondo',
      aliases: [
        'tofu vemondo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'chocolate kinder',
      displayName: 'Kinder Chocolate',
      aliases: [
        'chocolate',
        'chocolate kinder',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'original tuc',
      displayName: 'Tuc Original',
      aliases: [
        'original tuc',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bruschette chips mandel',
      displayName: 'Mandel Bruschette Chips',
      aliases: [
        'bruschette chips',
        'bruschette chips mandel',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'alesto classic fruit mix nut',
      displayName: 'Alesto Nut Fruit Mix Classic',
      aliases: [
        'alesto classic fruit mix nut',
        'classic fruit mix nut',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'caprice papadopoulos puricki',
      displayName: 'Papadopoulos Puricki Caprice',
      aliases: [
        'caprice papadopoulos puricki',
        'caprice puricki',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'dmbio kokos',
      displayName: 'Dmbio Kokos',
      aliases: [
        'dmbio kokos',
        'kokos',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'premium sli',
      displayName: 'Premium Sli',
      aliases: [
        'premium sli',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'chocolate dark schogetten',
      displayName: 'Schogetten Dark Chocolate',
      aliases: [
        'chocolate dark schogetten',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'chocolate cocoa dark heidi',
      displayName: 'Heidi Dark Chocolate Cocoa',
      aliases: [
        'chocolate cocoa dark',
        'chocolate cocoa dark heidi',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'butter pilos',
      displayName: 'Pilos Butter',
      aliases: [
        'butter',
        'butter pilos',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crownfield flakes oat rolled',
      displayName: 'Crownfield Rolled Oat Flakes',
      aliases: [
        'crownfield flakes oat rolled',
        'flakes oat rolled',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'berio classic filippo pesto',
      displayName: 'Filippo Berio Classic Pesto',
      aliases: [
        'berio classic filippo pesto',
        'classic pesto',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ricotta zanetti',
      displayName: 'Zanetti Ricotta',
      aliases: [
        'ricotta',
        'ricotta zanetti',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'noodles soba vitasia',
      displayName: 'Vitasia Soba Noodles',
      aliases: [
        'noodles soba',
        'noodles soba vitasia',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'coconut freshona milk',
      displayName: 'Freshona Coconut Milk',
      aliases: [
        'coconut freshona milk',
        'coconut milk',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bevanda cocco riso vemondo',
      displayName: 'Vemondo Bevanda Cocco Riso',
      aliases: [
        'bevanda cocco riso',
        'bevanda cocco riso vemondo',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'butter nature peanut promise',
      displayName: 'Nature Promise Peanut Butter',
      aliases: [
        'butter nature peanut promise',
        'butter peanut',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bites bruschette cheese maretti mixed',
      displayName: 'Maretti Bruschette Bites Mixed Cheese',
      aliases: [
        'bites bruschette cheese maretti mixed',
        'bites bruschette cheese mixed',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cokoladice kinder',
      displayName: 'Kinder Cokoladice',
      aliases: [
        'cokoladice kinder',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'coated crispy peanuts vitasia wasabi',
      displayName: 'Vitasia Wasabi Crispy Coated Peanuts',
      aliases: [
        'coated crispy peanuts vitasia wasabi',
        'coated crispy peanuts wasabi',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'crownfield crunchy',
      displayName: 'Crownfield Crunchy',
      aliases: [
        'crownfield crunchy',
        'crunchy',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'alpine chocolate milk schogetten',
      displayName: 'Schogetten Alpine Milk Chocolate',
      aliases: [
        'alpine chocolate milk schogetten',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'ar maggi mes',
      displayName: 'Maggi Ar Mes',
      aliases: [
        'ar maggi mes',
        'ar mes',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'nature promise',
      displayName: 'Nature Promise',
      aliases: [
        '100',
        'nature promise',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'free ikea kafferep oat sugar',
      displayName: 'Ikea Kafferep Oat Sugar Free',
      aliases: [
        'free ikea kafferep oat sugar',
        'free kafferep oat sugar',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kakaovou lidl pln susenky',
      displayName: 'Lidl Susenky Pln Kakaovou',
      aliases: [
        'kakaovou lidl pln susenky',
        'kakaovou pln susenky',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'alpsko ljubljanske mlekarne mleko',
      displayName: 'Ljubljanske Mlekarne Alpsko Mleko',
      aliases: [
        'alpsko ljubljanske mlekarne mleko',
        'alpsko mleko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'chio stickletti',
      displayName: 'Chio Stickletti',
      aliases: [
        'chio stickletti',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'el teqquito tortilla wraps',
      displayName: 'El Teqquito Tortilla Wraps',
      aliases: [
        'el teqquito tortilla wraps',
        'tortilla wraps',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'bonduelle crveni pasulj',
      displayName: 'Bonduelle Crveni Pasulj',
      aliases: [
        'bonduelle crveni pasulj',
        'crveni pasulj',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cacao dark supreme valor',
      displayName: 'Valor Cacao Supreme Dark',
      aliases: [
        'cacao dark supreme',
        'cacao dark supreme valor',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'arla cheese cream natural',
      displayName: 'Arla Natural Cream Cheese',
      aliases: [
        'arla cheese cream natural',
        'cheese cream natural',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'juha kokosja podravka tjesteninom',
      displayName: 'Podravka Kokosja Juha Tjesteninom',
      aliases: [
        'juha kokosja podravka tjesteninom',
        'juha kokosja tjesteninom',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'krem mlek sir sveze',
      displayName: 'Mlek Sveže Krem Sir',
      aliases: [
        'krem mlek sir sveze',
        'krem sir sveze',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'smoki',
      displayName: 'Smoki',
      aliases: [
        'smoki',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'guarana',
      displayName: 'Guarana',
      aliases: [
        'guarana',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'cokoladno dukat mleko',
      displayName: 'Dukat Cokoladno Mleko',
      aliases: [
        'cokoladno dukat mleko',
        'cokoladno mleko',
      ],
    ),
    SeedItemEntry(
      canonicalKey: 'kajmak',
      displayName: 'Kajmak',
      aliases: [
        'kajmak',
      ],
    ),
  ];
}
