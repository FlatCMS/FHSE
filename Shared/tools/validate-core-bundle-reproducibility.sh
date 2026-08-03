#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PAYLOAD_PATH="${1:-$ROOT_DIR/Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/packages/flatcms.zip}"
BUILD_SCRIPT="$ROOT_DIR/Shared/tools/build-core-bundle-archive.sh"

if [ ! -f "$PAYLOAD_PATH" ]; then
  echo "Missing FlatCMS payload: $PAYLOAD_PATH" >&2
  exit 1
fi

for command_name in cmp cp python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "The '$command_name' command is required." >&2
    exit 1
  fi
done

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cp "$PAYLOAD_PATH" "$TMP_DIR/payload-old.zip"
cp "$PAYLOAD_PATH" "$TMP_DIR/payload-new.zip"
python3 - "$TMP_DIR/payload-old.zip" "$TMP_DIR/payload-new.zip" <<'PY'
import os
from pathlib import Path
import sys

os.utime(Path(sys.argv[1]), (946684800, 946684800))
os.utime(Path(sys.argv[2]), (1785801540, 1785801540))
PY

"$BUILD_SCRIPT" "$TMP_DIR/payload-old.zip" "$TMP_DIR/bundle-old.zip" >/dev/null
"$BUILD_SCRIPT" "$TMP_DIR/payload-new.zip" "$TMP_DIR/bundle-new.zip" >/dev/null
cmp "$TMP_DIR/bundle-old.zip" "$TMP_DIR/bundle-new.zip"

echo "OK: FHSE core bundle is byte-for-byte reproducible."
