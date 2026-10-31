#!/usr/bin/env bash
# Sign the release manifest with the offline update key.
#
#   scripts/sign_update_manifest.sh dist/manifest.json ~/.keys/fancad-update.pem
#
# Writes manifest.json.sig as base64 text, which is what the updater expects.
# The private key never belongs in this repository or in CI.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <manifest.json> <private-key.pem>" >&2
  exit 2
fi

manifest="$1"
key="$2"
if [[ ! -f "$manifest" ]]; then
  echo "error: $manifest not found" >&2
  exit 1
fi
if [[ ! -f "$key" ]]; then
  echo "error: $key not found" >&2
  exit 1
fi

raw="$(mktemp)"
public="$(mktemp)"
cleanup() { rm -f "$raw" "$public"; }
trap cleanup EXIT

if [[ -n "${FANCAD_UPDATE_KEY_PASSPHRASE:-}" ]]; then
  openssl dgst -sha256 -sign "$key" \
    -passin env:FANCAD_UPDATE_KEY_PASSPHRASE \
    -out "$raw" "$manifest"
  openssl rsa -in "$key" \
    -passin env:FANCAD_UPDATE_KEY_PASSPHRASE \
    -pubout -out "$public" 2>/dev/null
else
  openssl dgst -sha256 -sign "$key" -out "$raw" "$manifest"
  openssl rsa -in "$key" -pubout -out "$public" 2>/dev/null
fi

base64 < "$raw" | tr -d '\n' > "$manifest.sig"

# Prove the signature before uploading it.
openssl dgst -sha256 -verify "$public" -signature "$raw" "$manifest"

echo "wrote $manifest.sig"
