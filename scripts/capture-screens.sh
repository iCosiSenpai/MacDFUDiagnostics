#!/bin/zsh
# Photographs the app in its demo mode, for the README and for the website.
#
#   scripts/capture-screens.sh
#
# It builds the app, then opens it once per screen with simulated hardware (nothing real is touched)
# and captures the window: in English for docs/media, and in Italian and English for the website
# when its checkout is at SITE_REPO. The app comes to the front each time, so leave the Mac alone
# for the minute it takes — and unlocked: a locked screen draws windows as inactive, or not at all.
set -euo pipefail

cd "${0:A:h:h}"
SITE_REPO="${SITE_REPO:-$HOME/dev/IPSW-Downloader-Plus}"
APP="$PWD/MacDFUDiagnostics.app"
WORK="$(mktemp -d)"
trap 'pkill -x MacDFUDiagnostics 2>/dev/null; rm -rf "$WORK"' EXIT

if [[ "$(python3 -c 'import Quartz; print(Quartz.CGSessionCopyCurrentDictionary().get("CGSSessionScreenIsLocked", 0))' 2>/dev/null)" == "1" ]]; then
    echo "ERROR: the screen is locked. Unlock the Mac and run this again." >&2
    exit 1
fi

./build-app.sh >/dev/null
swiftc -O Tools/WindowList.swift -o "$WORK/windows"

# shot <output.png> <seconds to settle> <launch arguments…>
shot() {
    local out="$1" settle="$2"; shift 2
    pkill -x MacDFUDiagnostics 2>/dev/null || true
    while pgrep -x MacDFUDiagnostics >/dev/null; do sleep 0.1; done
    open -n "$APP" --args "$@"
    local id=""
    for attempt in {1..160}; do
        id="$("$WORK/windows" | head -1 | cut -d' ' -f1)"
        [[ -n "$id" ]] && break
        sleep 0.25
    done
    [[ -n "$id" ]] || { echo "ERROR: no window for $out" >&2; return 1; }
    sleep "$settle"
    id="$("$WORK/windows" | head -1 | cut -d' ' -f1)"
    mkdir -p "${out:h}"
    screencapture -x -o -l "$id" "$out"
    echo "  ${out#$PWD/}"
}

# The seven screens, by name, with what each needs on the command line.
screens() {
    local dir="$1" lang="$2"
    shot "$dir/connect.png"   3.5 -demo dfu -language "$lang" -appearance dark
    shot "$dir/restoring.png" 4   -demo restoring -language "$lang" -appearance dark
    shot "$dir/disks.png"     3.5 -demo dfu -section disks -language "$lang" -appearance dark
    shot "$dir/macs.png"      3.5 -demo dfu -section macs -language "$lang" -appearance dark
    shot "$dir/inspector.png" 3.5 -demo dfu -inspector device -language "$lang" -appearance dark
    shot "$dir/restore.png"   4   -demo dfu -sheet restore -language "$lang" -appearance dark
    shot "$dir/manual.png"    4   -demo empty -sheet manual -language "$lang" -appearance dark
}

echo "==> README (docs/media)"
screens "$WORK/readme" en
for name in connect restoring disks macs inspector; do
    sips -Z 1400 "$WORK/readme/$name.png" --out "docs/media/$name.png" >/dev/null
done
sips -Z 1400 "$WORK/readme/restore.png" --out docs/media/restore-sheet.png >/dev/null
sips -Z 1400 "$WORK/readme/manual.png" --out docs/media/manual-dfu.png >/dev/null

if [[ -d "$SITE_REPO/site/src/assets/dfu" ]]; then
    echo "==> Website ($SITE_REPO)"
    cp "$WORK/readme/"*.png "$SITE_REPO/site/src/assets/dfu/en/"
    screens "$SITE_REPO/site/src/assets/dfu/it" it
else
    echo "No website checkout at $SITE_REPO: skipped."
fi
echo "==> Done. Look at the pictures before committing them."
