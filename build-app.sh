#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

APP_NAME="stayawake"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUNDLE="$HERE/build/${APP_NAME}.app"
BIN_SRC="$HERE/.build/release/${APP_NAME}"

echo "==> swift build -c release"
swift build -c release

echo "==> packaging ${APP_BUNDLE}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_SRC" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

for b in "$HERE"/.build/release/*.bundle; do
    [ -e "$b" ] || continue
    cp -R "$b" "$APP_BUNDLE/Contents/Resources/"
done

if [ -f "$HERE/Sources/stayawake/Resources/stayawake.icns" ]; then
    cp "$HERE/Sources/stayawake/Resources/stayawake.icns" "$APP_BUNDLE/Contents/Resources/stayawake.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>stayawake</string>
    <key>CFBundleDisplayName</key>
    <string>stayawake</string>
    <key>CFBundleIdentifier</key>
    <string>dev.stayawake.app</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>stayawake</string>
    <key>CFBundleIconFile</key>
    <string>stayawake.icns</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>ja</string>
        <string>ko</string>
        <string>fr</string>
        <string>de</string>
        <string>es</string>
    </array>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> ad-hoc signing ${APP_BUNDLE}"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> done: ${APP_BUNDLE}"
echo "    run: open \"${APP_BUNDLE}\""
