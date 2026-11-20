#!/bin/zsh
# Keeps Resources/Localizable.xcstrings in step with the source code.
#
#   1. Builds the app so the compiler writes out every localizable string it found (.stringsdata).
#   2. Merges those keys into the string catalog — new ones appear, unused ones are dropped.
#   3. Fills in Italian from Tools/italian.json and fails if any key is left without a translation.
#
# Run it after adding or changing user-facing text:  Tools/sync-strings.sh
set -euo pipefail

cd "${0:A:h:h}"
CATALOG="Resources/Localizable.xcstrings"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

[[ -f "$CATALOG" ]] || printf '{\n  "sourceLanguage" : "en",\n  "strings" : {\n\n  },\n  "version" : "1.0"\n}\n' > "$CATALOG"

swift build --build-path "$BUILD" --target MacDFUDiagnostics >/dev/null
find "$BUILD" -name '*.stringsdata' -path '*MacDFUDiagnostics*' -print0 \
    | xargs -0 xcrun xcstringstool sync "$CATALOG" --stringsdata

/usr/bin/python3 - "$CATALOG" Tools/italian.json <<'PY'
import json, sys

catalog_path, italian_path = sys.argv[1], sys.argv[2]
catalog = json.load(open(catalog_path, encoding="utf-8"))
italian = json.load(open(italian_path, encoding="utf-8"))

# The sync marks strings the code no longer uses as stale instead of removing them. Remove them.
stale = [key for key, entry in catalog["strings"].items() if entry.get("extractionState") == "stale"]
for key in stale:
    del catalog["strings"][key]

missing = []
for key, entry in catalog["strings"].items():
    if key in italian:
        entry.setdefault("localizations", {})["it"] = {"stringUnit": {"state": "translated", "value": italian[key]}}
    else:
        missing.append(key)

with open(catalog_path, "w", encoding="utf-8") as handle:
    json.dump(catalog, handle, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : "))
    handle.write("\n")

unused = sorted(set(italian) - set(catalog["strings"]))
if unused:
    for key in unused:
        del italian[key]
    with open(italian_path, "w", encoding="utf-8") as handle:
        json.dump(italian, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"Removed {len(unused)} translation(s) the code no longer uses.")
if missing:
    print("Keys without an Italian translation (add them to Tools/italian.json):")
    for key in sorted(missing):
        print("  ", repr(key))
    sys.exit(1)
print(f"{len(catalog['strings'])} strings, all translated.")
PY
