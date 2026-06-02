# Troškovnik

Flutter aplikacija za skeniranje srpskih fiskalnih računa, preuzimanje podataka sa
portala Poreske uprave (`suf.purs.gov.rs`, TaxCore) i lokalno enkriptovano čuvanje.

Ovaj repozitorijum pokriva **FREE/MVP deo** (bez AI-ja): skeniranje QR koda, preuzimanje
i rule-based parsiranje računa, čuvanje u enkriptovanu SQLite bazu, pregled i pretragu.
Vidi `instrukcije.md` za pun obim.

## Tehnologije

- **Flutter** (zakucana verzija kroz FVM — vidi `.fvmrc`)
- **Riverpod** — state management
- **drift + SQLCipher** — enkriptovana lokalna baza
- **mobile_scanner** — skeniranje QR koda
- **dio + html** — preuzimanje i parsiranje stranica portala
- **workmanager** — background re-fetch za stavke koje još nisu na serveru
- Lokalizacija SR (default) / EN; RSD format

## Preduslovi: FVM

Verzijom Fluttera upravlja [FVM](https://fvm.app). Sve Flutter/Dart komande idu kroz FVM.

```bash
# 1. Instaliraj FVM (jednom, globalno)
dart pub global activate fvm        # ili: brew tap leoafarias/fvm && brew install fvm

# 2. Instaliraj zakucanu verziju Fluttera za ovaj projekat (čita .fvmrc)
fvm install

# 3. Preuzmi zavisnosti
fvm flutter pub get

# 4. Generiši lokalizaciju (ARB -> Dart)
fvm flutter gen-l10n
```

## Pokretanje

```bash
fvm flutter run
```

## Razvoj

```bash
fvm flutter analyze          # statička analiza (mora biti čisto)
fvm flutter test             # testovi
fvm dart run build_runner build --delete-conflicting-outputs   # drift codegen
```

> **Generisani kod** (`*.g.dart`, `*.drift.dart`) se ne commit-uje — generiše se lokalno
> kroz `build_runner`. Lokalizacioni izlaz u `lib/core/l10n/gen/` se generiše preko
> `gen-l10n`.

### IDE / CI

Podesi IDE da koristi FVM SDK putanju: `.fvm/flutter_sdk`. CI korake (`analyze`, `test`)
pokretati kroz `fvm flutter ...`.

## Struktura

```
lib/
  core/        # baza, lokalizacija, tema, util
  features/
    scan/      # skeniranje QR-a i validacija URL-a
    source/    # ReceiptSource: preuzimanje + parsiranje sa portala
    receipts/  # lista, detalj, čuvanje računa
test/
  fixtures/    # realni uhvaćeni odgovori portala (za parsere)
  unit/        # unit testovi
  widget/      # widget testovi
```

## Napomene

- `sqlcipher_flutter_libs` / `sqlite3_flutter_libs` su trenutno objavljeni sa `+eol`
  oznakom (maintainer ih postepeno gasi). Rade i standardni su izbor za drift+SQLCipher,
  ali su kandidat za reviziju u kasnijoj fazi.
