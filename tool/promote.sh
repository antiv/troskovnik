#!/bin/bash
#
# promote.sh — put the tested release of an app into production on both stores.
#
#   tool/promote.sh [<app>] --dry-run --notes-file notes.json   # check both stores, change nothing
#   tool/promote.sh [<app>] --notes en="..." --notes sr="..."
#
#   <app>                 in a workspace, the directory under apps/ (bird_tracker, ...);
#                         left out in a single-app repo
#   --notes LANG=TEXT     What's New for one language (en, sr, de, es, ...) or locale
#                         (es-419); repeatable. --notes-en / --notes-sr are shorthands
#   --notes-file F        the same as JSON: {"en": "...", "de": "..."}
#   --android | --ios     only one store (default: both)
#   --rollout F           Play staged rollout, 0 < F < 1 (default: everyone)
#   --manual-release      App Store: wait for "Release" after approval (default: live on approval)
#
# The version is the one in the app's pubspec.yaml (X.Y.Z+N) — the build the last
# Android upload with the bump and iOS upload without it sent to the internal
# track / TestFlight. Android: versionCode N moves to production
# (tool/play_promote.py). iOS: build N becomes App Store version X.Y.Z and is
# submitted for review (tool/asc_submit.py). Each store listing language gets
# the note for its language, or the English one (tool/release_notes.py); the
# output lists which note every language got. Both stores review the release
# before it is live.
#
set -euo pipefail

TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$TOOL")"
if [[ $# -gt 0 && "$1" != -* && -d "$ROOT/apps/$1" ]]; then
  DIR="$ROOT/apps/$1"; shift
elif [[ -f "$ROOT/pubspec.yaml" && -d "$ROOT/android" ]]; then
  DIR="$ROOT"
else
  sed -n '5,17p' "$0" | sed 's/^#[[:space:]]\{0,1\}//'; exit 64
fi

ANDROID=true; IOS=true; OPTS=(); PLAY_OPTS=(); ASC_OPTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --android)        IOS=false ;;
    --ios)            ANDROID=false ;;
    --dry-run)        OPTS+=(--dry-run) ;;
    --notes)          OPTS+=(--notes "$2"); shift ;;
    --notes-en)       OPTS+=(--notes "en=$2"); shift ;;
    --notes-sr)       OPTS+=(--notes "sr=$2"); shift ;;
    --notes-file)     OPTS+=(--notes-file "$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"); shift ;;
    --rollout)        PLAY_OPTS+=(--rollout "$2"); shift ;;
    --manual-release) ASC_OPTS+=(--manual-release) ;;
    *) echo "Unknown argument: $1" >&2; exit 64 ;;
  esac
  shift
done

version="$(grep -m1 -E '^version:' "$DIR/pubspec.yaml" | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]')"
name="${version%%+*}"; code="${version#*+}"
[[ "$code" != "$version" ]] || { echo "No +build in version '$version'" >&2; exit 1; }
echo "== $(basename "$DIR") $name ($code)"

if $ANDROID; then
  package="$(grep -h -m1 -oE 'applicationId *=? *"[^"]+"' "$DIR"/android/app/build.gradle* | cut -d'"' -f2)"
  # shellcheck disable=SC1091
  source "$DIR/android/deploy.env"
  echo "-- Google Play"
  PLAY_SERVICE_ACCOUNT_JSON="$PLAY_SERVICE_ACCOUNT_JSON" python3 -u "$TOOL/play_promote.py" \
    "$package" "$code" ${PLAY_OPTS[@]+"${PLAY_OPTS[@]}"} ${OPTS[@]+"${OPTS[@]}"}
fi

if $IOS; then
  bundle="$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9_.-]+;' \
    "$DIR/ios/Runner.xcodeproj/project.pbxproj" | grep -v RunnerTests | head -1 | sed -E 's/.* = (.*);/\1/')"
  # shellcheck disable=SC1091
  source "$DIR/ios/deploy.env"
  echo "-- App Store"
  ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" ASC_KEY_PATH="$ASC_KEY_PATH" \
    python3 -u "$TOOL/asc_submit.py" "$bundle" "$name" "$code" ${ASC_OPTS[@]+"${ASC_OPTS[@]}"} ${OPTS[@]+"${OPTS[@]}"}
fi
