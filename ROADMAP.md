# Troškovnik — Roadmap

## Planirani taskovi

| # | Issue | Oblast | Status |
|---|-------|--------|--------|
| [#1](https://github.com/antiv/troskovnik/issues/1) | Open source priprema (LICENSE, CI, CONTRIBUTING) | Infrastruktura |  ✅ |
| [#7](https://github.com/antiv/troskovnik/issues/7) | Backup/restore — ZIP export/import | Korisničke funkcije | ✅ |
| [#2](https://github.com/antiv/troskovnik/issues/2) | Ručni unos troška (struja, infostan, loš QR) | Korisničke funkcije | ✅ |
| [#3](https://github.com/antiv/troskovnik/issues/3) | Republika Srpska — multi-country Faza A | Proširenje tržišta | ✅ |
| [#5](https://github.com/antiv/troskovnik/issues/5) | Crna Gora — multi-country Faza B | Proširenje tržišta | ✅ |
| [#4](https://github.com/antiv/troskovnik/issues/4) | SuF lookup po broju računa (WebView) | Korisničke funkcije | 🔜 |
| [#6](https://github.com/antiv/troskovnik/issues/6) | Hrvatska — multi-country Faza B | Proširenje tržišta | 🔜 |

## Napomene

- **#3 i #5 su isporučeni.** `Country` (`lib/core/domain/country.dart`) pokriva Srbiju, Republiku Srpsku i Crnu Goru; `MultiSourceRegistry` rutira po hostu na `TaxCoreClient` (RS/SRB) ili `MneClient` (CG).
- **#6 (Hrvatska)** više nije blokiran — `Country`/`Currency` infrastruktura postoji. Zahteva istraživanje stvarnih računa pre implementacije.
- **#4 (WebView lookup)** — portal `suf.purs.gov.rs/verify` ima bez-QR formu ali je zaštićena reCAPTCHA Enterprise; jedini pristup je in-app WebView.
- **Store listinzi kasne za kodom** — proveriti da su BiH i Crna Gora uključene u distribuciju na oba store-a i da listinzi pominju sve tri zemlje (vidi `docs/STORE_LISTING_sr.md`, `docs/STORE_LISTING_APPSTORE.md`).
