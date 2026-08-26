#!/usr/bin/env bash
set -Eeuo pipefail

PAYLOAD="${1:-}"
if [[ -z "$PAYLOAD" || ! -f "$PAYLOAD" ]]; then
  echo "ERROR: FlatCMS payload missing: ${PAYLOAD:-<empty>}" >&2
  exit 2
fi

EXPECTED_CORE="${2:-}"

python3 - "$PAYLOAD" "$EXPECTED_CORE" <<'PY'
import json, sys, zipfile
from pathlib import PurePosixPath

payload = sys.argv[1]
expected_core = sys.argv[2].strip()
expected_modules = {
    "Modules": "1.0.3",
    "Backups": "1.0.2",
    "Languages": "1.0.1",
    "UpdateManager": "0.4.7",
}
forbidden_prefixes = (
    "app/Modules/Store/",
    "app/Modules/Downloads/",
    "app/Modules/PagesBuilder/",
    "app/Modules/MenuBuilder/",
    "app/Modules/FooterBuilder/",
    "app/Plugins/",
    "app/Extensions/",
    "public/modules/",
    "public/assets/plugins/",
    "public/assets/extensions/",
    "resources/Store/",
)
allowed_manifest_keys = {
    "name", "version", "description", "type", "author", "required", "enabled",
    "sidebar_visible", "dependencies", "vendor", "official", "origin", "signature",
}
errors = []
with zipfile.ZipFile(payload) as zf:
    names = set(zf.namelist())
    if "VERSION" not in names:
        errors.append("VERSION missing")
        core_version = ""
    else:
        core_version = zf.read("VERSION").decode("utf-8", "replace").strip()
        if expected_core and core_version != expected_core:
            errors.append(f"Core VERSION={core_version!r}, expected {expected_core!r}")

    try:
        flatcms = json.loads(zf.read("flatcms.json"))
    except Exception as exc:
        flatcms = {}
        errors.append(f"flatcms.json invalid or missing: {exc}")
    manifest_version = str(flatcms.get("version", "")).strip()
    if manifest_version != core_version:
        errors.append(f"flatcms.json version={manifest_version!r}, VERSION={core_version!r}")
    if expected_core and manifest_version != expected_core:
        errors.append(f"flatcms.json version={manifest_version!r}, expected {expected_core!r}")

    for module, expected in expected_modules.items():
        path = f"app/Modules/{module}/module.json"
        try:
            manifest = json.loads(zf.read(path))
        except Exception as exc:
            errors.append(f"{path} invalid or missing: {exc}")
            continue
        version = str(manifest.get("version", "")).strip()
        if version != expected:
            errors.append(f"{module} version={version!r}, expected {expected!r}")
        extras = sorted(set(manifest) - allowed_manifest_keys)
        if extras:
            errors.append(f"{module} manifest has non-conventional keys: {', '.join(extras)}")
        if not manifest.get("required"):
            errors.append(f"{module} must be required=true")
        if not str(manifest.get("signature", "")).strip():
            errors.append(f"{module} signature missing")

    for prefix in forbidden_prefixes:
        count = sum(1 for name in names if name.startswith(prefix))
        if count:
            errors.append(f"forbidden payload prefix {prefix} ({count} entries)")

    try:
        state = json.loads(zf.read("data/modules.json"))
    except Exception as exc:
        state = {}
        errors.append(f"data/modules.json invalid or missing: {exc}")
    for forbidden in ("Store", "Downloads", "PostScheduler", "StoreCarrierSandbox", "StorePaymentSandbox"):
        if forbidden in state:
            errors.append(f"forbidden module state entry: {forbidden}")

if errors:
    print("FlatCMS FHSE payload validation FAILED:", file=sys.stderr)
    for error in errors:
        print(f" - {error}", file=sys.stderr)
    raise SystemExit(1)
print(f"FlatCMS FHSE payload validation OK: Core {core_version}, Modules 1.0.3, Backups 1.0.2, Languages 1.0.1, UpdateManager 0.4.7")
PY
