#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONFIG_PATH="${1:-$ROOT_DIR/VM/appliance-builder/examples/fhse-vm-x86_64.env.example}"
TEMPLATE_PATH="$ROOT_DIR/VM/appliance-builder/cloud-init/user-data.template"
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

python3 - "$TEMPLATE_PATH" "$OUTPUT_PATH" "$FHSE_OS_HOSTNAME" "$FHSE_OS_USERNAME" <<'PY'
from pathlib import Path
import sys

template = Path(sys.argv[1]).read_text()
output = Path(sys.argv[2])
hostname = sys.argv[3]
username = sys.argv[4]

rendered = (
    template
    .replace("__FHSE_HOSTNAME__", hostname)
    .replace("__FHSE_USERNAME__", username)
)

output.write_text(rendered)
PY

echo "Rendered VM cloud-init user-data:"
echo "  $OUTPUT_PATH"

