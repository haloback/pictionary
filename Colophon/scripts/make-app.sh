#!/bin/bash
# Builds Colophon.app from the Swift package. Run from anywhere on a Mac with Xcode 15+.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
APP="build/Colophon.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Colophon"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Colophon"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources/Fonts"
cp Fonts/*.ttf "$APP/Contents/Resources/Fonts/"
cp -R Fonts/licenses "$APP/Contents/Resources/Fonts/licenses"

# App icon, drawn with Core Graphics at build time.
if swift scripts/make-icon.swift build/AppIcon.iconset >/dev/null 2>&1; then
    iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature so Gatekeeper lets it run locally.
codesign --force --deep --sign - "$APP"

echo "Built $APP"
