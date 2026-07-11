#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

HOSTNAME_VALUE="$(hostname -f 2>/dev/null || hostname)"
LOCAL_IP="$(detect_local_ipv4)"
DOMAIN="${FLATCMS_DOMAIN:-}"
DOMAIN="$(printf '%s' "$DOMAIN" | sed 's#^https\?://##;s#/*$##')"

write_report_value "FHS_HOSTNAME" "$HOSTNAME_VALUE"
write_report_value "FHS_LOCAL_IP" "$LOCAL_IP"
if [ -n "$DOMAIN" ]; then
  write_report_value "FLATCMS_PUBLIC_URL" "https://${DOMAIN}/"
  write_report_value "FLATCMS_DOMAIN" "$DOMAIN"
fi
write_report_value "FHS_COMPLETED_AT" "$(date -Is)"

log "Report written to $FHS_REPORT_PATH"
