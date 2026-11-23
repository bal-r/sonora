#!/usr/bin/env bash
set -euo pipefail

# Assembles a real .app bundle from the SwiftPM executable.
#
#   CONFIG=release ./scripts/bundle.sh
#   CODESIGN_IDENTITY="Developer ID Application: …" ./scripts/bundle.sh
#
# Local rebuilds use the same Apple Development identity when available.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-release}"
OUTPUT="$ROOT/build/Sonora.app"
IDENTITY="${CODESIGN_IDENTITY:-}"
timestamp=--timestamp

if [[ -z "$IDENTITY" ]]; then
  candidates="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ {print $2}')"
  case "$candidates" in
    *$'\n'*) echo "Multiple Apple Development identities. Set CODESIGN_IDENTITY to the one for Sonora." >&2; exit 1 ;;
    "") IDENTITY=- ;;
    *) IDENTITY="$candidates"; timestamp=--timestamp=none ;;
  esac
fi

if [[ "$IDENTITY" == "-" ]]; then
  echo "Ad-hoc build: macOS may require new permission grants after each code change." >&2
fi

cd "$ROOT"

echo "→ Building ($CONFIG)…"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "→ Assembling bundle…"
mkdir -p "$ROOT/build"
STAGE="$(mktemp -d "$ROOT/build/.bundle.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Sonora.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/Sonora" "$APP/Contents/MacOS/Sonora"
chmod +x "$APP/Contents/MacOS/Sonora"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE.txt"
cp "$ROOT/NOTICE" "$APP/Contents/Resources/NOTICE.txt"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "→ Generating icon…"
  swift "$ROOT/scripts/make-icon.swift" "$ROOT"
fi
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

if [[ -d "$ROOT/Resources/Sounds" ]]; then
  cp -R "$ROOT/Resources/Sounds" "$APP/Contents/Resources/Sounds"
fi

echo "→ Signing ($IDENTITY)…"
if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - \
    --entitlements "$ROOT/Resources/Sonora.entitlements" \
    "$APP"
else
  codesign --force "$timestamp" --options runtime --sign "$IDENTITY" \
    --entitlements "$ROOT/Resources/Sonora.entitlements" \
    "$APP"
fi

codesign --verify --strict --verbose=2 "$APP"
rm -rf "$OUTPUT"
mv "$APP" "$OUTPUT"
echo "✓ $OUTPUT"
