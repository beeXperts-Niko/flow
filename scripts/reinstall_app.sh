#!/bin/bash
# Fast rebuild + install with stable codesigning (preserves Mic/AX permissions).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="/Applications/Flow.app"
STAGE="$ROOT/dist/Flow.app"

echo "Baue Flow…"
IDENTITY="$("$ROOT/scripts/build_app.sh" | tail -1)"
echo "Signiert mit: $IDENTITY"

osascript -e 'tell application "Flow" to quit' >/dev/null 2>&1 || true
pkill -f "/Applications/Flow.app/Contents/MacOS/Flow" >/dev/null 2>&1 || true
sleep 0.4

rm -rf "$APP"
ditto "$STAGE" "$APP"

codesign -dv --verbose=2 "$APP" 2>&1 | grep -E 'Authority|Identifier|TeamIdentifier' || true
echo "Installiert: $APP"
open "$APP"
