#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONFIG_PATH="${1:-$ROOT_DIR/VM/appliance-builder/examples/fhse-vm-arm64.env.example}"
TEMPLATE_PATH="$ROOT_DIR/VM/appliance-builder/autoinstall/user-data.template"
OUTPUT_PATH="${2:-$ROOT_DIR/VM/appliance-builder/workspace/user-data}"

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

PASSWORD_HASH="$(openssl passwd -6 "$FHSE_OS_PASSWORD")"

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

echo "Rendered VM autoinstall user-data:"
echo "  $OUTPUT_PATH"
