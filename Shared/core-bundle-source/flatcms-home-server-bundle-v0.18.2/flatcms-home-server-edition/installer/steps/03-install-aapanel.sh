#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

AAPANEL_CREDENTIALS_FILE="$FHS_LOG_DIR/aapanel-credentials.env"
AAPANEL_INSTALL_CAPTURE="$FHS_LOG_DIR/aapanel-install-output.log"
AAPANEL_SSL_FLAG="/www/server/panel/data/ssl.pl"
AAPANEL_INIT_SCRIPT="/etc/init.d/bt"

normalize_local_aapanel_url() {
  local raw_url="$1"
  local local_ipv4
  local path_part
  local_ipv4="$(hostname -I | awk '{for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+\./) {print $i; exit}}')"
  if [ -z "$raw_url" ] || [ -z "$local_ipv4" ]; then
    printf '%s' "$raw_url"
    return 0
  fi
  path_part="$(printf '%s' "$raw_url" | sed -E 's#^https?://(\[[^]]+\]|[^/:]+)(:[0-9]+)?(/.*)?$#\2\3#')"
  printf 'http://%s%s' "$local_ipv4" "$path_part"
}

disable_aapanel_panel_ssl() {
  log "Disabling aaPanel panel SSL for trusted local FHSE access."

  rm -f "$AAPANEL_SSL_FLAG" 2>/dev/null || true

  if [ -x "$AAPANEL_INIT_SCRIPT" ]; then
    "$AAPANEL_INIT_SCRIPT" restart >/dev/null 2>&1 || true
  elif command -v service >/dev/null 2>&1; then
    service bt restart >/dev/null 2>&1 || true
  fi

  write_report_value "AAPANEL_PANEL_SSL" "disabled"
}

parse_aapanel_info_from_text() {
  local source_file="$1"
  local url username password
  [ -f "$source_file" ] || return 0

  url="$(awk '/https?:\/\// {print $NF}' "$source_file" | grep -E '^https?://' | tail -1 || true)"
  username="$(awk -F: 'tolower($1) ~ /username|user/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); if ($2 != "") print $2}' "$source_file" | tail -1 || true)"
  password="$(awk -F: 'tolower($1) ~ /password/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); if ($2 != "") print $2}' "$source_file" | tail -1 || true)"

  [ -n "$url" ] && url="$(normalize_local_aapanel_url "$url")"

  if [ -n "$url" ] || [ -n "$username" ] || [ -n "$password" ]; then
    {
      printf 'AAPANEL_URL=%q\n' "$url"
      printf 'AAPANEL_USERNAME=%q\n' "$username"
      printf 'AAPANEL_PASSWORD=%q\n' "$password"
    } > "$AAPANEL_CREDENTIALS_FILE"
    chmod 600 "$AAPANEL_CREDENTIALS_FILE"
    chown root:root "$AAPANEL_CREDENTIALS_FILE" 2>/dev/null || true
  fi
}

refresh_aapanel_credentials_nonblocking() {
  local bt_output="$FHS_LOG_DIR/aapanel-bt14-output.log"

  # Important v0.21 change:
  # credentials retrieval must never block the whole installer.
  # aaPanel can be ready in the browser while `bt 14` is temporarily slow or interactive.
  if command -v timeout >/dev/null 2>&1 && command -v bt >/dev/null 2>&1; then
    timeout 8s bt 14 > "$bt_output" 2>/dev/null || true
    parse_aapanel_info_from_text "$bt_output"
  elif command -v bt >/dev/null 2>&1; then
    bt 14 > "$bt_output" 2>/dev/null || true
    parse_aapanel_info_from_text "$bt_output"
  fi

  if [ ! -s "$AAPANEL_CREDENTIALS_FILE" ]; then
    parse_aapanel_info_from_text "$AAPANEL_INSTALL_CAPTURE"
  fi

  if [ -s "$AAPANEL_CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    source "$AAPANEL_CREDENTIALS_FILE" || true
    AAPANEL_PORT="$(printf '%s' "${AAPANEL_URL:-}" | sed -nE 's#^https?://(\[[^]]+\]|[^/:]+):([0-9]+).*#\2#p')"
    if [ -n "$AAPANEL_PORT" ] && command -v ufw >/dev/null 2>&1; then
      log "Allowing aaPanel port in UFW: ${AAPANEL_PORT}/tcp"
      ufw allow "${AAPANEL_PORT}/tcp" 2>/dev/null || true
      write_report_value "AAPANEL_PORT" "$AAPANEL_PORT"
    fi
    [ -n "${AAPANEL_URL:-}" ] && write_report_value "AAPANEL_URL" "$AAPANEL_URL"
    write_report_value "AAPANEL_CREDENTIALS_FILE" "$AAPANEL_CREDENTIALS_FILE"
  else
    log "aaPanel credentials were not available yet; continuing without blocking. They will be refreshed by the wizard later."
  fi
}

wait_for_aapanel_core() {
  local attempts="${FHS_AAPANEL_READY_ATTEMPTS:-60}"
  local install_soft="/www/server/panel/install/install_soft.sh"

  for _ in $(seq 1 "$attempts"); do
    if command -v bt >/dev/null 2>&1 && [ -f "$install_soft" ] && [ -d /www/server/panel ]; then
      log "aaPanel core is ready."
      return 0
    fi
    sleep 3
  done

  fail "aaPanel core was not ready after installation. Missing bt command or $install_soft."
}

if [ "${FLATCMS_INSTALL_AAPANEL:-1}" != "1" ]; then
  log "aaPanel installation disabled by configuration."
  write_report_value "AAPANEL_STATUS" "skipped"
  exit 0
fi

if command -v bt >/dev/null 2>&1; then
  log "aaPanel appears to be already installed."
else
  log "Installing aaPanel using the official installer script."
  cd /root
  URL="https://www.aapanel.com/script/install_panel_en.sh"
  if command -v curl >/dev/null 2>&1; then
    curl -ksSO "$URL"
  else
    wget --no-check-certificate -O install_panel_en.sh "$URL"
  fi
  if command -v ufw >/dev/null 2>&1; then
    log "Pre-allowing SSH in UFW before aaPanel changes firewall policy."
    ufw allow OpenSSH 2>/dev/null || ufw allow 22/tcp 2>/dev/null || true
  fi

  : > "$AAPANEL_INSTALL_CAPTURE"
  set +e
  set +o pipefail
  yes y | bash install_panel_en.sh forum 2>&1 | tee "$AAPANEL_INSTALL_CAPTURE"
  statuses=("${PIPESTATUS[@]}")
  set -o pipefail
  set -e
  installer_status="${statuses[1]:-1}"
  if [ "$installer_status" -ne 0 ]; then
    fail "aaPanel official installer failed with exit code: $installer_status"
  fi
fi

wait_for_aapanel_core
disable_aapanel_panel_ssl

# Mark aaPanel installed BEFORE credential lookup so the stack step can continue even if bt output is slow.
write_report_value "AAPANEL_STATUS" "installed"

refresh_aapanel_credentials_nonblocking
