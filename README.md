# LidStay

LidStay is a native macOS menu bar app for keeping your Mac on for a selected time while still allowing display sleep.

It uses public macOS power APIs only. It does not use private APIs, kernel extensions, LaunchDaemons, or privileged helpers.

## Download

Recommended download:

```text
https://github.com/ghkdqhrbals/LidStay/releases/latest/download/LidStay.zip
```

Unzip it, move `LidStay.app` to Applications, and open it. On first launch, LidStay installs or updates `lidstay` into `/usr/local/bin`. macOS may ask for an administrator password if that folder is not writable.

Installer package:

```text
https://github.com/ghkdqhrbals/LidStay/releases/latest/download/LidStay.pkg
```

Open `LidStay.pkg` to install `LidStay.app` into `/Applications` and `lidstay` into `/usr/local/bin`.

For a normal double-click install experience outside the Mac App Store, the app must be signed with a Developer ID Application certificate and notarized by Apple.

## Install With Homebrew

From a cloned checkout:

```bash
./packaging/install-with-brew.sh
```

This builds the app, creates a local Homebrew cask, and installs `LidStay.app` plus the `lidstay` CLI.

Homebrew links the CLI automatically through the cask `binary "lidstay"` stanza.

Manual build:

```bash
./packaging/build-cask-zip.sh
brew reinstall --cask lidstay/local/lidstay
```

Uninstall:

```bash
brew uninstall --cask lidstay
```

Manual uninstall:

```bash
lidstay uninstall
```

Use `lidstay uninstall --purge` to also remove LidStay preferences and local Application Support data.

## CLI

LidStay includes a terminal command for developer workflows:

```bash
lidstay on 2h
lidstay on until-exit npm run dev
lidstay off
lidstay status
lidstay notify-test
lidstay uninstall
```

Duration values support `s`, `m`, and `h`. A plain number is treated as minutes.

## Automatic Updates

LidStay uses Sparkle 2 for direct-distribution updates outside the Mac App Store.

The Sparkle EdDSA public key is already embedded in the project. The private key is stored in this Mac's login Keychain. To rotate keys later, run:

```bash
xcodebuild -resolvePackageDependencies -project LidStay.xcodeproj -scheme LidStay -derivedDataPath .build/DerivedData
.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```

Build a notarized update-enabled zip:

```bash
./packaging/build-notarized-zip.sh
```

Generate the Sparkle appcast after the notarized zip is built:

```bash
RELEASE_TAG="v1.0" ./packaging/generate-appcast.sh
```

Upload `dist/LidStay.zip`, `dist/updates/LidStay-<version>-<build>.zip`, and `dist/updates/appcast.xml` to the GitHub Release. The app reads updates from:

```text
https://github.com/ghkdqhrbals/LidStay/releases/latest/download/appcast.xml
```

## Notarized Release Build

Store a notarytool profile once:

```bash
xcrun notarytool store-credentials lidstay-notary --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
```

Build, sign, notarize, staple, and package the app-only zip:

```bash
./packaging/build-notarized-zip.sh
```

Build, sign, notarize, staple, and package the installer that also installs the CLI:

```bash
./packaging/build-notarized-pkg.sh
```

The release scripts default to:

```text
Developer ID Application: gyumin hwangbo (4CL25TC734)
Developer ID Installer: gyumin hwangbo (4CL25TC734)
notarytool profile: lidstay-notary
```

Upload the generated `dist/LidStay.pkg` and `dist/LidStay.zip` to a GitHub Release.

## GitHub Actions Release

Tagged releases are built automatically by `.github/workflows/release.yml`.

The workflow needs these GitHub repository secrets for the primary zip release and Sparkle automatic updates:

```text
APP_STORE_CONNECT_API_KEY_BASE64
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64
DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
SPARKLE_PRIVATE_ED_KEY
```

These two secrets are optional. Add them only if you also want the workflow to publish `LidStay.pkg`:

```text
DEVELOPER_ID_INSTALLER_CERTIFICATE_BASE64
DEVELOPER_ID_INSTALLER_CERTIFICATE_PASSWORD
```

Use these local commands to prepare the secret values:

```bash
base64 -i /Users/ghkdqhrbals/keys/AuthKey_QJW24W7F76.p8 | pbcopy
.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x /tmp/lidstay-sparkle-private-key
pbcopy < /tmp/lidstay-sparkle-private-key
```

Export the Developer ID Application certificate as a `.p12` file from Keychain Access, then base64 it and store the value in the matching secret. Export the Developer ID Installer certificate only if you also want pkg publishing.

`KEYCHAIN_PASSWORD` is generated inside GitHub Actions at runtime and is not a repository secret.

To publish a release, push a tag:

```bash
git tag v1.0
git push origin v1.0
```

## Install Page

The user-facing install page lives at:

```text
docs/index.html
```

`.github/workflows/pages.yml` deploys this folder to GitHub Pages. In the GitHub repository settings, set Pages to use GitHub Actions, then push to `main` or run the workflow manually.

## Product Requirements

The current product definition and implementation requirements are documented in:

```text
docs/PRD.md
```

## Build

```bash
xcodebuild -project LidStay.xcodeproj -scheme LidStay -configuration Debug -derivedDataPath .build/DerivedData build
```

The built app is created at:

```text
.build/DerivedData/Build/Products/Debug/LidStay.app
```

## Behavior

- `Mac 켜두기` starts or stops the current session.
- Choose `계속 켜두기`, `30분`, `1시간`, `2시간`, or a custom duration.
- The menu bar icon changes between off, on, and keep-on states.
- `충전 중일 때만 Mac 켜두기` keeps the session active only while power is connected.
- `로그인 시 자동 실행` reopens LidStay after a full macOS login.
- Battery sessions automatically pause at 20% or lower.
- Display sleep remains allowed, so the display can still turn off normally.
- Closed-lid behavior can still depend on Mac hardware, power source, and macOS policy.
