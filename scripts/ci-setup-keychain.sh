#!/usr/bin/env bash
# Import a PKCS#12 signing certificate into a temporary CI keychain.
# Requires: CERTIFICATE_P12 (base64), P12_PASSWORD
# Can run more than once per job (e.g. once per arch) only if the caller exports
# the same KEYCHAIN_PASSWORD to every run; release.yml does (#172).
set -euo pipefail

if [[ -z "${CERTIFICATE_P12:-}" ]]; then
  echo "CERTIFICATE_P12 not set; skipping keychain setup"
  exit 0
fi

: "${P12_PASSWORD:?P12_PASSWORD is required when CERTIFICATE_P12 is set}"

KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/app-signing.keychain-db"
CERT_PATH="${RUNNER_TEMP:-/tmp}/signing-cert.p12"

if [[ -z "${KEYCHAIN_PASSWORD:-}" ]]; then
  if [[ -f "$KEYCHAIN_PATH" ]]; then
    echo "error: $KEYCHAIN_PATH already exists but KEYCHAIN_PASSWORD wasn't inherited;" \
      "export one password for every run in this job (#172)" >&2
    exit 1
  fi
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

# Same-job reuse relies on exported KEYCHAIN_PASSWORD in this shell.
# Only persist the path for later steps (do not write the password to GITHUB_ENV).
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "KEYCHAIN_PATH=$KEYCHAIN_PATH" >> "$GITHUB_ENV"
fi
