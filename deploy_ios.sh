#!/usr/bin/env bash
#
# deploy_ios.sh — potpuno automatizovan iOS build + upload na App Store Connect.
#
# Potpisivanje NE zavisi od Apple ID-a ulogovanog u Xcode/Mac. Build potpisuje
# nalog kome pripadaju App Store Connect API ključ (ASC_KEY_*) i Team ID
# (APP_STORE_TEAM_ID). Uz `-allowProvisioningUpdates`, xcodebuild sam kreira i
# preuzme distribution sertifikat + provisioning profil tog naloga — bez GUI
# logina. Tako potpisuješ NOVIM nalogom dok ti je na Mac-u ulogovan lični.
#
# Jednokratna priprema:
#   1) developer.apple.com → Membership → prepiši Team ID
#   2) App Store Connect → Users and Access → Integrations → App Store Connect API
#      → generiši ključ (Admin/App Manager), skini AuthKey_XXXX.p8 (samo jednom!)
#   3) cp ios/deploy.env.example ios/deploy.env  &&  popuni vrednosti
#   4) app sa bundle ID-em rs.antonijevic.troskovnik mora postojati u App Store
#      Connect-u pod tim nalogom
#
# Upotreba:
#   ./deploy_ios.sh                # bump verzije + build + upload
#   ./deploy_ios.sh --no-bump      # bez podizanja verzije (npr. posle deploy.sh)
#   ./deploy_ios.sh --no-upload    # samo napravi .ipa, bez slanja
#
set -euo pipefail

# --- Lokacija projekta (radi i ako se pozove iz drugog dir-a) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PUBSPEC="pubspec.yaml"
ENV_FILE="ios/deploy.env"
FLUTTER="fvm flutter"

# --- Parsiranje argumenata ---
BUMP=true
UPLOAD=true
for arg in "$@"; do
  case "$arg" in
    --no-bump)    BUMP=false ;;
    --no-upload)  UPLOAD=false ;;
    -h|--help)
      sed -n '19,22p' "$0" | sed 's/^#[[:space:]]\{0,1\}//'
      exit 0 ;;
    *)
      echo "Nepoznat argument: $arg" >&2
      echo "Dozvoljeno: --no-bump | --no-upload | --help" >&2
      exit 64 ;;
  esac
done

# --- Učitaj konfiguraciju (tajne) ---
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Nedostaje $ENV_FILE — kopiraj ios/deploy.env.example i popuni." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

for v in APP_STORE_TEAM_ID ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
  if [[ -z "${!v:-}" ]]; then
    echo "U $ENV_FILE nije postavljeno: $v" >&2
    exit 1
  fi
done
if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "API ključ ne postoji na putanji ASC_KEY_PATH=$ASC_KEY_PATH" >&2
  exit 1
fi

# --- Pročitaj/bumpuj verziju iz pubspec: "version: X.Y.Z+N" ---
version_line="$(grep -E '^version:[[:space:]]*[0-9]' "$PUBSPEC" | head -1)"
[[ -n "$version_line" ]] || { echo "Ne mogu da nađem 'version:' u $PUBSPEC" >&2; exit 1; }
current="$(echo "$version_line" | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]')"
name="${current%%+*}"
build="${current#*+}"
[[ "$build" == "$current" ]] && build=0
IFS='.' read -r major minor patch <<< "$name"

if $BUMP; then
  patch=$((patch + 1)); build=$((build + 1))
  new_name="${major}.${minor}.${patch}"
  new_version="${new_name}+${build}"
  sed -i.bak -E "s/^version:[[:space:]]*.*/version: ${new_version}/" "$PUBSPEC"
  rm -f "${PUBSPEC}.bak"
  echo "Verzija: ${current}  ->  ${new_version}"
else
  new_name="$name"; new_version="$current"
  echo "Verzija (bez promene): ${new_version}"
fi

# --- Putanje artefakata ---
ARCHIVE="build/ios/archive/Runner.xcarchive"
IPA_DIR="build/ios/ipa"
EXPORT_PLIST="build/ios/ExportOptions.plist"
rm -rf "$ARCHIVE" "$IPA_DIR"
mkdir -p "$(dirname "$ARCHIVE")" "$IPA_DIR"

# --- 1) Flutter build (assets + App.framework), bez potpisivanja ---
echo "==> flutter build ios (release, --no-codesign)"
$FLUTTER build ios --release --no-codesign

# --- 2) Generiši ExportOptions.plist (Team ID iz env-a, ne commit-uje se) ---
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>${APP_STORE_TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

AUTH=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

# --- 3) Arhiviraj (potpisuje se Team ID-em novog naloga) ---
echo "==> xcodebuild archive"
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$APP_STORE_TEAM_ID" \
  "${AUTH[@]}" \
  archive

# --- 4) Export potpisanog .ipa ---
echo "==> xcodebuild -exportArchive"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$IPA_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  "${AUTH[@]}"

IPA="$(ls "$IPA_DIR"/*.ipa 2>/dev/null | head -1)"
[[ -f "$IPA" ]] || { echo "Export nije proizveo .ipa u $IPA_DIR" >&2; exit 1; }
echo "✓ IPA: $IPA ($(du -h "$IPA" | cut -f1))"

# --- 5) Upload na App Store Connect (altool, isti API ključ) ---
if $UPLOAD; then
  # altool traži ključ u ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8
  KEY_DIR="$HOME/.appstoreconnect/private_keys"
  mkdir -p "$KEY_DIR"
  cp -f "$ASC_KEY_PATH" "$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"

  echo "==> altool --upload-app"
  xcrun altool --upload-app --type ios \
    --file "$IPA" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

  echo ""
  echo "✓ Otpremljeno (${new_version}). Build se sada procesira u App Store Connect-u"
  echo "  (~5–30 min), pa će biti vidljiv u TestFlight / za izbor u verziji."
else
  echo ""
  echo "✓ IPA spreman, upload preskočen (--no-upload)."
fi
