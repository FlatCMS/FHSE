#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONFIG_PATH="${1:-$ROOT_DIR/PC/x86_64-iso-builder/examples/fhse-pc.env.example}"
TEMPLATE_PATH="$ROOT_DIR/PC/x86_64-iso-builder/autoinstall/user-data.template"
OUTPUT_PATH="${2:-$ROOT_DIR/PC/x86_64-iso-builder/workspace/user-data}"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Missing config file: $CONFIG_PATH" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$CONFIG_PATH"
set +a

: "${FHSE_OS_HOSTNAME:?Missing FHSE_OS_HOSTNAME}"
: "${FHSE_OS_USERNAME:?Missing FHSE_OS_USERNAME}"
: "${FHSE_OS_PASSWORD:?Missing FHSE_OS_PASSWORD}"

resolve_sha512_openssl() {
  local candidate=""
  local candidates=()

  if [ -n "${FHSE_OPENSSL_BIN:-}" ]; then
    candidates+=("$FHSE_OPENSSL_BIN")
  fi
  candidates+=(
    "/opt/homebrew/opt/openssl@3/bin/openssl"
    "/opt/homebrew/opt/openssl/bin/openssl"
    "/opt/homebrew/bin/openssl"
  )
  if command -v openssl >/dev/null 2>&1; then
    candidates+=("$(command -v openssl)")
  fi

  for candidate in "${candidates[@]}"; do
    [ -x "$candidate" ] || continue
    if printf 'flatcms-probe\n' | "$candidate" passwd -6 -stdin >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "No OpenSSL binary with SHA-512 password support was found." >&2
  echo "Install OpenSSL 3 or set FHSE_OPENSSL_BIN explicitly." >&2
  return 1
}

OPENSSL_BIN="$(resolve_sha512_openssl)"
PASSWORD_HASH="$(printf '%s\n' "$FHSE_OS_PASSWORD" | "$OPENSSL_BIN" passwd -6 -stdin)"
if [[ "$PASSWORD_HASH" != \$6\$* ]]; then
  echo "Failed to generate a SHA-512 password hash." >&2
  exit 1
fi

python3 - "$TEMPLATE_PATH" "$OUTPUT_PATH" "$FHSE_OS_HOSTNAME" "$FHSE_OS_USERNAME" "$PASSWORD_HASH" <<'PY'
from pathlib import Path
import sys

template = Path(sys.argv[1]).read_text()
output = Path(sys.argv[2])
hostname = sys.argv[3]
username = sys.argv[4]
password_hash = sys.argv[5]

rendered = (
    template
    .replace("__FHSE_HOSTNAME__", hostname)
    .replace("__FHSE_USERNAME__", username)
    .replace("__FHSE_PASSWORD_HASH__", password_hash)
)

output.write_text(rendered)
PY

echo "Rendered PC autoinstall user-data:"
echo "  $OUTPUT_PATH"

