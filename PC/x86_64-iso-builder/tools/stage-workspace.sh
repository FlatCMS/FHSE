#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORKSPACE_DIR="$ROOT_DIR/PC/x86_64-iso-builder/workspace"
BUNDLE_SCRIPT="$ROOT_DIR/PC/x86_64-iso-builder/tools/prepare-fhse-core-bundle.sh"
RENDER_SCRIPT="$ROOT_DIR/PC/x86_64-iso-builder/tools/render-autoinstall-user-data.sh"
CONFIG_PATH="${1:-$ROOT_DIR/PC/x86_64-iso-builder/examples/fhse-pc.env.example}"

mkdir -p "$WORKSPACE_DIR"

"$BUNDLE_SCRIPT"

cp "$ROOT_DIR/PC/x86_64-iso-builder/autoinstall/meta-data" "$WORKSPACE_DIR/meta-data"
cp "$ROOT_DIR/PC/x86_64-iso-builder/autoinstall/user-data.template" "$WORKSPACE_DIR/user-data.template"
"$RENDER_SCRIPT" "$CONFIG_PATH" "$WORKSPACE_DIR/user-data"

echo "PC workspace staged:"
echo "  $WORKSPACE_DIR"
