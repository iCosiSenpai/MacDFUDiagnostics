#!/bin/zsh
# Builds MacDFUDiagnostics.app from the Swift package.
#
#   ./build-app.sh            release build, ad-hoc signed (for running locally)
#   ./build-app.sh --icon     also regenerate Resources/AppIcon.icns from Tools/GenerateIcon.swift
#
# The version lives here and nowhere else.
set -euo pipefail

VERSION="${VERSION:-2.1.0}"
BUILD="${BUILD:-7}"

cd "${0:A:h}"
APP="MacDFUDiagnostics.app"
BUNDLE_ID="com.macsenpai.MacDFUDiagnostics"
HELPER_ID="$BUNDLE_ID.vdm-helper"

if [[ "${1:-}" == "--icon" || ! -f Resources/AppIcon.icns ]]; then
    echo "==> Generating the app icon"
    swift Tools/GenerateIcon.swift
    iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
    rm -rf Resources/AppIcon.iconset
fi

echo "==> Building (release)"
# SwiftPM stamps the binary with the deployment target as its SDK version. macOS reads that stamp to
# decide how to draw the app, and "built with the macOS 15 SDK" means the pre-Liquid Glass look. Record
# the SDK actually used, while still allowing the app to launch on macOS 15.
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
LINK_FLAGS=(-Xlinker -platform_version -Xlinker macos -Xlinker 15.0 -Xlinker "$SDK_VERSION")
swift build -c release "${LINK_FLAGS[@]}"
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/MacDFUDiagnostics" "$BIN/macdfu-vdm-helper" "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "==> Compiling shaders"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
AIR="$(mktemp -t Effects).air"
xcrun -sdk macosx metal -mmacosx-version-min=15.0 -F "$SDK/System/Library/Frameworks" \
    -c Shaders/Effects.metal -o "$AIR"
xcrun -sdk macosx metallib "$AIR" -o "$APP/Contents/Resources/Effects.metallib"
rm -f "$AIR"

echo "==> Compiling the string catalog"
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$APP/Contents/Resources"
# English is the source language, so the catalog compiles no table for it — but the system only offers
# the languages it finds a folder for, and without this one an English Mac would be served Italian.
mkdir -p "$APP/Contents/Resources/en.lproj"
[[ -f "$APP/Contents/Resources/en.lproj/Localizable.strings" ]] || printf '/* English is the source language. */\n' > "$APP/Contents/Resources/en.lproj/Localizable.strings"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>it</string>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Apple Restore Image</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.apple.itunes.ipsw</string>
            </array>
        </dict>
    </array>
    <key>CFBundleExecutable</key>
    <string>MacDFUDiagnostics</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Mac DFU Studio</string>
    <key>CFBundleDisplayName</key>
    <string>Mac DFU Studio</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Alessio Cosi. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Ad-hoc signature for local runs. Inside out, never --deep: the helper first, with its own identifier.
codesign --force --sign - --identifier "$HELPER_ID" "$APP/Contents/MacOS/macdfu-vdm-helper"
codesign --force --sign - "$APP"

echo "==> Built $(pwd)/$APP ($VERSION, build $BUILD)"
