#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA/Build/Products/Release/LidStay.app"
ZIP_PATH="$DIST_DIR/LidStay.zip"
PACKAGE_DIR="$DIST_DIR/package"

mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/LidStay.xcodeproj" \
  -scheme LidStay \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
COPYFILE_DISABLE=1 ditto --norsrc "$APP_PATH" "$PACKAGE_DIR/LidStay.app"
install -m 755 "$ROOT_DIR/CLI/lidstay" "$PACKAGE_DIR/lidstay"
find "$PACKAGE_DIR" -name '._*' -delete
COPYFILE_DISABLE=1 ditto --norsrc -c -k "$PACKAGE_DIR" "$ZIP_PATH"

echo "$ZIP_PATH"
