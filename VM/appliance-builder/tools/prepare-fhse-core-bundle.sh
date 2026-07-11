#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PAYLOAD_PATH="${1:-$ROOT_DIR/Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/packages/flatcms.zip}"
OUTPUT_PATH="$ROOT_DIR/VM/appliance-builder/assets/flatcms-home-server-bundle-v0.18.2-no-builders.zip"

"$ROOT_DIR/Shared/tools/build-core-bundle-archive.sh" "$PAYLOAD_PATH" "$OUTPUT_PATH"

echo "VM target bundle prepared:"
echo "  $OUTPUT_PATH"

