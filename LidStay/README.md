# LidStay

LidStay is a lightweight macOS 13+ menu bar app that keeps your Mac awake with a public IOKit power assertion while still allowing display sleep.

## Build

```bash
xcodebuild -project LidStay.xcodeproj -scheme LidStay -configuration Debug -derivedDataPath .build/DerivedData build
```

The built app is created at:

```text
.build/DerivedData/Build/Products/Debug/LidStay.app
```

The app bundle includes the `lidstay` CLI. On first launch, LidStay installs or updates the CLI at `/usr/local/bin/lidstay`; macOS may ask for an administrator password if needed.

## Behavior

- `Mac 켜두기` starts or stops the current session.
- Select a duration, then turn on `Mac 켜두기`.
- Enter custom minutes directly in the main panel.
- The main tab is for choosing time and turning awake mode on or off.
- Non-duration settings live in the Options window.
- `전원 연결 중에만 허용` keeps the session active only while power is connected.
- `로그인 시 자동 실행` reopens LidStay after a full macOS login.
- The default session keeps the Mac on until turned off.
- `배터리 조건 허용` permits the assertion while running on battery, although macOS may limit closed-lid behavior on battery.
- By default, battery power blocks the assertion to reduce drain and heat.
- Battery sessions automatically pause at 20% or lower.
- LidStay does not create a display sleep assertion, so the display can still turn off normally and macOS may still show the lock screen when you reopen the lid.
- Lid-closed behavior can still depend on Mac hardware, power source, and macOS policy.

## Homebrew Install

One-command local install:

```bash
./packaging/install-with-brew.sh
```

This builds `dist/LidStay.zip`, creates a local Homebrew tap, writes the cask, and installs the app plus the `lidstay` CLI.
Homebrew links the CLI automatically through the cask `binary "lidstay"` stanza.

## Installer Package

Build a local `.pkg` installer:

```bash
./packaging/build-pkg.sh
```

The pkg installs `LidStay.app` into `/Applications` and `lidstay` into `/usr/local/bin`.

Manual package build:

```bash
./packaging/build-cask-zip.sh
```

Manual install from the generated local tap cask:

```bash
brew reinstall --cask lidstay/local/lidstay
```

Uninstall:

```bash
brew uninstall --cask lidstay
```

## CLI

```bash
lidstay on 2h
lidstay on until-exit npm run dev
lidstay off
lidstay status
```

Duration values support `s`, `m`, and `h`. A plain number is treated as minutes.

## Automatic Updates

LidStay uses Sparkle 2 for automatic updates in direct distribution builds.

The Sparkle EdDSA public key is already embedded in the project. The private key is stored in this Mac's login Keychain. To rotate keys later, run:

```bash
xcodebuild -resolvePackageDependencies -project LidStay.xcodeproj -scheme LidStay -derivedDataPath .build/DerivedData
.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```

Build a notarized update-enabled zip:

```bash
./packaging/build-notarized-zip.sh
```

Generate the appcast:

```bash
RELEASE_TAG="v1.0" ./packaging/generate-appcast.sh
```

## GitHub Actions Release

`.github/workflows/release.yml` builds notarized zip/pkg artifacts, generates Sparkle `appcast.xml`, and uploads them to the GitHub Release when a `v*` tag is pushed.
