#!/usr/bin/env bash
#
# deploy.sh — podiže verziju, bilduje release artefakt i opcionalno šalje na Google Play.
#
# Podrazumevano: AAB (za Play Store), uz bump verzije (patch + build broj).
#   pubspec  version: X.Y.Z+N  ->  X.Y.(Z+1)+(N+1)
# Izlaz: troskovnik-<versionName>.aab (ili .apk) u root-u projekta.
#
# Upotreba:
#   ./deploy.sh                 # AAB, sa bump-om verzije
#   ./deploy.sh --upload        # AAB + bump + upload na Google Play (internal track)
#   ./deploy.sh apk             # APK umesto AAB (samo lokalni build)
#   ./deploy.sh --no-bump       # bez podizanja verzije
#   ./deploy.sh --upload --no-bump # upload bez podizanja verzije
#
# --upload čita android/deploy.env (vidi android/deploy.env.example) i prosleđuje
# bundle skripti tool/play_upload.py.
#
set -euo pipefail

# --- Lokacija projekta (skript radi i ako se pozove iz drugog dir-a) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PUBSPEC="pubspec.yaml"
ENV_FILE="android/deploy.env"
PLAY_UPLOAD="$SCRIPT_DIR/tool/play_upload.py"

# --- Parsiranje argumenata (flegovi, bilo kojim redosledom) ---
FORMAT="aab"
BUMP=true
UPLOAD=false
for arg in "$@"; do
  case "$arg" in
    apk)        FORMAT="apk" ;;
    aab)        FORMAT="aab" ;;
    --bump)     BUMP=true ;;
    --no-bump)  BUMP=false ;;
    --upload)   UPLOAD=true ;;
    -h|--help)
      sed -n '10,18p' "$0" | sed 's/^#[[:space:]]\{0,1\}//'
      exit 0 ;;
    *)
      echo "Nepoznat argument: $arg" >&2
      echo "Dozvoljeno: apk | aab | --upload | --no-bump | --help" >&2
      exit 64 ;;
  esac
done

if $UPLOAD && [[ "$FORMAT" == "apk" ]]; then
  echo "Greška: Google Play prima samo AAB za nove release-ove. Ukloni 'apk' ako želiš --upload." >&2
  exit 1
fi

# Sve provere za upload se vrše unapred, pre bump-a i build-a.
PACKAGE=""
if $UPLOAD; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Nedostaje $ENV_FILE — kopiraj android/deploy.env.example i popuni." >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  if [[ -z "${PLAY_SERVICE_ACCOUNT_JSON:-}" ]]; then
    echo "PLAY_SERVICE_ACCOUNT_JSON nije postavljen u $ENV_FILE" >&2
    exit 1
  fi
  if [[ ! -f "$PLAY_SERVICE_ACCOUNT_JSON" ]]; then
    echo "Fajl servisnog naloga nije pronađen: PLAY_SERVICE_ACCOUNT_JSON=$PLAY_SERVICE_ACCOUNT_JSON" >&2
    exit 1
  fi
  if ! python3 -c 'import googleapiclient, google.oauth2' 2>/dev/null; then
    echo "python3 nema instalirane Play API klijentske pakete: pip3 install google-api-python-client google-auth" >&2
    exit 1
  fi
  if [[ ! -f "$PLAY_UPLOAD" ]]; then
    echo "Pomoćna skripta za upload nije pronađena: $PLAY_UPLOAD" >&2
    exit 1
  fi
  PACKAGE="$(grep -E 'applicationId[[:space:]]*=' android/app/build.gradle.kts | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
  if [[ -z "$PACKAGE" ]]; then
    echo "Ne mogu da pročitam applicationId iz android/app/build.gradle.kts" >&2
    exit 1
  fi
fi

# --- FVM Flutter (sve komande kroz FVM, po konvenciji projekta) ---
FLUTTER="fvm flutter"

# --- Pročitaj trenutnu verziju iz pubspec: "version: X.Y.Z+N" ---
version_line="$(grep -E '^version:[[:space:]]*[0-9]' "$PUBSPEC" | head -1)"
if [[ -z "$version_line" ]]; then
  echo "Ne mogu da nađem 'version:' u $PUBSPEC" >&2
  exit 1
fi
current="$(echo "$version_line" | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]')"
name="${current%%+*}"            # X.Y.Z
build="${current#*+}"            # N
# Ako nema "+N", tretiraj build kao 0
if [[ "$build" == "$current" ]]; then build=0; fi

IFS='.' read -r major minor patch <<< "$name"

if $BUMP; then
  patch=$((patch + 1))
  build=$((build + 1))
  new_name="${major}.${minor}.${patch}"
  new_version="${new_name}+${build}"
  # Zameni version liniju u pubspec-u (in-place, BSD/sed kompatibilno).
  sed -i.bak -E "s/^version:[[:space:]]*.*/version: ${new_version}/" "$PUBSPEC"
  rm -f "${PUBSPEC}.bak"
  echo "Verzija: ${current}  ->  ${new_version}"
else
  new_name="$name"
  new_version="$current"
  echo "Verzija (bez promene): ${new_version}"
fi

# --- Build ---
# Dart obfuskacija + native debug simboli (čitljivi crash izveštaji na Play
# Console; rešava upozorenje "no deobfuscation file"). R8 DEX obfuskacija je u build.gradle.kts.
SYMBOLS_DIR="build/debug-symbols/${new_name}"
mkdir -p "$SYMBOLS_DIR"
OBFUSCATE_ARGS=(--obfuscate --split-debug-info="$SYMBOLS_DIR")

echo "Bildujem ${FORMAT} (release, sa debug simbolima)..."
if [[ "$FORMAT" == "apk" ]]; then
  $FLUTTER build apk --release "${OBFUSCATE_ARGS[@]}"
  src="build/app/outputs/flutter-apk/app-release.apk"
  ext="apk"
else
  $FLUTTER build appbundle --release "${OBFUSCATE_ARGS[@]}"
  src="build/app/outputs/bundle/release/app-release.aab"
  ext="aab"
fi

if [[ ! -f "$src" ]]; then
  echo "Build nije proizveo očekivani fajl: $src" >&2
  exit 1
fi

# --- Kopiraj u root kao troskovnik-<verzija>.<ext> ---
dest="troskovnik-${new_name}.${ext}"
cp "$src" "$dest"

size="$(du -h "$dest" | cut -f1)"
echo ""
echo "✓ Gotovo: ${dest} (${size})"
echo "  Izvor:  ${src}"
echo "  Debug simboli: ${SYMBOLS_DIR}/"

if $UPLOAD; then
  TRACK="${PLAY_TRACK:-internal}"
  echo ""
  echo "==> Otpremam ${dest} na Google Play (${PACKAGE}, staza: '${TRACK}')..."
  python3 "$PLAY_UPLOAD" "$dest" "$PACKAGE" --track "$TRACK" --key "$PLAY_SERVICE_ACCOUNT_JSON"
  echo "Google Play obrađuje bundle nekoliko minuta; zatim se prikazuje pod Testing → ${TRACK} track."
elif [[ "$FORMAT" == "aab" ]]; then
  echo ""
  echo "  (Za automatsko slanje na Google Play, pokreni: ./deploy.sh --upload)"
  echo "  Play Console: ako i dalje vidiš upozorenje, otpremi native debug simbole"
  echo "  (App bundle explorer → Downloads → Upload). Sadržaj: ${SYMBOLS_DIR}"
fi
