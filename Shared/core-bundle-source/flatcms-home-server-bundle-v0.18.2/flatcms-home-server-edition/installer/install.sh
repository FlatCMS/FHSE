#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-}"

require_root

set -a
load_config "$CONFIG_FILE"

PROFILE="${FLATCMS_PROFILE:-mini-pc}"
PROFILE_FILE="$SCRIPT_DIR/profiles/${PROFILE}.profile"

[ -f "$PROFILE_FILE" ] || fail "Unknown profile: $PROFILE"

# shellcheck disable=SC1090
source "$PROFILE_FILE"
set +a

if [ "${FHS_RESET_LOGS_ON_START:-1}" = "1" ]; then
  mkdir -p "$FHS_LOG_DIR"
  : > "$FHS_LOG_DIR/install.log"
  : > "$FHS_REPORT_PATH"
fi

log "FlatCMS Home Server Edition installer"
log "Profile: $PROFILE"
write_report_value "FLATCMS_PROFILE" "$PROFILE"

run_step "$SCRIPT_DIR/steps/01-preflight.sh"
run_step "$SCRIPT_DIR/steps/02-system-base.sh"
run_step "$SCRIPT_DIR/steps/03-install-aapanel.sh"
run_step "$SCRIPT_DIR/steps/03b-install-nginx.sh"
run_step "$SCRIPT_DIR/steps/03c-install-php.sh"
run_step "$SCRIPT_DIR/steps/04a-create-aapanel-site.sh"
run_step "$SCRIPT_DIR/steps/04b-install-flatcms.sh"
run_step "$SCRIPT_DIR/steps/06-final-report.sh"

run_step "$SCRIPT_DIR/healthchecks/final-healthcheck.sh"

log "Installation flow completed."
