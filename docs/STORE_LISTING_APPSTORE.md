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

Stoji iznad opisa i **menja se bez novog build-a** — jedino polje koje se može
promeniti dok je verzija „Ready for Sale". Ne indeksira se za pretragu, pa nema
smisla trpati ključne reči; služi za najavu ili za jednu rečenicu koja zadržava
posetioca dok ne klikne „more".

Tri ugla, u paru EN/SR — bira se jedan, prema tome šta je aktuelno.

**A — privatnost** (podrazumevani, ne zastareva)

```
Scan the QR code on a fiscal receipt: merchant, items, taxes and total land in an encrypted log on your phone. No account, no cloud, no tracking.
```

145/170.

```
Skeniraj QR kod sa fiskalnog računa: prodavac, artikli, porezi i iznos idu u enkriptovan dnevnik na tvom telefonu. Bez naloga, bez clouda, bez praćenja.
```

152/170. Ćirilična varijanta istog teksta (151/170):

```
Скенирај QR код са фискалног рачуна: продавац, артикли, порези и износ иду у енкриптован дневник на твом телефону. Без налога, без клауда, без праћења.
```

**B — regioni** (za period dok je proširenje na RS i CG novost)

```
Now works with receipts from Serbia, Republika Srpska and Montenegro. Scan the QR code — everything stays on your phone, encrypted. No account needed.
```

150/170.

```
Sada radi i sa računima iz Republike Srpske i Crne Gore. Skeniraj QR kod — svi podaci ostaju na tvom telefonu, enkriptovani. Bez naloga i bez clouda.
```

149/170.

**C — garancije** (jedina funkcija koju konkurencija uglavnom nema)

```
Paper fades. Troškovnik keeps the receipt, its items and the warranty date, and reminds you 30 and 7 days before the warranty runs out.
```

135/170.

```
Papir izbledi. Troškovnik čuva račun, njegove stavke i rok garancije, i podseti te 30 i 7 dana pre nego što garancija istekne.
```

126/170.

> **Gde koji ide.** Tekstovi se u App Store-u vezuju za **jezik, ne za
> storefront**, a srpski Apple (bar do sad) nije nudio kao lokalizaciju — proveri
> listu u App Store Connect → App Information. Ako srpskog nema, srpska verzija
> ide u primarni jezik aplikacije, a engleska u dodatnu englesku lokalizaciju
> (npr. English (U.K.) uz English (U.S.) kao primarni). Na Google Play-u ovo polje
> **ne postoji** — tamo isti posao radi prvi red kratkog opisa
> (`STORE_LISTING_sr.md`).

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
