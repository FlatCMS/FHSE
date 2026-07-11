#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ACCESS_MODE="${FLATCMS_ACCESS_MODE:-local_only}"
TOKEN="${FLATCMS_CLOUDFLARE_TUNNEL_TOKEN:-}"
TOKEN="$(printf '%s' "$TOKEN" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

install_cloudflared() {
  log "Installing cloudflared from official Cloudflare APT repository."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl gnupg

  install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
    | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

  echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' \
    > /etc/apt/sources.list.d/cloudflared.list

  apt-get update
  apt-get install -y cloudflared
}

if [ "$ACCESS_MODE" != "cloudflare_tunnel" ]; then
  log "Cloudflare Tunnel not enabled. Local access mode selected."
  write_report_value "CLOUDFLARE_TUNNEL_STATUS" "skipped"
  write_report_value "CHECK_CLOUDFLARED" "skipped"
  exit 0
fi

if [ -z "$TOKEN" ]; then
  log "Cloudflare Tunnel token is mandatory but missing."
  write_report_value "CLOUDFLARE_TUNNEL_STATUS" "missing-token"
  write_report_value "CHECK_CLOUDFLARED" "missing-token"
  exit 1
fi

install_cloudflared

log "Cloudflare Tunnel token detected. Installing service."
set +e
systemctl stop cloudflared >/dev/null 2>&1
cloudflared service uninstall >/dev/null 2>&1
rm -f /etc/systemd/system/cloudflared.service
systemctl daemon-reload >/dev/null 2>&1
cloudflared service install "$TOKEN" >/tmp/fhse-cloudflared-install.log 2>&1
install_status=$?
set -e

if [ "$install_status" -ne 0 ]; then
  log "Cloudflare Tunnel service installation failed. See /tmp/fhse-cloudflared-install.log"
  write_report_value "CLOUDFLARE_TUNNEL_STATUS" "error"
  write_report_value "CHECK_CLOUDFLARED" "failed"
  exit 1
fi

systemctl enable --now cloudflared >/dev/null 2>&1 || true
sleep 5

if systemctl is-active --quiet cloudflared; then
  log "Cloudflare Tunnel service is active."
  write_report_value "CLOUDFLARE_TUNNEL_STATUS" "active"
  write_report_value "CHECK_CLOUDFLARED" "ok"
else
  log "Cloudflare Tunnel service is installed but not active."
  write_report_value "CLOUDFLARE_TUNNEL_STATUS" "error"
  write_report_value "CHECK_CLOUDFLARED" "failed"
  exit 1
fi
