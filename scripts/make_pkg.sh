#!/bin/bash
# Builds the installer for other Macs: dist/Flow-<version>.pkg (installs /Applications/Flow.app)
# plus dist/Flow-<version>.zip (the bare app, for drag-and-drop installs).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")"
PKG="$DIST/Flow-$VERSION.pkg"
ZIP="$DIST/Flow-$VERSION.zip"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

"$ROOT/scripts/build_app.sh" >/dev/null

mkdir -p "$WORK/root/Applications"
# Drop extended attributes (Synology/provenance/quarantine); pkgbuild would ship them as ._ files.
ditto --norsrc --noextattr --noqtn "$DIST/Flow.app" "$WORK/root/Applications/Flow.app"
export COPYFILE_DISABLE=1

# Never relocate into another copy of the bundle (e.g. a synced dist/Flow.app) – always /Applications.
pkgbuild --analyze --root "$WORK/root" "$WORK/components.plist" >/dev/null
/usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' "$WORK/components.plist"

rm -f "$PKG" "$ZIP"
pkgbuild \
  --root "$WORK/root" \
  --component-plist "$WORK/components.plist" \
  --identifier "de.sinthex.flow" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG"

ditto -c -k --norsrc --noextattr --noqtn --keepParent "$WORK/root/Applications/Flow.app" "$ZIP"

echo "Paket: $PKG ($(du -h "$PKG" | cut -f1))"
echo "App-Zip: $ZIP ($(du -h "$ZIP" | cut -f1))"
