#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="${APP_PATH:-$DERIVED_DATA/Build/Products/Release/LidStay.app}"
ZIP_PATH="${ZIP_PATH:-$DIST_DIR/LidStay.zip}"
UPDATES_DIR="${UPDATES_DIR:-$DIST_DIR/updates}"
RELEASE_NOTES="${RELEASE_NOTES:-$ROOT_DIR/docs/release-notes.md}"
PRODUCT_URL="${PRODUCT_URL:-https://github.com/ghkdqhrbals/LidStay}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app at $APP_PATH. Run packaging/build-notarized-zip.sh first." >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing zip at $ZIP_PATH. Run packaging/build-notarized-zip.sh first." >&2
  exit 1
fi

if ! codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
  echo "The app at $APP_PATH is not code signed correctly." >&2
  echo "Run packaging/build-notarized-zip.sh with your Developer ID Application certificate before generating appcast.xml." >&2
  exit 1
fi

SPARKLE_GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-}"
if [[ -z "$SPARKLE_GENERATE_APPCAST" ]]; then
  SPARKLE_GENERATE_APPCAST="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
fi

if [[ ! -x "$SPARKLE_GENERATE_APPCAST" ]]; then
  echo "Missing Sparkle generate_appcast tool. Resolve/build the Sparkle package first, or set SPARKLE_GENERATE_APPCAST." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")"
RELEASE_TAG="${RELEASE_TAG:-v$VERSION}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/ghkdqhrbals/LidStay/releases/download/$RELEASE_TAG}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX%/}/"
ARCHIVE_NAME="LidStay-$VERSION-$BUILD.zip"

mkdir -p "$UPDATES_DIR"
cp "$ZIP_PATH" "$UPDATES_DIR/$ARCHIVE_NAME"

if [[ -f "$RELEASE_NOTES" ]]; then
  cp "$RELEASE_NOTES" "$UPDATES_DIR/${ARCHIVE_NAME%.zip}.md"
fi

ARGS=(
  --download-url-prefix "$DOWNLOAD_URL_PREFIX"
  --link "$PRODUCT_URL"
)

if [[ -n "${SPARKLE_PRIVATE_ED_KEY_FILE:-}" ]]; then
  ARGS+=(--ed-key-file "$SPARKLE_PRIVATE_ED_KEY_FILE")
fi

"$SPARKLE_GENERATE_APPCAST" "${ARGS[@]}" "$UPDATES_DIR"

echo "$UPDATES_DIR/appcast.xml"
