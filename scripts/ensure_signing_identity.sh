#!/bin/bash
# Creates/reuses a stable local codesigning identity so TCC (Mic, Accessibility)
# survives app rebuilds. Prints the identity HASH on stdout (preferred by codesign).
set -euo pipefail

NAME="Flow Local Code Signing"
SUPPORT="${HOME}/Library/Application Support/Flow"
CERT_DIR="$SUPPORT/signing"
P12="$CERT_DIR/flow-signing.p12"
CRT="$CERT_DIR/flow-signing.crt"
KEY="$CERT_DIR/flow-signing.key"
HASH_FILE="$CERT_DIR/identity.hash"
PASS_FILE="$CERT_DIR/password"
LOG="$SUPPORT/signing-setup.log"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

mkdir -p "$CERT_DIR"
if [[ -n "${FLOW_SIGNING_PASSWORD:-}" ]]; then
  PASS="$FLOW_SIGNING_PASSWORD"
elif [[ -f "$PASS_FILE" ]]; then
  PASS="$(tr -d '[:space:]' < "$PASS_FILE")"
else
  echo "ERROR: PKCS#12-Passwort fehlt. Lege es in $PASS_FILE ab oder setze FLOW_SIGNING_PASSWORD. Das Passwort gehört nicht ins Repository." >&2
  exit 1
fi
if [[ -z "$PASS" ]]; then
  echo "ERROR: PKCS#12-Passwort ist leer." >&2
  exit 1
fi
exec 3>>"$LOG"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&3; }

hash_for_name() {
  security find-identity -v -p codesigning 2>/dev/null \
    | grep -F "$NAME" \
    | head -1 \
    | awk '{print $2}'
}

count_identities() {
  security find-identity -v -p codesigning 2>/dev/null | grep -cF "$NAME" || true
}

# Reuse cached hash if it still resolves
if [[ -f "$HASH_FILE" ]]; then
  CACHED="$(tr -d '[:space:]' < "$HASH_FILE")"
  if [[ -n "$CACHED" ]] && security find-identity -v -p codesigning 2>/dev/null | grep -q "$CACHED"; then
    log "Using cached identity hash $CACHED"
    echo "$CACHED"
    exit 0
  fi
fi

EXISTING="$(hash_for_name || true)"
if [[ -n "${EXISTING:-}" ]] && [[ "$(count_identities)" -eq 1 ]]; then
  echo "$EXISTING" > "$HASH_FILE"
  log "Identity already available: $EXISTING"
  echo "$EXISTING"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ ! -f "$P12" ]]; then
  log "Generating new signing certificate"
  cat > "$TMP/cert.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = Flow Local Code Signing
O = Flow
C = DE
[v3]
basicConstraints = CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
EOF

  openssl req -new -newkey rsa:2048 -nodes \
    -keyout "$KEY" -out "$TMP/flow.csr" -config "$TMP/cert.cnf" >/dev/null 2>&1
  openssl x509 -req -in "$TMP/flow.csr" -signkey "$KEY" \
    -out "$CRT" -days 3650 -extfile "$TMP/cert.cnf" -extensions v3 >/dev/null 2>&1
  openssl pkcs12 -export -inkey "$KEY" -in "$CRT" -out "$P12" \
    -passout "pass:$PASS" -name "$NAME" >/dev/null 2>&1
  chmod 600 "$KEY" "$P12"
  log "Created $P12"
elif [[ ! -f "$CRT" ]]; then
  openssl pkcs12 -in "$P12" -passin "pass:$PASS" -clcerts -nokeys -out "$CRT" 2>/dev/null || true
fi

# Remove every copy of this identity (by hash) to avoid "ambiguous"
while true; do
  H="$(hash_for_name || true)"
  [[ -z "${H:-}" ]] && break
  log "Removing existing identity $H"
  security delete-identity -Z "$H" "$KEYCHAIN" >/dev/null 2>&1 || break
done

log "Importing identity into login keychain"
security unlock-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
security import "$P12" \
  -k "$KEYCHAIN" \
  -P "$PASS" \
  -A \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null 2>&1 || true

security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "" \
  -D "$NAME" \
  "$KEYCHAIN" >/dev/null 2>&1 || true

if [[ -f "$CRT" ]]; then
  log "Trusting certificate for codeSign"
  security add-trusted-cert \
    -d -r trustRoot -p codeSign -k "$KEYCHAIN" "$CRT" >/dev/null 2>&1 || \
  security add-trusted-cert \
    -d -r trustAsRoot -p codeSign -k "$KEYCHAIN" "$CRT" >/dev/null 2>&1 || \
  log "add-trusted-cert failed – in Keychain Access set Trust → Code Signing = Always Trust for '$NAME'"
fi

HASH="$(hash_for_name || true)"
if [[ -n "${HASH:-}" ]]; then
  echo "$HASH" > "$HASH_FILE"
  log "OK: $NAME ($HASH)"
  echo "$HASH"
  exit 0
fi

log "FAIL: identity not usable after import/trust"
echo "ERROR: Konnte Codesign-Identität nicht einrichten. Siehe $LOG" >&2
exit 1
