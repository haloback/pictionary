#!/bin/sh
# Builds Cadence.app (a double-clickable Mac app) into Cadence/build/.
# Usage: ./scripts/build-app.sh   (from the Cadence folder, on macOS 14+)
set -e
cd "$(dirname "$0")/.."

swift build -c release --product Cadence
BIN="$(swift build -c release --show-bin-path)/Cadence"

APP="build/Cadence.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Cadence"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Cadence</string>
    <key>CFBundleDisplayName</key><string>Cadence</string>
    <key>CFBundleIdentifier</key><string>app.cadence.accompanist</string>
    <key>CFBundleExecutable</key><string>Cadence</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>MIDI File</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key><array><string>public.midi-audio</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS will launch it locally.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
