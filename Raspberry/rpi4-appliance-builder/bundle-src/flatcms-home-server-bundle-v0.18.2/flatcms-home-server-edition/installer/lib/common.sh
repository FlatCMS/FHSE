#!/usr/bin/env bash
set -Eeuo pipefail

FHS_LOG_DIR="${FHS_LOG_DIR:-/var/log/flatcms-home-server}"
FHS_REPORT_PATH="${FHS_REPORT_PATH:-$FHS_LOG_DIR/report.env}"

mkdir -p "$FHS_LOG_DIR"

# Return the first IPv4 address detected on the host.
# Avoid `hostname -I | awk '{print $1}'` because IPv6 or bridge interfaces
# can appear before the LAN IPv4 address on Raspberry Pi / VM systems.
detect_local_ipv4() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+\./) {print $i; exit}}')"
  if [ -z "$ip" ] && command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')"
  fi
  printf '%s' "$ip"
}


log() {
  printf '[%s] %s\n' "$(date -Is)" "$*" | tee -a "$FHS_LOG_DIR/install.log"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fail "This installer must run as root."
  fi
}

write_report_value() {
  local key="$1"
  local value="$2"
  mkdir -p "$(dirname "$FHS_REPORT_PATH")"
  if [ -f "$FHS_REPORT_PATH" ]; then
    grep -v "^${key}=" "$FHS_REPORT_PATH" > "${FHS_REPORT_PATH}.tmp" || true
    mv "${FHS_REPORT_PATH}.tmp" "$FHS_REPORT_PATH"
  fi
  printf '%s=%q\n' "$key" "$value" >> "$FHS_REPORT_PATH"
}

load_config() {
  local config_file="${1:-}"
  if [ -n "$config_file" ] && [ -f "$config_file" ]; then
    # shellcheck disable=SC1090
    source "$config_file"
  fi
}

run_step() {
  local script="$1"
  log "Starting step: $script"
  bash "$script"
  log "Finished step: $script"
}

