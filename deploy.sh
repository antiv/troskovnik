#!/usr/bin/env bash
#
# deploy.sh — podiže verziju, bilduje release artefakt i kopira ga u root projekta.
#
# Podrazumevano: AAB (za Play Store), uz bump verzije (patch + build broj).
#   pubspec  version: X.Y.Z+N  ->  X.Y.(Z+1)+(N+1)
# Izlaz: troskovnik-<versionName>.aab (ili .apk) u root-u projekta.
#
# Upotreba:
#   ./deploy.sh                 # AAB, sa bump-om verzije
#   ./deploy.sh apk             # APK umesto AAB
#   ./deploy.sh --no-bump       # bez podizanja verzije
#   ./deploy.sh apk --no-bump   # APK, bez bump-a (flegovi bilo kojim redosledom)
#
set -euo pipefail

# --- Lokacija projekta (skript radi i ako se pozove iz drugog dir-a) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PUBSPEC="pubspec.yaml"

# --- Parsiranje argumenata (flegovi, bilo kojim redosledom) ---
FORMAT="aab"
BUMP=true
for arg in "$@"; do
  case "$arg" in
    apk)        FORMAT="apk" ;;
    aab)        FORMAT="aab" ;;
    --no-bump)  BUMP=false ;;
    -h|--help)
      sed -n '10,16p' "$0" | sed 's/^#[[:space:]]\{0,1\}//'
      exit 0 ;;
    *)
      echo "Nepoznat argument: $arg" >&2
      echo "Dozvoljeno: apk | aab | --no-bump | --help" >&2
      exit 64 ;;
  esac
done

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
# Console; rešava upozorenje "no deobfuscation file"). NE dira R8 (ostaje isključen).
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
if [[ "$FORMAT" == "aab" ]]; then
  echo ""
  echo "  Play Console: ako i dalje vidiš upozorenje, otpremi native debug simbole"
  echo "  (App bundle explorer → Downloads → Upload). Sadržaj: ${SYMBOLS_DIR}"
fi
