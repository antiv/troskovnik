# Troškovnik

A Flutter app for scanning Serbian (and Republika Srpska) fiscal receipts, fetching itemized data from the Tax Authority portal, and storing everything locally in an encrypted database — no account, no cloud.

[<img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="50">](https://play.google.com/store/apps/details?id=rs.antonijevic.troskovnik)
[<img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" height="50">](https://apps.apple.com/app/troskovnik/id6746502939)

## Features

- **Scan QR codes** from Serbian fiscal receipts (TaxCore / `suf.purs.gov.rs`)
- **Fetch itemized data** — line items, tax breakdown, merchant info
- **Encrypted local storage** — Drift + SQLCipher, no data leaves your device
- **Categories** — assign categories to line items, with custom category support
- **Warranties** — track warranty expiry with notifications
- **Analytics** — monthly spending charts by category and merchant
- **Localization** — Serbian (Latin & Cyrillic) and English

## Tech stack

- **Flutter** (version pinned via FVM — see `.fvmrc`)
- **Riverpod** — state management
- **Drift + SQLCipher** — encrypted local database
- **mobile_scanner** — QR code scanning
- **Dio + html** — fetching and parsing the Tax Authority portal
- **workmanager** — background re-fetch for receipts not yet on the server

## Getting started

This project uses [FVM](https://fvm.app) to pin the Flutter version.

```bash
# Install FVM (once, globally)
dart pub global activate fvm

# Install the pinned Flutter version and get dependencies
fvm install
fvm flutter pub get

# Generate localizations and database code
fvm flutter gen-l10n
fvm dart run build_runner build --delete-conflicting-outputs

# Run
fvm flutter run
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development workflow.

## Project structure

```
lib/
  core/        # db schema, localization, theme, utils
  features/
    scan/      # QR scanning, URL validation, scan state machine
    source/    # TaxCore client + parsers (journal, specifications)
    receipts/  # list, detail, repository
    analytics/ # spending charts and aggregations
    warranties/# warranty tracking
    home/      # main shell / bottom navigation
test/
  fixtures/    # real captured portal responses (used by parsers)
  unit/
  widget/
```

## How it works

Serbian fiscal QR codes contain a verification URL (`https://suf.purs.gov.rs/v/?vl=<token>`). The app:

1. Validates the URL and fetches the portal page
2. Parses the server-rendered journal (`<pre>` block) for the receipt header
3. Requests itemized data from the `/specifications` endpoint (AJAX, best-effort)
4. Falls back to journal text parsing if specifications aren't available yet
5. Saves everything to an encrypted local SQLite database

If the device is offline, the receipt header is saved immediately and items are fetched automatically in the background when connectivity is restored.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
