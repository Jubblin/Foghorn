#!/usr/bin/env bash
# Import a PKCS#12 signing certificate into a temporary CI keychain.
# Requires: CERTIFICATE_P12 (base64), P12_PASSWORD
# Safe to source more than once in the same job (reuses the keychain).
set -euo pipefail

if [[ -z "${CERTIFICATE_P12:-}" ]]; then
  echo "CERTIFICATE_P12 not set; skipping keychain setup"
  exit 0
fi

: "${P12_PASSWORD:?P12_PASSWORD is required when CERTIFICATE_P12 is set}"

KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/app-signing.keychain-db"
CERT_PATH="${RUNNER_TEMP:-/tmp}/signing-cert.p12"

if [[ -z "${KEYCHAIN_PASSWORD:-}" ]]; then
  KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"
  export KEYCHAIN_PASSWORD
fi

echo "$CERTIFICATE_P12" | base64 --decode > "$CERT_PATH"

if [[ -f "$KEYCHAIN_PATH" ]]; then
  echo "Reusing existing signing keychain: $KEYCHAIN_PATH"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
else
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
  security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
  security import "$CERT_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
fi

security list-keychain -d user -s "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "KEYCHAIN_PATH=$KEYCHAIN_PATH"
    echo "KEYCHAIN_PASSWORD=$KEYCHAIN_PASSWORD"
  } >> "$GITHUB_ENV"
fi
