# Troškovnik — FREE MVP: skeniranje + preuzimanje računa sa Poreske

> Instrukcije za Claude Code za **prvi deo** (FREE verzija, bez AI-ja). Obim ovog dela:
> skeniranje QR koda fiskalnog računa → preuzimanje podataka sa `suf.purs.gov.rs` →
> rule-based parsiranje → čuvanje u lokalnu bazu → pregled. **AI se NE koristi** u ovom delu.
> Kategorizacija (AI) i pretplate dolaze kasnije i grade se nad ovim temeljom.

---

## 1. Obim ovog dela (scope)

**U obimu:**
- Skeniranje QR koda fiskalnog računa.
- Validacija i parsiranje verifikacionog URL-a (`suf.purs.gov.rs`).
- Preuzimanje podataka računa sa portala Poreske uprave (TaxCore „Verify Invoice").
- Rule-based parsiranje zaglavlja, ukupnih iznosa, poreza i **stavki** (bez AI-ja).
- Robusno rukovanje graničnim slučajem: **stavke još nisu dostupne** (račun nije stigao na server).
- Čuvanje u lokalnu enkriptovanu SQLite bazu; lista i detalj računa; pretraga.
- Ručni unos kao fallback kad QR ne valja.

**NIJE u obimu (kasnije):**
- AI kategorizacija stavki, budžeti, analitika, garancije, sinhronizacija, pretplate.
- (Ali model podataka ostavlja prostor: `category_id` nullable itd.)

## 2. Stack za ovaj deo
- **Projekat je u Flutter-u (Dart).** Android prvo, ali kod iOS-ready (bez Android-only API-ja gde nije nužno).
- **Verzijom Fluttera upravlja FVM (Flutter Version Management).** Obavezno:
  - Zakuj verziju kroz `fvm use <verzija>`; commit-uj `.fvmrc` (i `.fvm/` konfiguraciju) u repo da svi koriste istu verziju.
  - Sve Flutter/Dart komande idu kroz FVM: `fvm flutter ...`, `fvm dart ...` (npr. `fvm flutter pub get`, `fvm flutter run`, `fvm flutter test`).
  - U `.gitignore` ignoriši `.fvm/flutter_sdk` (simlink na keširani SDK), a NE i `.fvmrc`.
  - Podesi IDE/CI da koriste FVM SDK putanju (`.fvm/flutter_sdk`); CI korake (`analyze`, `test`) pokretati kroz `fvm flutter ...`.
  - U README-u dokumentuj: instalacija FVM-a, `fvm install`, pa `fvm flutter pub get`.
- Riverpod (state management).
- `drift` + SQLCipher (enkriptovana lokalna baza).
- `mobile_scanner` (QR), `image_picker` (opciono, skeniranje iz galerije).
- `dio` (HTTP ka `suf.purs.gov.rs`), `html` paket (parsiranje HTML stranice).
- `workmanager` (background re-fetch za granični slučaj), `flutter_local_notifications` (opciono obaveštenje kad se stavke dopune).
- Lokalizacija SR (default) / EN; RSD format.

## 3. Pozadina: kako TaxCore izlaže podatke (VAŽNO)

Srpski fiskalni QR sadrži **verifikacioni URL** oblika
`https://suf.purs.gov.rs/v/?vl=<TOKEN>`, gde je `<TOKEN>` potpisani, kodirani zapis internih
podataka računa. Sistem je TaxCore.

Postoje **dva nivoa podataka**, što je ključ celog ovog dela:

1. **Zaglavlje + tekstualni „žurnal" (journal / textual representation)** — ime prodavca, PIB,
   lokacija, datum/vreme, broj računa, PFR podaci, ukupan iznos, obračun poreza, i tekstualni
   ispis računa. Dostupno čim je verifikacioni URL validan.
2. **Izdvojene stavke (specifications)** — strukturirana lista artikala (naziv, količina,
   jedinična cena, ukupno, poreska oznaka). **Dostupno tek kad je račun prosleđen na server
   Poreske uprave.** Ako korisnik skenira odmah, a račun (iz bilo kog razloga) još nije poslat,
   strukturirane stavke neće postojati — to je granični slučaj koji moramo razraditi.

> **OBAVEZNO PRE IMPLEMENTACIJE PARSERA:** ručno uhvatiti **realne** odgovore portala za više
> stanja (kompletan račun; račun bez izdvojenih stavki; nepostojeći/neposlat račun; otkazan
> račun) i sačuvati ih kao test fixture fajlove. Parser graditi i testirati nad tim fajlovima,
> jer se tačan oblik (HTML struktura vs. JSON endpoint za specifikacije, nazivi polja) mora
> potvrditi empirijski, ne pretpostaviti. Parser drži iza interfejsa `ReceiptSource`.

### Predloženi tok preuzimanja (potvrditi nad realnim odgovorima)
1. Validiraj da je skenirani sadržaj URL sa host-om `suf.purs.gov.rs` i da ima `vl` parametar.
2. (Opciono, za offline otpornost) dekodiraj `vl` token da izvučeš bar minimum zaglavlja
   (ukupan iznos, datum/vreme, broj računa) i pre mrežnog poziva.
3. GET verifikacione stranice → parsiraj **zaglavlje + žurnal + status** (ispravan/otkazan).
4. Zatraži **izdvojene stavke** (specifications endpoint/POST koji koristi sama stranica):
   - Ako vrati stavke → parsiraj strukturirano (`items_source = specifications`).
   - Ako vrati prazno/grešku/„u obradi" → padni na parsiranje stavki iz **žurnal teksta**
     (`items_source = journal`), ako je žurnal prisutan.
   - Ako ni žurnal nema stavke → `items_status = pending`, zakaži re-fetch (vidi sekciju 5).

## 4. Model podataka (Drift — podskup za ovaj deo)

> **Konvencija imenovanja:** sva imena tabela i polja su na **engleskom** (snake_case), i kad
> izvorni naziv na PURS-u/računu jeste na srpskom. Srpski pojam navodi se samo kao komentar radi
> mapiranja. Vrednosti enum-a takođe na engleskom. (Korisnički vidljivi tekst se i dalje
> lokalizuje na SR/EN preko ARB-a — to je odvojeno od imena u šemi.)

Tabele (sa poljima bitnim sad; ostavi prostor za kasnije):

- **merchants** — `id`, `tin` (PIB), `name`, `location_name`, `address`, `first_seen`.
- **receipts**
  - identifikacija: `id`, `merchant_id` (FK), `invoice_number` (broj računa), `pfr_number` (PFR broj),
    `pfr_time` (PFR vreme), `sdc_time` (SDC vreme), `invoice_counter` (brojač računa),
    `invoice_type` (tip računa: `normal`/`proforma`/`copy`/`training`),
    `transaction_type` (`sale`/`refund`).
  - iznosi: `total_amount`, `payment_method`, `tax_json` (obračun po stopama).
  - izvor: `verification_url`, `token`, `journal_text` (žurnal; nullable).
  - stanje: `fetch_status` (enum, vidi 5), `items_status` (enum), `items_source`
    (`specifications`/`journal`/`none`), `retry_count`, `next_retry_at` (nullable).
  - korisničko: `is_business` (bool, default false), `image_path` (nullable), `note`.
  - meta: `created_at`, `updated_at`.
- **line_items** — `id`, `receipt_id` (FK), `name`, `quantity`, `unit` (jedinica mere),
  `unit_price`, `total`, `tax_label` (poreska oznaka), `tax_rate`, `source`
  (`specifications`/`journal`), `category_id` (nullable — za kasnije, NE koristi se sada).

Indeksi: po `merchants.name`, `line_items.name` (LIKE pretraga), `receipts.pfr_time`,
i jedinstveni ključ nad (`invoice_number` + `pfr_number`) da se isti račun ne upiše dvaput.

## 5. Granični slučaj: stavke još nisu dostupne (državni mehanizam)

Definiši dva enum-a sa jasnim stanjima i tranzicijama.

**`fetch_status`** (status preuzimanja celog računa):
- `pending` — još nije uspešno preuzeto sa servera (npr. nema mreže ili račun još nije na serveru).
- `headerOnly` — zaglavlje/žurnal preuzeti, ali bez izdvojenih stavki.
- `complete` — zaglavlje + stavke preuzeti.
- `invalid` — račun ne postoji / otkazan / token neispravan (trajno).

**`items_status`** (status stavki):
- `none` — nema stavki (još).
- `pendingServer` — račun postoji ali izdvojene stavke još nisu na serveru → re-fetch.
- `fromJournal` — stavke parsirane iz žurnal teksta (niža pouzdanost, prikazati indikator).
- `fromSpecifications` — strukturirane stavke sa servera (puna pouzdanost).

**Pravila prelaza:**
1. Skeniranje → uvek odmah sačuvaj zapis (čak i samo sa tokenom/zaglavljem) da korisnik ne izgubi račun.
2. Ako stavke nisu stigle (`pendingServer`): zakaži background re-fetch sa **eksponencijalnim backoff-om**
   (npr. +5 min, +30 min, +2 h, +6 h, +24 h; maksimalno N pokušaja, npr. 6). `next_retry_at` upiši u zapis.
3. `workmanager` periodični task obrađuje sve račune sa `items_status = pendingServer` i `next_retry_at <= sada`.
4. Kad re-fetch uspe → pređi na `fromSpecifications`, `fetch_status = complete`, (opciono) lokalna notifikacija „Stavke računa su dopunjene".
5. Korisnik uvek može ručno da pokrene „Osveži" na detalju računa.
6. Posle isteka svih pokušaja, a stavke i dalje nedostupne: ostavi `headerOnly` i ponudi
   ručni „Pokušaj ponovo" + (kasnije) opciju ručnog unosa stavki.

**UI tretman graničnog slučaja:**
- U listi: bedž „Stavke u obradi" na računima sa `pendingServer`.
- U detalju: jasno stanje („Račun je sačuvan. Prodavac ga još nije proknjižio kod Poreske;
  stavke će se automatski dopuniti.") + dugme „Osveži sada".
- Nikad tiha greška — uvek vidljivo stanje i akcija.

## 6. Rule-based parsiranje stavki iz žurnala (bez AI-ja)

PFR žurnal ima standardizovan tekstualni format. Parsiraj pravilima/regexom, NE AI-jem:
- Sekcija stavki je između markera zaglavlja i bloka „Ukupan iznos / Oblici plaćanja".
- Tipičan red stavke: naziv (+ poreska oznaka u zagradama, npr. `(Ђ)`), pa red sa
  `količina x jedinična_cena = ukupno`. Rukuj decimalama sa zarezom, hiljadama, i razmacima.
- Mapiraj poreske oznake (Ђ, Е, А, …) na stope iz zaglavlja/obračuna poreza.
- Parser izoluj u zaseban, testabilan servis sa fixture-ima; ako red ne može da se isparsira,
  označi stavku kao „neparsiran red" umesto da rušiš ceo račun.
- AI fallback za izopačene žurnale NIJE deo ovog dela (kandidat za kasnije, plaćeno).

## 7. Ekrani (za ovaj deo)
1. **Skener** — `mobile_scanner`, batch režim (više računa zaredom), prelazak na ručni unos.
2. **Rezultat skeniranja** — kratak prikaz preuzetog (prodavac, iznos, broj stavki ili stanje „u obradi"), dugme Sačuvaj/Otvori.
3. **Lista računa** — sortiranje/filtriranje po datumu/prodavcu/iznosu; bedž stanja stavki; pretraga po artiklu i prodavcu.
4. **Detalj računa** — zaglavlje, obračun poreza, stavke (ili stanje „u obradi" + Osveži), prilog fotografije, beleška, oznaka „poslovni" (čuva se, koristi se kasnije).
5. **Ručni unos (fallback)** — „Verify Invoice Manually": polja koja portal traži kad nema QR-a (npr. ukupan iznos, PFR broj, PFR vreme, brojač) → isti tok preuzimanja.

## 8. Rukovanje greškama
- Nema mreže → sačuvaj `pending`, stavi u red za re-fetch, obavesti korisnika nenametljivo.
- Nevažeći/otkazan račun → `invalid`, jasna poruka.
- Portal nedostupan / timeout → retry sa backoff-om, ne gubi zapis.
- Skeniran ne-fiskalni QR → poruka „Ovo nije fiskalni račun" (validacija host-a i `vl`).
- Duplikat (isti račun ponovo skeniran) → otvori postojeći zapis umesto novog.

## 9. Testovi (obavezno za ovaj deo)
- Unit: validacija URL-a; (ako se radi) dekodiranje `vl` tokena; parser zaglavlja; parser
  specifikacija (JSON); parser žurnal stavki; mapiranje poreskih oznaka; državni mehanizam
  prelaza `fetch_status`/`items_status`.
- Fixtures: realni uhvaćeni odgovori za sva 4–5 stanja (complete, headerOnly, pendingServer,
  invalid, journal-only).
- Widget: skeniranje → detalj (happy path) i skeniranje → „stavke u obradi" → osveži → complete.
- Provera da se duplikat ne upisuje dvaput; provera da se zapis nikad ne gubi pri grešci mreže.

## 10. Redosled gradnje
1. FAZA 0 skelet (projekat, Riverpod, drift + SQLCipher, lokalizacija) — ako već nije.
2. Validacija + parsiranje verifikacionog URL-a; ekran skenera.
3. `ReceiptSource` interfejs + `dio` klijent; **uhvati realne fixture-e**; parser zaglavlja.
4. Parser specifikacija; parser žurnal stavki; mapiranje poreza.
5. Drift tabele + upis/čitanje; lista + detalj + pretraga.
6. Državni mehanizam + `workmanager` re-fetch + UI stanja graničnog slučaja.
7. Ručni unos (fallback) + rukovanje greškama + duplikati.
8. Testovi za sve gore; `fvm flutter analyze` čist.

> Sve komande u svim fazama izvršavaj kroz FVM (`fvm flutter ...` / `fvm dart ...`); inicijalni `fvm use <verzija>` i commit `.fvmrc` su deo FAZE 0.

**Definicija „gotovo" za ovaj deo:** korisnik skenira fiskalni račun, podaci se preuzmu sa
`suf.purs.gov.rs` i sačuvaju lokalno (enkriptovano); ako stavke još nisu na serveru, račun se
ipak sačuva i automatski dopuni kasnije; korisnik može da pregleda, pretražuje i ručno osveži
račune — sve bez ijednog AI poziva.

## 11. Otvorena pitanja (razrešiti rano, nad realnim odgovorima)
1. Tačan endpoint i format izdvojenih stavki (HTML u stranici vs. zaseban POST/JSON) i nazivi polja.
2. Da li je `vl` token isplativo dekodirati klijentski za offline zaglavlje, ili se osloniti samo na stranicu.
3. Tačan skup PFR poreskih oznaka i njihovo mapiranje na stope (potvrditi sa realnih računa).
4. Ponašanje za tipove računa: Predračun/Kopija/Obuka/Refundacija (`proforma`/`copy`/`training`/`refund`) — koje obrađujemo, a koje samo prikazujemo.
5. Koliko pokušaja re-fetch-a i koji intervali su optimalni (da ne troše bateriju, a da stignu dopunu).
