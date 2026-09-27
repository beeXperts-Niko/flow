#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUPPORT="$HOME/Library/Application Support/Flow"
PYTHON="$SUPPORT/.venv/bin/python"
APP="/Applications/Flow.app"

mkdir -p "$SUPPORT"
if [[ ! -x "$PYTHON" ]]; then
  uv venv --python 3.12 "$SUPPORT/.venv"
fi

echo "Installiere Whisper und MLX…"
uv pip install --python "$PYTHON" "$ROOT/engine"

if [[ ! -f "$SUPPORT/config.json" ]]; then
  cat > "$SUPPORT/config.json" <<EOF
{
  "commandMode" : true,
  "dictionary" : "",
  "hotkey" : "function",
  "instructions" : "",
  "language" : "auto",
  "nativeLanguage" : "de",
  "launchAtLogin" : false,
  "modelPath" : "$HOME/Models/Qwen3.8-27B-Uncensored-MLX/4-bit",
  "openAIModel" : "auto",
  "playSounds" : true,
  "polishProvider" : "openai",
  "port" : 17321,
  "style" : "auto",
  "whisperModel" : "mlx-community/whisper-large-v3-turbo"
}
EOF
fi

echo "Lade das Whisper-Modell…"
"$PYTHON" - <<'PY'
from huggingface_hub import snapshot_download
snapshot_download("mlx-community/whisper-large-v3-turbo")
print("Whisper-Gewichte liegen lokal.")
PY

echo "Baue die Mac-App…"
cd "$ROOT"
swift build -c release

STAGE="$ROOT/dist/Flow.app"
rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$ROOT/.build/release/Flow" "$STAGE/Contents/MacOS/Flow"
cp "$ROOT/packaging/Info.plist" "$STAGE/Contents/Info.plist"
if [[ ! -f "$ROOT/packaging/AppIcon.icns" ]]; then
  swift "$ROOT/scripts/make_icon.swift" "$ROOT/dist/AppIcon.iconset"
  iconutil -c icns "$ROOT/dist/AppIcon.iconset" -o "$ROOT/packaging/AppIcon.icns"
fi
cp "$ROOT/packaging/AppIcon.icns" "$STAGE/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
chmod +x "$STAGE/Contents/MacOS/Flow"

IDENTITY=""
if IDENTITY="$("$ROOT/scripts/ensure_signing_identity.sh")"; then
  echo "Signiere mit stabiler Identität: $IDENTITY"
  codesign --force --deep --sign "$IDENTITY" --identifier "de.dietergeschaeft.Flow" "$STAGE"
else
  echo "FEHLER: Stabile Codesign-Identität fehlt – ohne sie gehen Mikro/Bedienungshilfen nach jedem Update verloren." >&2
  echo "Log: $SUPPORT/signing-setup.log" >&2
  exit 1
fi

osascript -e 'tell application "Flow" to quit' >/dev/null 2>&1 || true
if pgrep -f "/Applications/Flow.app/Contents/MacOS/Flow" >/dev/null 2>&1; then
  pkill -f "/Applications/Flow.app/Contents/MacOS/Flow" || true
  sleep 0.4
fi
rm -rf "$APP"
cp -R "$STAGE" "$APP"
codesign --force --deep --sign "$IDENTITY" --identifier "de.dietergeschaeft.Flow" "$APP"
echo "Installiert: $APP (Signatur bleibt über Updates stabil)"
