#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA/Build/Products/Release/LidStay.app"
ZIP_PATH="$DIST_DIR/LidStay.zip"
PACKAGE_DIR="$DIST_DIR/package"

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION, for example: Developer ID Application: Your Name (TEAMID)}"
: "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to a stored notarytool keychain profile}"

mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/LidStay.xcodeproj" \
  -scheme LidStay \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH" || true

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
COPYFILE_DISABLE=1 ditto --norsrc "$APP_PATH" "$PACKAGE_DIR/LidStay.app"
install -m 755 "$ROOT_DIR/CLI/lidstay" "$PACKAGE_DIR/lidstay"
find "$PACKAGE_DIR" -name '._*' -delete
COPYFILE_DISABLE=1 ditto --norsrc -c -k "$PACKAGE_DIR" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

COPYFILE_DISABLE=1 ditto --norsrc "$APP_PATH" "$PACKAGE_DIR/LidStay.app"
install -m 755 "$ROOT_DIR/CLI/lidstay" "$PACKAGE_DIR/lidstay"
find "$PACKAGE_DIR" -name '._*' -delete
COPYFILE_DISABLE=1 ditto --norsrc -c -k "$PACKAGE_DIR" "$ZIP_PATH"

echo "$ZIP_PATH"
