# Task (budući): Procesiranje računa iz više zemalja + više valuta

> **Status: NIJE IMPLEMENTIRANO.** Ovo je dokumentovan predlog za kasniju implementaciju.
> Republika Srpska (Faza A) + Crna Gora (Faza B). Uvodi i podršku za više valuta.

## Kontekst

Aplikacija trenutno procesira **isključivo srpske** fiskalne račune: skenira QR → URL ka
`suf.purs.gov.rs` → fetch HTML žurnala + AJAX `/specifications` → parsiranje (ćirilični
markeri, srpske poreske oznake) → upis. Svuda je „Srbija" implicitno zakucano; ne postoji
koncept zemlje ni valute (RSD je zakucan u `MoneyFormat`).

### Nalaz istraživanja (ključno)

| Zemlja | Sistem | Verifikacioni portal | Uklapanje u arhitekturu |
|---|---|---|---|
| **Republika Srpska (BiH)** | **Isti TaxCore** (Data Tech International), kao Srbija | `suf.poreskaupravars.org/v/?vl=…` | **Skoro identično.** Isti URL format, isti žurnal u `<pre>`, isti `/specifications` AJAX. Postojeći parser radi gotovo netaknut. Valuta: **BAM (KM)**. |
| **Crna Gora (MNE)** | **EFI** (drugačiji sistem: IKOF/JIKR) | `mapr.tax.gov.me/ic/` | Drugačiji portal i format računa, verovatno bez `/specifications`. Traži **nov parser i reverse-engineering** stvarnih računa. Valuta: **EUR**. |

**Zaključak:** „isti način" je izvodljiv za **Republiku Srpsku odmah** (isti TaxCore). Za
**Crnu Goru** je izvodljivo ali zahteva poseban parser → zasebna kasnija faza.

---

## Faza A: Arhitektura za više zemalja + više valuta + Republika Srpska

### 1. `Country` enum
Novi fajl `lib/core/domain/country.dart`:
```dart
enum Country { serbia, republikaSrpska } // montenegro dolazi u Fazi B

extension CountryX on Country {
  /// Host suffix verifikacionog portala (TaxCore).
  String get portalHost => switch (this) {
        Country.serbia => 'suf.purs.gov.rs',
        Country.republikaSrpska => 'suf.poreskaupravars.org',
      };

  Currency get currency => switch (this) {
        Country.serbia => Currency.rsd,
        Country.republikaSrpska => Currency.bam,
      };
}
```
RS i Srbija dele isti TaxCore, pa je za RS dovoljno **samo dodati host** — bez novog parsera.

### 2. URL validacija — prepoznati zemlju iz hosta
`lib/features/scan/domain/verification_url.dart`: zameniti zakucani `_verificationHostSuffix`
proverom kroz **listu svih `Country.portalHost`**. Validator prepoznaje koji host je pogođen
i u `ValidVerificationUrl` dodaje polje `country`. Ako nijedan host ne odgovara →
`InvalidReason.wrongHost` (kao i sad). Token (`vl`) logika ostaje ista.

### 3. Provesti `country` kroz tok
- `ScanController.process` (`lib/features/scan/presentation/scan_controller.dart`):
  `valid.country` se prosleđuje dalje. RS i Srbija koriste **isti `TaxCoreClient` i isti
  parser**, pa `receiptSourceProvider` ostaje jedan (`TaxCoreClient`) — fetch ide na
  `valid.normalizedUrl` bez obzira na host. **Nije potreban novi `ReceiptSource` za RS.**
- `repo.saveParsed(...)` (`lib/features/receipts/data/receipt_repository.dart`): primiti
  `country` i upisati `country` + izvedeni `currency`.

### 4. Valuta — `currency` kolona po računu (KLJUČNO)

**Problem:** Iznosi su sada svuda zakucani kao RSD (`MoneyFormat` ima fiksni `symbol: 'RSD'`,
`lib/core/utils/money_format.dart:13`). Čim uđu RS (BAM) i kasnije CG (EUR), iznosi imaju
različite valute, a analitika radi sirovi `SUM(totalAmount)`
(`analytics_repository.dart:88,113,137`) — sabiranje RSD+BAM+EUR daje besmislen broj.

**Odluka: `currency` kolona po računu.**
- Nov `enum Currency { rsd, bam, eur }` u `lib/core/domain/currency.dart`, sa ISO kodom i
  simbolom. Iznosi **ostaju `int` minor units** (1/100), samo dobijaju pridruženu valutu.
- Valuta se **izvodi iz zemlje** pri upisu (`Country.currency` getter) — bez zasebnog izvora.
- Dodati `currency` kolonu na `Receipts` (stavke dele valutu računa, pa je na `LineItems`
  opciono).

```dart
// tables.dart → Receipts
IntColumn get country =>
    intEnum<Country>().withDefault(Constant(Country.serbia.index))();
IntColumn get currency =>
    intEnum<Currency>().withDefault(Constant(Currency.rsd.index))();
```

**Formatiranje:** `MoneyFormat` parametrizovati valutom —
`MoneyFormat.fromMinor(int minor, Currency currency)` koji bira simbol/locale po valuti
(RSD `sr_RS`, BAM/`KM`, EUR `€`). Postojeći pozivi (`receipt_detail_screen.dart`,
`receipt_list_screen.dart`, analitika) prosleđuju valutu iz svog reda.

### 5. Analitika — grupisanje po valuti

Valute se ne smeju sabirati, pa se agregacije rade **po valuti** umesto jednog skalara:
- `analytics_repository.dart`: u svaku agregaciju (`_monthly`, `_byMerchant`,
  `_businessSplit`, `_topItems`, ukupno) dodati `currency` u `groupBy([...])`,
  tj. `SUM(...)` po (dimenzija, valuta).
- `analytics_models.dart`: `totalMinor` nosi `currency`, ili `AnalyticsSummary` postaje
  struktura **po valuti** (mapa/lista sekcija po valuti).
- `analytics_screen.dart`: `_TotalCard` i sekcije renderuju **zaseban blok po valuti**
  (npr. „120.000,00 RSD" pa ispod „340,00 KM"), bez ikakvog kursa. Kad je sve u jednoj valuti
  (današnji slučaj — sve RSD), prikaz izgleda isto kao sada.

**Bez kurseva/konverzije** — svesno izbegnuto (nema pouzdanog online izvora, kursevi po datumu
unose netačnost i složenost).

### 6. UI — zemlja/valuta (minimalno)
- Skener radi automatski: zemlja se prepoznaje iz QR hosta; valuta sledi iz zemlje.
- `ManualEntryScreen` (ručni unos URL-a): validacija prihvata i RS host — radi automatski.
- Detalj i lista računa: iznos u valuti tog računa; oznaka zemlje ako `country != serbia`.
  Novi stringovi u sva tri ARB-a (sr latinica/ćirilica + en).

### Ostala polja
Srpski-nazvana polja (`pfrNumber`, `pfrTime`, `taxLabel`, `paymentMethod`) **ostaju kao jesu**
— RS koristi isti TaxCore format (ćirilica, iste poreske oznake), pa postojeći
`JournalHeaderParser`/`JournalItemParser` rade bez izmena.

### Migracija baze
Bumpnuti `schemaVersion` + `onUpgrade` korak koji dodaje `country` i `currency` kolone;
postojeći zapisi → `serbia` / `rsd`. Pratiti postojeći migracioni obrazac (drift/sqlcipher).

### Kritični fajlovi (Faza A)
- `lib/core/domain/country.dart` — nov (enum + `portalHost` + `currency`)
- `lib/core/domain/currency.dart` — nov (enum + ISO kod + simbol/locale)
- `lib/core/utils/money_format.dart` — parametrizovati valutom
- `lib/features/scan/domain/verification_url.dart` — host lista + `country` u rezultatu
- `lib/features/scan/presentation/scan_controller.dart` — prosleđivanje `country`
- `lib/features/receipts/data/receipt_repository.dart` — `saveParsed(country:)` + upis `currency`
- `lib/core/db/tables.dart` + migracija — `country` i `currency` kolone
- `lib/features/analytics/data/analytics_repository.dart` — `groupBy` po valuti
- `lib/features/analytics/domain/analytics_models.dart` — agregati po valuti
- `lib/features/analytics/presentation/analytics_screen.dart` — blok po valuti
- `lib/features/receipts/presentation/{receipt_detail_screen,receipt_list_screen}.dart` — format sa valutom
- `test/unit/verification_url_test.dart` + test analitike sa više valuta

---

## Faza B (kasnije, zasebno): Crna Gora (EFI)

**Ne implementira se u Fazi A.** Traži:
1. **Reverse-engineering** stvarnih CG računa: format QR/URL-a (`mapr.tax.gov.me/ic/…`),
   kako portal servira podatke (HTML/JSON), postoji li ekvivalent `/specifications`.
2. Nov `MontenegroSource implements ReceiptSource` (`lib/features/source/data/`) +
   `MontenegroParser` (drugačiji markeri, IKOF/JIKR umesto PFR, moguće latinica,
   format datuma/brojeva).
3. `receiptSourceProvider` postaje `switch` po `country` (tek ovde postaje potreban — RS ga
   ne traži).
4. `Country.montenegro` u enum + host `mapr.tax.gov.me` + `Currency.eur` mapiranje. Pošto
   Faza A već uvodi `currency` kolonu i analitiku po valuti, EUR računi se odmah ispravno
   prikazuju i grupišu — **bez dodatnog rada na valuti**.
5. Eventualno mapiranje CG poreskih oznaka.

Tačka proširenja je čista jer Faza A već uvodi `Country` + `Currency` kroz ceo tok, a
`ReceiptSource` interfejs već postoji (`lib/features/source/domain/receipt_source.dart`).

---

## Ponovo korišćeno (bez novog koda)
- `ReceiptSource` interfejs (`lib/features/source/domain/receipt_source.dart`) — već
  apstrahovan; RS koristi postojeći `TaxCoreClient`.
- `TaxCoreParser`, `JournalHeaderParser`, `JournalItemParser`, `SpecificationsParser` — RS
  koristi netaknute (isti TaxCore format).
- `ReceiptRepository.saveParsed` / duplikat zaštita (`invoiceNumber`+`pfrNumber`) — proširuje
  se samo `country`/`currency` poljima.
- Postojeća Drift migraciona infrastruktura.

---

## Verifikacija (Faza A, end-to-end)
1. `fvm flutter analyze` — čisto.
2. Jedinični testovi:
   - `verification_url_test.dart`: `suf.poreskaupravars.org/v/?vl=…` → `republikaSrpska`;
     `suf.purs.gov.rs` → `serbia`; nepoznat host → `wrongHost`.
   - Mapiranje `Country.currency` (serbia→rsd, republikaSrpska→bam).
   - Analitika: test sa pomešanim RSD i BAM računima → zbirovi razdvojeni po valuti, nigde
     sabrani u jedan broj.
   - Migracija baze (stari zapis dobije `country = serbia`, `currency = rsd`).
3. Ručno na uređaju:
   - Skenirati/uneti **RS** URL (`suf.poreskaupravars.org`) → preuzme/parsira/sačuva;
     iznosi u **KM/BAM**.
   - Skenirati **srpski** URL → radi, iznosi u **RSD** (regresija).
   - Analitika sa računima iz obe zemlje → ukupno/mesec/prodavac **odvojeno po valuti**.
   - Nepoznat host → „Ovo nije fiskalni račun".
4. Postojeći (pre-migracija) računi rade, prikazuju se kao Srbija/RSD; analitika nad
   samo-RSD podacima izgleda nepromenjeno.

---

## Izvori (istraživanje)
- RS TaxCore portal: https://suf.poreskaupravars.org/ (Data Tech International, isti kao Srbija)
- RS „Provjeri račun" kampanja: https://www.novostiplus.org/bs/kako-gradjani-da-provjere-validnost-fiskalnog-racuna/
- CG EFI verifikacija (IKOF/JIKR): https://mapr.tax.gov.me/ic/ ,
  https://www.vatupdate.com/2023/09/22/receipt-verification-in-montenegro-fiscalization-system-methods-and-time-limit-for-validity/
