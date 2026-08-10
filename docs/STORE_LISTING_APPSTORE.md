# App Store listing — Troškovnik

> **Apple i Google indeksiraju različita polja.** Ovo je čest izvor grešaka, pa
> stoji na vrhu:
>
> | Polje | Google Play | App Store |
> |---|---|---|
> | Naslov / Name (30) | indeksira se | indeksira se |
> | Subtitle (30) | **ne postoji** | **indeksira se** |
> | Keywords (100) | **ne postoji** | **indeksira se** |
> | Kratak opis (80) | indeksira se | ne postoji |
> | Pun opis | **indeksira se** | **NE indeksira se** |
>
> Posledica: na Apple-u sav teret rangiranja nose **Name + Subtitle + Keywords**.
> Opis služi isključivo konverziji — trud uložen u ključne reči u opisu je
> bačen. Na Play-u je obrnuto (vidi `STORE_LISTING_sr.md`).

---

## Name (maks. 30)

```
Troškovnik: troškovi i budžet
```

29/30. Namerno **ne ponavlja** „fiskalni računi" — to je već u Subtitle-u, a
Apple indeksira Name i Subtitle zajedno, pa bi ponavljanje bio bačen prostor.

## Subtitle (maks. 30)

```
Fiskalni računi i garancije
```

27/30.

## Keywords (maks. 100)

```
skener,QR,PDV,PURS,EFI,potrošnja,kupovina,evidencija,arhiva,Srbija,Srpska,Crna,Gora,offline
```

91/100. Pravila:

- **bez razmaka posle zareza** — razmaci troše karaktere
- **bez ponavljanja** reči iz Name/Subtitle — indeksiraju se zajedno
- jednina umesto množine; Apple sam kombinuje tokene u fraze (zato `Crna,Gora`)
- `EFI` je crnogorski termin (elektronska fiskalizacija)

## Opis (maks. 4000)

```
Troškovnik pretvara papirne račune u privatan, pretraživ dnevnik troškova.

Skeniraj QR kod sa fiskalnog računa i aplikacija preuzme prodavca, datum,
artikle, poreze i ukupan iznos direktno sa portala Poreske uprave. Sve ostaje
na tvom telefonu, u enkriptovanoj bazi.

Bez naloga. Bez clouda. Bez praćenja.

• Skeniranje QR koda sa fiskalnog računa uz automatsko preuzimanje stavki
• Enkriptovano lokalno čuvanje (AES-256) — podaci ne napuštaju uređaj
• Pretraga po prodavcu ili artiklu, kategorije, poslovno/privatno
• Garancije — podsetnik 30 i 7 dana pre isteka
• Račun kao dokaz o kupovini: žurnal, zvanični link i fotografija
• Analitika — po mesecu, kategoriji i prodavcu, uz procenjen PDV
• Backup u ZIP i izvoz u CSV
• Radi sa računima iz Srbije, Republike Srpske i Crne Gore
• Srpski (ćirilica i latinica) i engleski

Troškovnik nema reklame ni analitiku. Jedina veza koju pravi je ka zvaničnom
portalu Poreske uprave, radi očitavanja računa koji si skenirao.

Nezavisna aplikacija; nije povezana sa Poreskom upravom niti je ona podržava.
```

## Promotional text (maks. 170)

Stoji iznad opisa i **menja se bez novog build-a** — koristi za najave:

```
Sada radi i sa računima iz Republike Srpske i Crne Gore. Skeniraj QR kod, a
svi podaci ostaju na tvom telefonu — bez naloga i bez clouda.
```

---

## Screenshot-ovi

Sirovi snimci ekrana bez natpisa slabo konvertuju, a prvi kadar odlučuje.
Predlog natpisa iznad kadrova:

1. „Skeniraj QR kod"
2. „Sve stavke automatski"
3. „Prati garancije"
4. „Sve ostaje na telefonu"

Izbegavati kadar sa računom fotografisanim u polumraku kao prvi.

## Distribucija — proveriti

App Store Connect → Pricing and Availability mora da uključuje **Srbiju, BiH i
Crnu Goru** — aplikacija podržava sve tri (`lib/core/domain/country.dart`).

## Ostalo

- **Kategorija:** Finance
- **Age rating:** 4+
- **Privacy Policy URL:** `<PRIVACY_POLICY_URL>`
- **Podržani jezici:** srpski (ćirilica i latinica), engleski
