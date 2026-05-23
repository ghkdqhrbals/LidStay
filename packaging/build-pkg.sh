#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
PKG_ROOT="$DIST_DIR/pkg-root"
APP_PATH="$DERIVED_DATA/Build/Products/Release/LidStay.app"
PKG_PATH="$DIST_DIR/LidStay.pkg"
COMPONENT_PLIST="$DIST_DIR/pkg-components.plist"
VERSION="${LIDSTAY_VERSION:-}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/ghkdqhrbals/LidStay/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-SFBDrWBr+kRxZOiUM1xHY+XgbC8vqAZ9fcLadJ9Trmw=}"

mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/LidStay.xcodeproj" \
  -scheme LidStay \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  "SPARKLE_FEED_URL=$SPARKLE_FEED_URL" \
  "SPARKLE_PUBLIC_ED_KEY=$SPARKLE_PUBLIC_ED_KEY" \
  build

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")"
fi
VERSION="${VERSION#v}"

rm -rf "$PKG_ROOT" "$PKG_PATH" "$COMPONENT_PLIST"
mkdir -p "$PKG_ROOT/Applications" "$PKG_ROOT/usr/local/bin"

COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn --noacl "$APP_PATH" "$PKG_ROOT/Applications/LidStay.app"
install -m 755 "$ROOT_DIR/CLI/lidstay" "$PKG_ROOT/usr/local/bin/lidstay"
find "$PKG_ROOT" -name '._*' -delete
xattr -cr "$PKG_ROOT"
pkgbuild --analyze --root "$PKG_ROOT" "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST"

COPYFILE_DISABLE=1 pkgbuild \
  --root "$PKG_ROOT" \
  --component-plist "$COMPONENT_PLIST" \
  --identifier "com.ghkdqhrbals.LidStay.pkg" \
  --version "$VERSION" \
  --install-location / \
  "$PKG_PATH"

echo "$PKG_PATH"
