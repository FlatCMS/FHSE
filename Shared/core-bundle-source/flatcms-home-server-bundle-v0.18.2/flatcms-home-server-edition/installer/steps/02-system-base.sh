#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

export DEBIAN_FRONTEND=noninteractive

log "Updating package index and installing base packages."
apt-get update
apt-get install -y ca-certificates curl wget gnupg lsb-release openssh-server ufw unzip jq avahi-daemon libc-ares-dev

systemctl enable --now ssh
systemctl enable --now avahi-daemon

if command -v ufw >/dev/null 2>&1; then
  ufw allow OpenSSH || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
fi

write_report_value "FHS_BASE_PACKAGES" "installed"
write_report_value "FHS_PHP_DEPENDENCIES" "libc-ares-dev"

