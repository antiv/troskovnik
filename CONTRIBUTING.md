# Contributing to Troškovnik

## Setup

This project uses [FVM](https://fvm.app) to pin the Flutter version. All Flutter/Dart commands must go through FVM.

```bash
# 1. Install FVM (once, globally)
dart pub global activate fvm
# or: brew tap leoafarias/fvm && brew install fvm

# 2. Install the pinned Flutter version
fvm install

# 3. Get dependencies
fvm flutter pub get

# 4. Generate localization files
fvm flutter gen-l10n

# 5. Generate Drift database code
fvm dart run build_runner build --delete-conflicting-outputs
```

Configure your IDE to use the FVM SDK path: `.fvm/flutter_sdk`.

## Running the app

```bash
fvm flutter run
```

## Before submitting a PR

```bash
fvm flutter gen-l10n                                              # localizations first
fvm dart run build_runner build --delete-conflicting-outputs      # drift codegen
fvm flutter analyze                                               # must be clean
fvm flutter test                                                  # must pass
```

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
  unit/        # unit tests
  widget/      # widget tests
```

## Adding a localized string

Add the string to all three ARB files before running `gen-l10n`:

- `lib/core/l10n/arb/app_sr.arb` (Serbian Latin)
- `lib/core/l10n/arb/app_sr_Cyrl.arb` (Serbian Cyrillic)
- `lib/core/l10n/arb/app_en.arb` (English)

## Commit style

```
type: short description

feat:     new feature
fix:      bug fix
refactor: code change with no behaviour change
chore:    build, deps, config
docs:     documentation only
test:     tests only
```

## Notes

- Generated files (`*.g.dart`, `*.drift.dart`, `lib/core/l10n/gen/`) are not committed — generate locally.
- `instrukcije.md` contains original scope notes (in Serbian) used during initial development.
- `deploy.sh` / `deploy_ios.sh` are personal deployment scripts that read credentials from environment variables — not needed for development.
