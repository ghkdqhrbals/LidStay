# LidStay

LidStay is a native macOS menu bar app for keeping your Mac on for a selected time while still allowing display sleep.

It uses public macOS power APIs only. It does not use private APIs, kernel extensions, LaunchDaemons, or privileged helpers.

## Download

Download the latest app zip:

```text
https://github.com/ghkdqhrbals/LidStay/releases/latest/download/LidStay.zip
```

Unzip it, move `LidStay.app` to Applications, and open it. If macOS shows a security warning on first launch, right-click the app in Finder and choose `Open`.

For a normal double-click install experience outside the Mac App Store, the app must be signed with a Developer ID Application certificate and notarized by Apple.

## Install With Homebrew

From a cloned checkout:

```bash
./packaging/install-with-brew.sh
```

This builds the app, creates a local Homebrew cask, and installs `LidStay.app` plus the `lidstay` CLI.

Manual build:

```bash
./packaging/build-cask-zip.sh
brew reinstall --cask --no-quarantine lidstay/local/lidstay
```

Uninstall:

```bash
brew uninstall --cask lidstay
```

## CLI

LidStay includes a terminal command for developer workflows:

```bash
lidstay on 2h
lidstay on until-exit npm run dev
lidstay off
lidstay status
```

Duration values support `s`, `m`, and `h`. A plain number is treated as minutes.

## Notarized Release Build

Store a notarytool profile once:

```bash
xcrun notarytool store-credentials lidstay-notary --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
```

Build, sign, notarize, staple, and package:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="lidstay-notary" \
./packaging/build-notarized-zip.sh
```

Upload the generated `dist/LidStay.zip` to a GitHub Release.

## Install Page

The user-facing install page lives at:

```text
docs/index.html
```

When GitHub Pages is enabled for the `docs` folder, it gives users a simple download page with Brew as an advanced option.

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
