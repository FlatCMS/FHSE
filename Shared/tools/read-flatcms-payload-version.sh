#!/usr/bin/env bash
set -Eeuo pipefail

PAYLOAD="${1:-}"
if [[ -z "$PAYLOAD" || ! -f "$PAYLOAD" ]]; then
  echo "ERROR: FlatCMS payload missing: ${PAYLOAD:-<empty>}" >&2
  exit 2
fi

python3 - "$PAYLOAD" <<'PY'
import json
import re
import sys
import zipfile

payload = sys.argv[1]
with zipfile.ZipFile(payload) as archive:
    version = archive.read("VERSION").decode("utf-8", "replace").strip()
    manifest = json.loads(archive.read("flatcms.json"))
    manifest_version = str(manifest.get("version", "")).strip()

if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:[.-][0-9A-Za-z.-]+)?", version):
    raise SystemExit(f"Invalid FlatCMS VERSION in payload: {version!r}")
if manifest_version != version:
    raise SystemExit(
        f"FlatCMS payload version mismatch: VERSION={version!r}, flatcms.json={manifest_version!r}"
    )

print(version)
PY
