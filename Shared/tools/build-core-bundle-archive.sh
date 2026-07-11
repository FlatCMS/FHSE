#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORE_DIR="$ROOT_DIR/Shared/core-bundle-source/flatcms-home-server-bundle-v0.18.2"
DEFAULT_PAYLOAD="$ROOT_DIR/Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/packages/flatcms.zip"
DEFAULT_OUTPUT="$ROOT_DIR/Raspberry/rpi4-appliance-builder/system-boot/fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip"

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

if ! command -v zip >/dev/null 2>&1; then
  echo "The 'zip' command is required." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

STAGE_DIR="$TMP_DIR/flatcms-home-server-bundle-v0.18.2"
mkdir -p "$TMP_DIR"

rsync -a --exclude '.DS_Store' "$CORE_DIR/" "$STAGE_DIR/"
cp -p "$PAYLOAD_PATH" "$STAGE_DIR/packages/flatcms.zip"
touch -r "$CORE_DIR/packages" "$STAGE_DIR/packages"

mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"

(
  cd "$TMP_DIR"
  LC_ALL=C find "flatcms-home-server-bundle-v0.18.2" -print | sort | zip -Xq "$OUTPUT_PATH" -@
)

echo "Built bundle archive:"
echo "  $OUTPUT_PATH"
echo "Using payload:"
echo "  $PAYLOAD_PATH"
