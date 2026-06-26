# Troškovnik — Roadmap

## Planirani taskovi

| # | Issue | Oblast | Status |
|---|-------|--------|--------|
| [#1](https://github.com/antiv/troskovnik/issues/1) | Open source priprema (LICENSE, CI, CONTRIBUTING) | Infrastruktura |  ✅ |
| [#7](https://github.com/antiv/troskovnik/issues/7) | Backup/restore — ZIP export/import | Korisničke funkcije | 🔜 |
| [#2](https://github.com/antiv/troskovnik/issues/2) | Ručni unos troška (struja, infostan, loš QR) | Korisničke funkcije | 🔜 |
| [#3](https://github.com/antiv/troskovnik/issues/3) | Republika Srpska — multi-country Faza A | Proširenje tržišta | 🔜 |
| [#4](https://github.com/antiv/troskovnik/issues/4) | SuF lookup po broju računa (WebView) | Korisničke funkcije | 🔜 |
| [#5](https://github.com/antiv/troskovnik/issues/5) | Crna Gora — multi-country Faza B | Proširenje tržišta | ⏳ čeka #3 |
| [#6](https://github.com/antiv/troskovnik/issues/6) | Hrvatska — multi-country Faza B | Proširenje tržišta | ⏳ čeka #3 |

## Napomene

- **#5 i #6 su blokirani od #3** — Republika Srpska uvodi `Country`/`Currency` infrastrukturu koju Crna Gora i Hrvatska koriste.
- **#5 i #6 mogu ići paralelno** kada #3 bude gotov, ali svaki zahteva istraživanje stvarnih računa pre implementacije.
- **#4 (WebView lookup)** — portal `suf.purs.gov.rs/verify` ima bez-QR formu ali je zaštićena reCAPTCHA Enterprise; jedini pristup je in-app WebView.
