#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/Shared/tools/sync-core-to-raspberry.sh"
"$ROOT_DIR/Shared/tools/build-core-bundle-archive.sh"

echo "Raspberry embedded bundle refreshed from Shared core."

