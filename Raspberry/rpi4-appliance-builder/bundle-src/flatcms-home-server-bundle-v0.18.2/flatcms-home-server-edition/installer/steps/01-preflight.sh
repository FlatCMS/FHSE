#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ARCH="$(uname -m)"
OS_ID="$(. /etc/os-release && printf '%s' "$ID")"
OS_VERSION="$(. /etc/os-release && printf '%s' "$VERSION_ID")"
RAM_MB="$(awk '/MemTotal/ { printf "%d", $2 / 1024 }' /proc/meminfo)"

log "Detected OS: $OS_ID $OS_VERSION"
log "Detected architecture: $ARCH"
log "Detected RAM: ${RAM_MB} MB"

if [ "${FHS_EXPECTED_ARCH:-any}" != "any" ] && [ "$ARCH" != "$FHS_EXPECTED_ARCH" ]; then
  fail "Profile expects $FHS_EXPECTED_ARCH but detected $ARCH."
fi

if [ "$OS_ID" != "ubuntu" ]; then
  fail "This MVP installer expects Ubuntu. Detected: $OS_ID."
fi

case "$OS_VERSION" in
  22.04|22.04.*|24.04|24.04.*)
    log "Ubuntu version accepted for MVP: $OS_VERSION"
    ;;
  *)
    fail "Unsupported Ubuntu version for MVP: $OS_VERSION"
    ;;
esac

if [ "$RAM_MB" -lt "${FHS_MIN_RAM_MB:-512}" ]; then
  fail "Not enough RAM. Minimum: ${FHS_MIN_RAM_MB} MB."
fi

if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
  fail "Network check failed. Cannot reach 1.1.1.1."
fi

write_report_value "FHS_ARCH" "$ARCH"
write_report_value "FHS_OS" "$OS_ID $OS_VERSION"
write_report_value "FHS_RAM_MB" "$RAM_MB"

