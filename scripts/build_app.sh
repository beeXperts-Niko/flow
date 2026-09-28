#!/bin/bash
# Builds dist/Flow.app: release binary, icon, bundled engine sources + first-run setup script,
# signed with the stable local identity. Prints the identity hash on the last line.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/dist/Flow.app"
RES="$STAGE/Contents/Resources"

cd "$ROOT"
swift build -c release >&2

IDENTITY="$("$ROOT/scripts/ensure_signing_identity.sh")"

rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$RES"
cp "$ROOT/.build/release/Flow" "$STAGE/Contents/MacOS/Flow"
cp "$ROOT/packaging/Info.plist" "$STAGE/Contents/Info.plist"
cp "$ROOT/packaging/AppIcon.icns" "$RES/AppIcon.icns"
mkdir -p "$RES/Languages"
cp "$ROOT/Languages/"*.json "$RES/Languages/"
for lproj in "$ROOT/packaging/"*.lproj; do
  name="$(basename "$lproj")"
  rm -rf "$RES/$name"
  cp -R "$lproj" "$RES/$name"
done
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
chmod +x "$STAGE/Contents/MacOS/Flow"

# Engine sources; the app installs them into its own Python environment on first launch.
rsync -a --delete \
  --exclude '__pycache__' --exclude '*.pyc' --exclude '*.egg-info' --exclude 'tests' --exclude '.venv' \
  "$ROOT/engine/" "$RES/engine/"
cp "$ROOT/packaging/setup_engine.sh" "$RES/setup_engine.sh"
chmod +x "$RES/setup_engine.sh"

# Content hash: a changed engine triggers a reinstall on the next app launch.
VERSION="$(cd "$RES/engine" && find . -type f \( -name '*.py' -o -name '*.toml' \) -print0 \
  | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -c1-12)"
echo "$VERSION" > "$RES/engine.version"

codesign --force --deep --sign "$IDENTITY" --identifier "de.sinthex.flow" "$STAGE" >&2
codesign --verify --strict "$STAGE" >&2
echo "Gebaut: $STAGE (Engine $VERSION)" >&2
echo "$IDENTITY"
