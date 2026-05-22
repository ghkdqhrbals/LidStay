#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA/Build/Products/Release/LidStay.app"
ZIP_PATH="$DIST_DIR/LidStay.zip"

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

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "$ZIP_PATH"
