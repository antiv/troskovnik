# Store screenshot-ovi sa natpisima

Sirov snimak ekrana bez ijedne reči preko njega troši najskuplji prostor u
listingu. Uz to, Apple od juna 2025. OCR-uje tekst sa **prva tri**
screenshot-a i koristi ga kao ranking signal — natpis je, dakle, ranking
polje, a ne ukras.

`make_screenshots.py` uzima tvoje snimke ekrana i pravi gotove store slike sa
natpisima, za sr / sr_Cyrl / en i za oba store-a.

## Upotreba

**1.** Napravi snimke ekrana na telefonu ili simulatoru i ubaci ih ovde:

```
marketing/screenshots/raw/scan.png
marketing/screenshots/raw/analytics.png
marketing/screenshots/raw/receipt.png
marketing/screenshots/raw/warranties.png
```

Imena moraju biti tačno ovakva — po njima se biraju natpisi. Slajd `privacy`
nema snimak, generiše se iz `assets/icon/appstore.png`.

**2.** Pokreni:

```sh
python3 marketing/screenshots/make_screenshots.py
```

```sh
python3 marketing/screenshots/make_screenshots.py --locale sr --platform ios
```

**3.** Rezultat je u `out/<platform>/<locale>/`, numerisan redosledom za upload:

```
out/ios/en/1-scan.png         1320 × 2868   (iPhone 6.9")
out/play/sr/2-analytics.png   1080 × 1920   (9:16)
```

## Šta je namerno

- **Redosled je priča: skeniraj → vidi troškove → vidi stavke.** U
  rezultatima pretrage vide se samo prva tri slajda. Skeniranje je ono što se
  traži, analitika je razlog da se tapne, a stavke sa računa su ono što
  aplikacije sa ručnim unosom nemaju.
- **Garancije su četvrte, ne prve.** Jaka su funkcija, ali niko ih ne traži
  pod „troškovi" — one prodaju nakon što je korisnik već zainteresovan.
- **Peti slajd je čist tekst o privatnosti.** Nema odgovarajući ekran u
  aplikaciji, a tvrdnja (bez naloga, bez cloud-a, SQLCipher baza) previše je
  vredna da bi ostala samo u opisu koji na iOS-u ionako nije indeksiran.
- **Ikonica ide na belu pločicu.** I ikonica i podloga su zelene, pa se bez
  pločice gubi.
- **Jedna tema za sve slajdove.** Snimi svih pet u istoj temi (svetloj ili
  tamnoj) — mešavina se čita kao previd.
- **Arial, ne SF.** SF je varijabilan font i Pillow ga ne renderuje pouzdano;
  Arial pokriva i našu latinicu (č ć š ž đ) i ćirilicu.

## Jezici i store-ovi

Play prihvata srpski listing, pa tamo idu `sr` (ili `sr_Cyrl`, u zavisnosti od
toga koje pismo je u listingu) i `en`. App Store Connect nema srpski među
lokalizacijama listinga — proveri u ASC šta je otvoreno za tvoju aplikaciju;
ako srpskog nema, na iOS ide `en` set.

## Izmene

Natpisi su u `CAPTIONS` na vrhu skripte, boje u `DINAR_GREEN` / `DEEP_GREEN`
(preuzete iz `lib/core/theme/app_theme.dart`), dimenzije u `PLATFORMS`. `\n` u
natpisu forsira prelom reda. Novi jezik je samo novi ključ u `CAPTIONS` —
skripta ga pokupi sama.

## Zavisnosti

Pillow (provereno na 10.4.0). Ako nedostaje: `python3 -m pip install Pillow`.

`out/` je generisan sadržaj i ne commit-uje se. `raw/` zadrži u gitu — to su
izvorni snimci koje ćeš hteti ponovo kad menjaš natpise.
