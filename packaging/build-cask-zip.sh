#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA/Build/Products/Release/LidStay.app"
ZIP_PATH="$DIST_DIR/LidStay.zip"

mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/LidStay.xcodeproj" \
  -scheme LidStay \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "$ZIP_PATH"
