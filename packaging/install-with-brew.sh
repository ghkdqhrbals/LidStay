#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ZIP_PATH="$ROOT_DIR/dist/LidStay.zip"
TAP_NAME="lidstay/local"
TAP_DIR="$(brew --repository)/Library/Taps/lidstay/homebrew-local"
CASK_DIR="$TAP_DIR/Casks"
CASK_PATH="$CASK_DIR/lidstay.rb"

"$ROOT_DIR/packaging/build-cask-zip.sh" >/dev/null

if [[ ! -d "$TAP_DIR" ]]; then
  brew tap-new --no-git "$TAP_NAME" >/dev/null
fi

mkdir -p "$CASK_DIR"

cat > "$CASK_PATH" <<CASK
cask "lidstay" do
  version "1.0"
  sha256 :no_check

  url "file://$ZIP_PATH"
  name "LidStay"
  desc "Menu bar app that keeps a Mac awake while allowing display sleep"
  homepage "https://github.com/ghkdqhrbals/LidStay"

  depends_on macos: ">= :ventura"

  app "LidStay.app"

  zap trash: [
    "~/Library/Preferences/com.local.LidStay.plist",
  ]
end
CASK

brew reinstall --cask --no-quarantine "$TAP_NAME/lidstay"
