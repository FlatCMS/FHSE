#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORKSPACE_DIR="$ROOT_DIR/VM/appliance-builder/workspace"
BUNDLE_SCRIPT="$ROOT_DIR/VM/appliance-builder/tools/prepare-fhse-core-bundle.sh"

mkdir -p "$WORKSPACE_DIR"

"$BUNDLE_SCRIPT"

cp "$ROOT_DIR/VM/appliance-builder/cloud-init/meta-data" "$WORKSPACE_DIR/meta-data"
cp "$ROOT_DIR/VM/appliance-builder/cloud-init/user-data.template" "$WORKSPACE_DIR/user-data.template"

echo "VM workspace staged:"
echo "  $WORKSPACE_DIR"

