# Test fixtures — realni odgovori TaxCore portala

Sekcija 3 (bold) i sekcija 11 instrukcije.md: **parser se gradi i testira nad
realnim odgovorima portala**, jer se tačan oblik (HTML stranica vs. JSON/POST za
specifikacije, nazivi polja, markeri za „otkazan/nepostojeći") mora potvrditi
empirijski — ne sme se pretpostaviti.

## Kako uhvatiti fixture

Iz realnog fiskalnog računa uzmi verifikacioni URL (skeniraj QR ili prepiši
`https://suf.purs.gov.rs/v/?vl=...`) i pokreni:

```bash
fvm dart run tool/capture_fixtures.dart <label> "<verification_url>"
```

Alat snima:
- `<label>.page.html` — verifikaciona stranica (zaglavlje + žurnal)
- `<label>.specifications.txt` — odgovor specifications endpointa (ako vrati nešto)
- `<label>.meta.json` — status kodovi, content-type, vreme

## Stanja koja treba uhvatiti (sekcija 9)

| label            | situacija                                                        |
|------------------|------------------------------------------------------------------|
| `complete`       | kompletan račun: zaglavlje + izdvojene stavke dostupne           |
| `header_only`    | zaglavlje/žurnal ima, ali izdvojene stavke još nisu na serveru   |
| `journal_only`   | stavke se vide samo u žurnal tekstu (ne kroz specifications)     |
| `pending_server` | račun skeniran odmah; stavke još nisu prosleđene Poreskoj        |
| `invalid`        | nepostojeći / otkazan račun (npr. izmenjen token)                |

> Najteže je uhvatiti `pending_server` — traži skeniranje neposredno po izdavanju,
> pre nego što prodavac proknjiži račun. Ako se ne uhvati lako, dovoljan je
> `header_only` + ručno konstruisan slučaj u testu.

## Privatnost

Ovi fajlovi sadrže realne podatke računa. Ako su lični/osetljivi, **anonimizuj**
pre commit-a (zameni PIB/iznose/nazive) ili ih drži van VCS-a. Parser testovi
treba da rade i nad anonimizovanim sadržajem (struktura je bitna, ne vrednosti).
