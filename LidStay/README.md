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

## Behavior

- `Mac 켜두기` starts or stops the current session.
- Select a duration, then turn on `Mac 켜두기`.
- Enter custom minutes directly in the main panel.
- The main tab is for choosing time and turning awake mode on or off.
- The options tab contains charging-only behavior, language, About, and quit.
- `충전 중일 때만 Mac 켜두기` keeps the session active only while power is connected.
- The default session is infinite.
- `배터리에서도 사용` permits the assertion while running on battery, although macOS may limit closed-lid behavior on battery.
- By default, battery power blocks the assertion to reduce drain and heat.
- Battery sessions automatically pause at 20% or lower.
- LidStay does not create a display sleep assertion, so the display can still turn off normally and macOS may still show the lock screen when you reopen the lid.
- Lid-closed behavior can still depend on Mac hardware, power source, and macOS policy.

## Homebrew Install

One-command local install:

```bash
./packaging/install-with-brew.sh
```

This builds `dist/LidStay.zip`, creates a local Homebrew tap, writes the cask, and installs the app.

Manual package build:

```bash
./packaging/build-cask-zip.sh
```

Manual install from the generated local tap cask:

```bash
brew reinstall --cask --no-quarantine lidstay/local/lidstay
```

Uninstall:

```bash
brew uninstall --cask lidstay
```
