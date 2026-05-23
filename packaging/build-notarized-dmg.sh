#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA/Build/Products/Release/LidStay.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/LidStay.dmg"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-lidstay-notary}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing built app: $APP_PATH" >&2
  echo "Run packaging/build-notarized-zip.sh before creating the dmg." >&2
  exit 1
fi

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"

COPYFILE_DISABLE=1 ditto --norsrc "$APP_PATH" "$DMG_ROOT/LidStay.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "LidStay" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "$DMG_PATH"
