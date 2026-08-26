#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_PAYLOAD="${1:-}"
EXPECTED_VERSION="${2:-}"
TARGET_PAYLOAD="$ROOT_DIR/Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/packages/flatcms.zip"
TARGET_CHECKSUM="${TARGET_PAYLOAD}.sha256"

if [[ -z "$SOURCE_PAYLOAD" || ! -f "$SOURCE_PAYLOAD" ]]; then
  echo "ERROR: source FlatCMS archive missing: ${SOURCE_PAYLOAD:-<empty>}" >&2
  exit 2
fi

PAYLOAD_VERSION="$("$ROOT_DIR/Shared/tools/read-flatcms-payload-version.sh" "$SOURCE_PAYLOAD")"
if [[ -n "$EXPECTED_VERSION" && "$PAYLOAD_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "ERROR: FlatCMS payload version is $PAYLOAD_VERSION, expected $EXPECTED_VERSION." >&2
  exit 1
fi

"$ROOT_DIR/Shared/tools/validate-flatcms-payload.sh" "$SOURCE_PAYLOAD" "$PAYLOAD_VERSION"

mkdir -p "$(dirname "$TARGET_PAYLOAD")"
TEMP_PAYLOAD="${TARGET_PAYLOAD}.tmp"
cp "$SOURCE_PAYLOAD" "$TEMP_PAYLOAD"
mv "$TEMP_PAYLOAD" "$TARGET_PAYLOAD"

python3 - "$TARGET_PAYLOAD" "$TARGET_CHECKSUM" <<'PY'
import hashlib
from pathlib import Path
import sys

payload = Path(sys.argv[1])
checksum = Path(sys.argv[2])
digest = hashlib.sha256(payload.read_bytes()).hexdigest()
checksum.write_text(f"{digest}  {payload.name}\n", encoding="utf-8")
PY

"$ROOT_DIR/Shared/tools/build-core-bundle-archive.sh"
"$ROOT_DIR/Raspberry/rpi4-appliance-builder/tools/validate-no-builders.sh" "$PAYLOAD_VERSION"
"$ROOT_DIR/Shared/tools/validate-core-bundle-reproducibility.sh" "$TARGET_PAYLOAD"
"$ROOT_DIR/VM/appliance-builder/tools/prepare-fhse-core-bundle.sh" "$TARGET_PAYLOAD"

echo "FlatCMS release payload staged for FHSE:"
echo "  version: $PAYLOAD_VERSION"
echo "  payload: $TARGET_PAYLOAD"
echo "  checksum: $TARGET_CHECKSUM"
