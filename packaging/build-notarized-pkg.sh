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
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-Developer ID Application: gyumin hwangbo (4CL25TC734)}"
DEVELOPER_ID_INSTALLER="${DEVELOPER_ID_INSTALLER:-Developer ID Installer: gyumin hwangbo (4CL25TC734)}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-lidstay-notary}"

if ! /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -Fq "\"$DEVELOPER_ID_APPLICATION\""; then
  echo "Missing signing identity: $DEVELOPER_ID_APPLICATION" >&2
  echo "Create it in Xcode > Settings > Accounts > Manage Certificates > Developer ID Application." >&2
  exit 1
fi

if ! /usr/bin/security find-identity -v | /usr/bin/grep -Fq "\"$DEVELOPER_ID_INSTALLER\""; then
  echo "Missing signing identity: $DEVELOPER_ID_INSTALLER" >&2
  echo "Create it in Xcode > Settings > Accounts > Manage Certificates > Developer ID Installer." >&2
  exit 1
fi

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

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH" || true

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
  --sign "$DEVELOPER_ID_INSTALLER" \
  "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH"
spctl --assess --type install --verbose "$PKG_PATH" || true
xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$PKG_PATH"
xcrun stapler validate "$PKG_PATH"

echo "$PKG_PATH"
