#!/bin/bash
# Uploads ../flow-site/ and dist/Flow-<version>.pkg to https://sinthex.de/flow/
# Older Flow-*.pkg files on the server stay in place.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$(cd "$ROOT/../flow-site" && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")"
PKG="$ROOT/dist/Flow-$VERSION.pkg"
REMOTE="sinthex:hosting/sinthex.de/flow"
BASE="https://sinthex.de/flow"

python3 - "$ROOT" "$SITE" "$VERSION" <<'PY'
import json, pathlib, sys
root, site, version = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
latest = json.loads((site / "latest.json").read_text())
if latest.get("version") != version:
    sys.exit(f"latest.json ist {latest.get('version')}, Info.plist ist {version}")
expected = f"https://sinthex.de/flow/Flow-{version}.pkg"
if latest.get("pkg") != expected:
    sys.exit(f"latest.json pkg ist {latest.get('pkg')}, erwartet {expected}")
en = json.loads((root / "Languages" / "en.json").read_text())
keys = [k for k in en if not str(k).startswith("_")]
keyset = set(keys)
bad = []
for path in sorted((root / "Languages").glob("*.json")):
    data = json.loads(path.read_text())
    have = {k for k in data if not str(k).startswith("_")}
    missing = [k for k in keys if k not in have]
    extra = sorted(have - keyset)
    if missing or extra:
        bad.append(f"{path.name}: fehlend {len(missing)}, zusätzlich {len(extra)}")
if bad:
    sys.exit("Sprachdateien unvollständig:\n" + "\n".join(bad))
PY

if [[ ! -f "$PKG" ]]; then
  echo "Paket fehlt: $PKG" >&2
  echo "Zuerst ./scripts/make_pkg.sh ausführen." >&2
  exit 1
fi

rsync -a --checksum \
  --exclude '.DS_Store' \
  --exclude '.git/' \
  --exclude '.gitignore' \
  --exclude '*.pkg' \
  -e ssh \
  "$SITE/" "$REMOTE/"

rsync -a --checksum -e ssh "$PKG" "$REMOTE/Flow-$VERSION.pkg"

python3 - "$VERSION" "$PKG" "$BASE" <<'PY'
import json, pathlib, sys, urllib.request
version, pkg, base = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3]
with urllib.request.urlopen(f"{base}/latest.json", timeout=30) as res:
    feed = json.load(res)
expected = f"{base}/Flow-{version}.pkg"
if feed.get("version") != version or feed.get("pkg") != expected:
    sys.exit(f"latest.json online ist {feed}, erwartet {version} {expected}")
req = urllib.request.Request(expected, method="HEAD")
with urllib.request.urlopen(req, timeout=30) as res:
    length = int(res.headers.get("Content-Length") or 0)
    local = pkg.stat().st_size
    if res.status != 200 or length != local:
        sys.exit(f"Paket online: HTTP {res.status}, {length} Bytes, lokal {local}")
with urllib.request.urlopen(f"{base}/", timeout=30) as res:
    page = res.read().decode("utf-8", "replace")
if f"Flow-{version}.pkg" not in page:
    sys.exit("Die Startseite verlinkt das neue Paket nicht")
print(f"Online: {version}, Paket {length} Bytes")
PY
