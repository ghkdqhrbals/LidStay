# LidStay

LidStay is a native macOS menu bar app for keeping your Mac on for a selected time while still allowing display sleep.

It uses public macOS power APIs only. It does not use private APIs, kernel extensions, LaunchDaemons, or privileged helpers.

## Install With Homebrew

From a cloned checkout:

```bash
./packaging/install-with-brew.sh
```

This builds the app, creates a local Homebrew cask, and installs `LidStay.app`.

Manual build:

```bash
./packaging/build-cask-zip.sh
brew reinstall --cask --no-quarantine lidstay/local/lidstay
```

Uninstall:

```bash
brew uninstall --cask lidstay
```

## Install Page

The user-facing install page lives at:

```text
docs/index.html
```

When GitHub Pages is enabled for the `docs` folder, it gives users a simple Brew install interface.

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
- Choose `무제한`, `30분`, `1시간`, `2시간`, or a custom duration.
- The menu bar icon changes between off, on, and unlimited states.
- `충전 중일 때만 Mac 켜두기` keeps the session active only while power is connected.
- Battery sessions automatically pause at 20% or lower.
- Display sleep remains allowed, so the display can still turn off normally.
- Closed-lid behavior can still depend on Mac hardware, power source, and macOS policy.
