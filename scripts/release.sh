#!/bin/zsh
# Publishes a release, start to finish, from the version in build-app.sh:
#
#   1. checks the tree is clean, on main, and that this version is new and has its notes;
#   2. runs the tests;
#   3. builds, signs, notarizes and staples the app (scripts/release-dmg.sh);
#   4. tests the notarized bundle the way the in-app updater will;
#   5. tags, pushes, and creates the GitHub release with the zip (what the updater installs) and the DMG;
#   6. redeploys the website, which reads the newest release of every app and so follows this one.
#
#   scripts/release.sh            the whole thing
#   scripts/release.sh --dry-run  steps 1 and 2 only: nothing is built, pushed or published
#
# The website lives in another repository. SITE_REPO says where its checkout is; if it is not there,
# the release still goes out and the script says how to update the site by hand.
set -euo pipefail

cd "${0:A:h:h}"
SITE_REPO="${SITE_REPO:-$HOME/dev/IPSW-Downloader-Plus}"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

VERSION="$(sed -n 's/^VERSION="\${VERSION:-\([0-9.]*\)}"$/\1/p' build-app.sh)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: no version found in build-app.sh" >&2; exit 1; }
TAG="v$VERSION"
NOTES="docs/release-notes/$VERSION.md"

echo "==> Releasing Mac DFU Studio $VERSION"
[[ "$(git branch --show-current)" == "main" ]] || { echo "ERROR: releases are cut from main." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "ERROR: commit or stash your changes first." >&2; git status --short >&2; exit 1; }
[[ -f "$NOTES" ]] || { echo "ERROR: write the release notes in $NOTES first." >&2; exit 1; }
git fetch --quiet origin --tags
if git rev-parse --quiet --verify "refs/tags/$TAG" >/dev/null; then
    echo "ERROR: $TAG already exists. Bump VERSION and BUILD in build-app.sh." >&2
    exit 1
fi
[[ "$(git rev-list --count HEAD..origin/main)" == "0" ]] || { echo "ERROR: origin/main has commits this checkout lacks." >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: gh is not signed in." >&2; exit 1; }

echo "==> Tests"
swift test 2>&1 | tail -3

if (( DRY_RUN )); then
    echo "==> Dry run: everything is in place for $TAG. Nothing was built or published."
    exit 0
fi

scripts/release-dmg.sh
ZIP="dist/Mac-DFU-Studio-$VERSION.zip"
DMG="dist/Mac-DFU-Studio-$VERSION.dmg"
[[ -f "$ZIP" && -f "$DMG" ]] || { echo "ERROR: the release artifacts are missing." >&2; exit 1; }

echo "==> Testing the notarized bundle as the updater will"
CHECK="$(mktemp -d)"
trap 'rm -rf "$CHECK"' EXIT
ditto -x -k "$ZIP" "$CHECK"
MACDFU_RELEASE_APP="$CHECK/MacDFUDiagnostics.app" MACDFU_RELEASE_VERSION="$VERSION" swift test --filter ReleaseArtifact 2>&1 | tail -3

echo "==> Publishing $TAG"
git tag -a "$TAG" -m "Mac DFU Studio $VERSION"
git push --quiet origin refs/heads/main "refs/tags/$TAG"
# The zip goes first: it is the asset the in-app updater downloads.
gh release create "$TAG" "$ZIP" "$DMG" --title "Mac DFU Studio $VERSION" --notes-file "$NOTES" --verify-tag
echo "    $(gh release view "$TAG" --json url -q .url)"

echo "==> Website"
if [[ -f "$SITE_REPO/scripts/deploy-site-cloudflare.mjs" ]]; then
    if (cd "$SITE_REPO" && npm run --silent site:deploy && npm run --silent site:verify -- https://icosisenpai.app); then
        echo "==> The website now offers $VERSION."
    else
        echo "WARNING: the release is out, but the website was not updated." >&2
        echo "         Usually the Cloudflare login has expired. Renew it and deploy:" >&2
        echo "           cd $SITE_REPO && npx wrangler auth create ipsw-personal --scopes account:read user:read workers:write workers_routes:write workers_scripts:write zone:read d1:write" >&2
        echo "           cd $SITE_REPO && npm run site:deploy" >&2
    fi
else
    echo "WARNING: no website checkout at $SITE_REPO. Run 'npm run site:deploy' there to make the site offer $VERSION." >&2
fi
