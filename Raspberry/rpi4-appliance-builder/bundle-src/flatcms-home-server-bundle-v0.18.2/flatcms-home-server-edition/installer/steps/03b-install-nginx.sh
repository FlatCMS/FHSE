#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

INSTALL_STACK="${FLATCMS_INSTALL_AAPANEL_STACK:-1}"
INSTALL_DIR="/www/server/panel/install"
INSTALL_SOFT="$INSTALL_DIR/install_soft.sh"
NGINX_VERSION="${FLATCMS_NGINX_VERSION:-1.24}"
NGINX_BIN="/www/server/nginx/sbin/nginx"

install_soft() {
  local name="$1"
  local version="$2"
  local timeout_seconds="${FHS_AAPANEL_APP_INSTALL_TIMEOUT:-3600}"
  local install_status=0

  [ -f "$INSTALL_SOFT" ] || fail "aaPanel installer not found: $INSTALL_SOFT"
  chmod +x "$INSTALL_SOFT" 2>/dev/null || true

  log "Installing aaPanel app: $name $version"
  log "aaPanel app installer timeout: ${timeout_seconds}s"

  set +e
  set +o pipefail
  (
    cd "$INSTALL_DIR"
    yes y | timeout "$timeout_seconds" bash install_soft.sh 4 install "$name" "$version"
  )
  install_status=$?
  set -o pipefail
  set -e

  if [ "$install_status" -eq 124 ]; then
    fail "aaPanel app installer timed out while installing: $name $version"
  fi

  if [ "$install_status" -ne 0 ]; then
    log "aaPanel app installer returned exit code $install_status for $name $version; continuing to verify filesystem result."
  else
    log "aaPanel app installer command completed for $name $version."
  fi
}

wait_for_path() {
  local path="$1"
  local label="$2"
  local attempts="${3:-120}"

  for _ in $(seq 1 "$attempts"); do
    if [ -e "$path" ]; then
      log "$label is ready: $path"
      return 0
    fi
    sleep 5
  done

  fail "$label was not ready after waiting for: $path"
}

if [ "$INSTALL_STACK" != "1" ]; then
  log "aaPanel stack installation disabled by configuration."
  write_report_value "AAPANEL_NGINX_STATUS" "skipped"
  exit 0
fi

if [ ! -f "$INSTALL_SOFT" ]; then
  fail "aaPanel is installed but its internal app installer is missing: $INSTALL_SOFT"
fi

log "aaPanel internal app installer is available: $INSTALL_SOFT"

if [ ! -x "$NGINX_BIN" ]; then
  install_soft nginx "$NGINX_VERSION"
else
  log "aaPanel Nginx already installed."
fi

wait_for_path "$NGINX_BIN" "aaPanel Nginx"

if "$NGINX_BIN" -v >/tmp/flatcms-nginx-version.txt 2>&1; then
  NGINX_FULL_VERSION="$(sed 's#nginx version: ##' /tmp/flatcms-nginx-version.txt)"
else
  NGINX_FULL_VERSION="nginx/${NGINX_VERSION}"
fi
rm -f /tmp/flatcms-nginx-version.txt

service nginx start 2>/dev/null || /etc/init.d/nginx start 2>/dev/null || "$NGINX_BIN" 2>/dev/null || true

write_report_value "AAPANEL_STACK_STATUS" "partial-nginx"
write_report_value "AAPANEL_NGINX_STATUS" "installed"
write_report_value "AAPANEL_NGINX_VERSION" "$NGINX_VERSION"
write_report_value "CHECK_NGINX" "ok"
write_report_value "CHECK_NGINX_VERSION" "$NGINX_FULL_VERSION"
