#!/bin/zsh
set -euo pipefail

cd "${0:A:h}"
echo "Generating AppIcon.icns..."
swift Tools/GenerateIcon.swift
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
rm -rf Resources/AppIcon.iconset

echo "Building MacDFUDiagnostics & macdfu-vdm-helper (Release)..."
swift build -c release

APP_DIR="MacDFUDiagnostics.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/release/MacDFUDiagnostics" "$APP_DIR/Contents/MacOS/MacDFUDiagnostics"
cp ".build/release/macdfu-vdm-helper" "$APP_DIR/Contents/MacOS/macdfu-vdm-helper"
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "Resources/AppLogo.png" "$APP_DIR/Contents/Resources/AppLogo.png"
chmod +x "$APP_DIR/Contents/MacOS/MacDFUDiagnostics" "$APP_DIR/Contents/MacOS/macdfu-vdm-helper"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacDFUDiagnostics</string>
    <key>CFBundleIdentifier</key>
    <string>com.macsenpai.MacDFUDiagnostics</string>
    <key>CFBundleName</key>
    <string>Mac DFU Studio</string>
    <key>CFBundleDisplayName</key>
    <string>Mac DFU Studio</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.3.0</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
echo "Created bundle: $(pwd)/$APP_DIR"
