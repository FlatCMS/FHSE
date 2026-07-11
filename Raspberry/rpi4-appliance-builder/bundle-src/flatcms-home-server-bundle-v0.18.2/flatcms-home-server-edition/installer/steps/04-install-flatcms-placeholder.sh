#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Compatibility wrapper kept for older direct flows.
# Do not move, backup or rename /www/wwwroot/default.
# The validated step-by-step flow uses 04a + 04b directly.
bash "$SCRIPT_DIR/steps/04a-create-aapanel-site.sh"
bash "$SCRIPT_DIR/steps/04b-install-flatcms.sh"
