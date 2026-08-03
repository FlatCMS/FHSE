#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORE_DIR="$ROOT_DIR/Shared/core-bundle-source/flatcms-home-server-bundle-v0.18.2"
DEFAULT_PAYLOAD="$ROOT_DIR/Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/packages/flatcms.zip"
DEFAULT_OUTPUT="$ROOT_DIR/Raspberry/rpi4-appliance-builder/system-boot/fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-946684800}"

PAYLOAD_PATH="${1:-$DEFAULT_PAYLOAD}"
OUTPUT_PATH="${2:-$DEFAULT_OUTPUT}"

if [ ! -d "$CORE_DIR" ]; then
  echo "Missing shared core source: $CORE_DIR" >&2
  exit 1
fi

if [ ! -f "$PAYLOAD_PATH" ]; then
  echo "Missing FlatCMS payload: $PAYLOAD_PATH" >&2
  exit 1
fi

for command_name in zip rsync python3; do
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

STAGE_DIR="$TMP_DIR/flatcms-home-server-bundle-v0.18.2"
mkdir -p "$TMP_DIR"

rsync -a --exclude '.DS_Store' "$CORE_DIR/" "$STAGE_DIR/"
cp "$PAYLOAD_PATH" "$STAGE_DIR/packages/flatcms.zip"

python3 - "$STAGE_DIR" "$SOURCE_DATE_EPOCH" <<'PYTIME'
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
epoch = int(sys.argv[2])
for path in sorted(root.rglob('*'), key=lambda item: len(item.parts), reverse=True):
    os.utime(path, (epoch, epoch), follow_symlinks=False)
os.utime(root, (epoch, epoch), follow_symlinks=False)
PYTIME

mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"

(
  cd "$TMP_DIR"
  TZ=UTC LC_ALL=C find "flatcms-home-server-bundle-v0.18.2" -print \
    | LC_ALL=C sort \
    | TZ=UTC zip -Xq "$OUTPUT_PATH" -@
)

echo "Built bundle archive:"
echo "  $OUTPUT_PATH"
echo "Using payload:"
echo "  $PAYLOAD_PATH"
