#!/bin/zsh
set -euo pipefail

REPO_ROOT="${0:A:h:h}"
cd "$REPO_ROOT"

NOTARY_PROFILE="${NOTARY_PROFILE:-NOTARY}"
TEAM_ID="6KV8L8WQ9D"
BUNDLE_ID="com.macsenpai.MacDFUDiagnostics"
HELPER_ID="$BUNDLE_ID.vdm-helper"
SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F\" '/Developer ID Application/ {print $2; exit}')}"

if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "ERROR: No Developer ID Application identity found in Keychain." >&2
    exit 1
fi

echo "==> 1. Building Release App Bundle..."
./build-app.sh

VERSION="$(defaults read "$REPO_ROOT/MacDFUDiagnostics.app/Contents/Info" CFBundleShortVersionString)"
echo "==> Version: $VERSION"
echo "==> Signing Identity: $SIGN_IDENTITY"

WORK="$(mktemp -d /tmp/macdfu-release-XXXXXX)"
STAGE_APP="$WORK/MacDFUDiagnostics.app"
APP_ZIP="$WORK/MacDFUDiagnostics-notarize.zip"
DMG_STAGE="$WORK/dmg-stage"
DMG_MOUNT="$WORK/dmg-mount"
RW_DMG="$WORK/rw.dmg"

mkdir -p "$REPO_ROOT/dist" "$DMG_STAGE" "$DMG_MOUNT"
FINAL_DMG="$REPO_ROOT/dist/Mac-DFU-Studio-${VERSION}.dmg"
FINAL_ZIP="$REPO_ROOT/dist/Mac-DFU-Studio-${VERSION}.zip"

cleanup() {
    hdiutil detach "$DMG_MOUNT" -quiet 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

echo "==> 2. Staging clean bundle in $STAGE_APP..."
ditto --norsrc --noextattr --noacl "$REPO_ROOT/MacDFUDiagnostics.app" "$STAGE_APP"
xattr -cr "$STAGE_APP" 2>/dev/null || true

echo "==> 3. Signing nested helper and outer app bundle with hardened runtime..."
# Inside out, never --deep. The helper gets its own identifier: the app refuses to run a helper as
# root unless it is signed by this team *for that identifier*.
codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    --identifier "$HELPER_ID" \
    "$STAGE_APP/Contents/MacOS/macdfu-vdm-helper"

codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$STAGE_APP"

# Verify against the same requirements the app itself enforces (see CodeTrust.swift). A plain
# `codesign --verify` would pass for any signer; these name the team and the identifier.
requirement() {
    echo "=anchor apple generic and identifier \"$1\" and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"$TEAM_ID\""
}
codesign --verify --strict --deep --verbose=2 -R "$(requirement "$BUNDLE_ID")" "$STAGE_APP"
codesign --verify --strict -R "$(requirement "$HELPER_ID")" "$STAGE_APP/Contents/MacOS/macdfu-vdm-helper"
if codesign -d --entitlements - "$STAGE_APP" 2>/dev/null | grep -q get-task-allow; then
    echo "ERROR: the app carries get-task-allow." >&2
    exit 1
fi
echo "    App and helper signatures verified against the team requirement."

notarize_file() {
    local file_to_submit="$1"
    local attempt=1
    while (( attempt <= 3 )); do
        echo "    [Attempt $attempt/3] notarytool submit $(basename "$file_to_submit")..."
        if xcrun notarytool submit "$file_to_submit" --keychain-profile "$NOTARY_PROFILE" --wait; then
            return 0
        fi
        sleep 2
        (( attempt++ ))
    done
    return 1
}

echo "==> 4. Submitting MacDFUDiagnostics.app to Apple Notary Service (profile: $NOTARY_PROFILE)..."
ditto -c -k --sequesterRsrc --keepParent "$STAGE_APP" "$APP_ZIP"
notarize_file "$APP_ZIP"

echo "==> 5. Stapling notarization ticket to MacDFUDiagnostics.app..."
xcrun stapler staple "$STAGE_APP"
xcrun stapler validate "$STAGE_APP"
spctl -a -vv "$STAGE_APP" 2>&1 | tee /dev/stderr | grep -q "source=Notarized Developer ID"

# Copy signed & notarized app back to repo root and create distributable ZIP
rm -rf "$REPO_ROOT/MacDFUDiagnostics.app" "$FINAL_ZIP"
ditto "$STAGE_APP" "$REPO_ROOT/MacDFUDiagnostics.app"
ditto -c -k --sequesterRsrc --keepParent "$STAGE_APP" "$FINAL_ZIP"

echo "==> 6. Building custom Retina DMG ($FINAL_DMG)..."
cp -R "$STAGE_APP" "$DMG_STAGE/MacDFUDiagnostics.app"
ln -s /Applications "$DMG_STAGE/Applications"
mkdir -p "$DMG_STAGE/.background"
cp "$REPO_ROOT/Resources/dmg/background.tiff" "$DMG_STAGE/.background/background.tiff"
cp "$REPO_ROOT/Resources/dmg/DS_Store" "$DMG_STAGE/.DS_Store"

PAYLOAD_KB="$(du -sk "$DMG_STAGE" | awk '{print $1}')"
IMAGE_MB=$(( PAYLOAD_KB / 1024 + 40 ))

hdiutil create -srcfolder "$DMG_STAGE" -volname "Mac DFU Studio" -fs HFS+ \
    -format UDRW -size "${IMAGE_MB}m" "$RW_DMG" -quiet

hdiutil attach "$RW_DMG" -mountpoint "$DMG_MOUNT" -nobrowse -quiet
cp "$STAGE_APP/Contents/Resources/AppIcon.icns" "$DMG_MOUNT/.VolumeIcon.icns"
SetFile -a C "$DMG_MOUNT" 2>/dev/null || true
sync
hdiutil detach "$DMG_MOUNT" -quiet

rm -f "$FINAL_DMG"
hdiutil convert "$RW_DMG" -format ULFO -o "$FINAL_DMG" -quiet

echo "==> 7. Signing, Notarizing & Stapling DMG..."
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$FINAL_DMG"
notarize_file "$FINAL_DMG"
xcrun stapler staple "$FINAL_DMG"
xcrun stapler validate "$FINAL_DMG"
spctl -a -vv -t open --context context:primary-signature "$FINAL_DMG" 2>&1 | tee /dev/stderr | grep -q "source=Notarized Developer ID"

echo "==> SUCCESS! Signed, Notarized & Stapled artifacts:"
ls -lh "$FINAL_DMG" "$FINAL_ZIP"
