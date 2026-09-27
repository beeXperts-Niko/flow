#!/bin/bash
# Bundled in Flow.app/Contents/Resources. Flow runs it on first launch and whenever the bundled
# engine version changes. Args: <engine source dir> <support dir> <engine version>
set -euo pipefail

ENGINE_SRC="$1"
SUPPORT="$2"
VERSION="$3"

# GUI apps start with a minimal PATH.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo "== Flow-Engine einrichten ($VERSION)"

if ! command -v uv >/dev/null 2>&1; then
  echo "Installiere uv (Python-Paketmanager)…"
  curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v uv >/dev/null 2>&1 || { echo "uv konnte nicht installiert werden"; exit 1; }

mkdir -p "$SUPPORT"

# Build from a writable copy – the app bundle may be read-only.
SRC_COPY="$SUPPORT/engine-src"
rm -rf "$SRC_COPY"
cp -R "$ENGINE_SRC" "$SRC_COPY"

if [[ ! -x "$SUPPORT/.venv/bin/python" ]]; then
  echo "Lege Python-Umgebung an…"
  uv venv --python 3.12 "$SUPPORT/.venv"
fi

echo "Installiere Whisper und MLX…"
uv pip install --python "$SUPPORT/.venv/bin/python" --reinstall-package flow-engine "$SRC_COPY"

echo "$VERSION" > "$SUPPORT/engine.version"
echo "== Fertig"
