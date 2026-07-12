#!/usr/bin/env bash
set -Eeuo pipefail

LOG_DIR="/var/log/flatcms-home-server"
LOG_FILE="$LOG_DIR/rpi-firstboot.log"
INSTALL_ROOT="/opt/flatcms-home-server"
BUNDLE_NAME="flatcms-home-server-bundle-v0.18.2-no-builders.zip"
BUNDLE_SRC="/boot/firmware/fhse/$BUNDLE_NAME"
BUNDLE_DIR="$INSTALL_ROOT/flatcms-home-server-bundle-v0.18.2"
SERVICE_FILE="/etc/systemd/system/fhse-wizard.service"
PORT="8080"
HOSTNAME_TARGET="fhse"

mkdir -p "$LOG_DIR" "$INSTALL_ROOT"
touch "$LOG_FILE"
chmod 0644 "$LOG_FILE"

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*" | tee -a "$LOG_FILE"
}

install_pkg_if_missing() {
  local bin="$1"
  local pkg="$2"
  if ! command -v "$bin" >/dev/null 2>&1; then
    log "Installing missing package: $pkg"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y || true
    apt-get install -y "$pkg" || true
  fi
}

log "FHSE Raspberry Pi first boot bootstrap started."
log "Target local name: ${HOSTNAME_TARGET}.local"
log "Package: $BUNDLE_NAME"

log "Ensuring hostname"
hostnamectl set-hostname "$HOSTNAME_TARGET" || true
printf '127.0.1.1\t%s\n' "$HOSTNAME_TARGET" > /etc/hosts.fhse.tmp
if grep -q '^127\.0\.1\.1' /etc/hosts; then
  sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${HOSTNAME_TARGET}/" /etc/hosts || true
else
  cat /etc/hosts.fhse.tmp >> /etc/hosts || true
fi
rm -f /etc/hosts.fhse.tmp

log "Ensuring technical access account"
id admin >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,adm admin
passwd -l admin >/dev/null 2>&1 || usermod -L admin >/dev/null 2>&1 || true
usermod -aG sudo,adm admin || true
printf 'admin ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-fhse-admin
chmod 0440 /etc/sudoers.d/90-fhse-admin

log "Ensuring SSH service for emergency support"
install_pkg_if_missing sshd openssh-server
ssh-keygen -A || true
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-fhse-password-auth.conf <<'SSHCFG'
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PermitRootLogin no
SSHCFG
systemctl unmask ssh >/dev/null 2>&1 || true
systemctl enable ssh >/dev/null 2>&1 || true
systemctl restart ssh >/dev/null 2>&1 || systemctl start ssh >/dev/null 2>&1 || true

log "Ensuring mDNS / Avahi for fhse.local"
install_pkg_if_missing avahi-daemon avahi-daemon
if command -v avahi-daemon >/dev/null 2>&1; then
  systemctl enable avahi-daemon >/dev/null 2>&1 || true
  systemctl restart avahi-daemon >/dev/null 2>&1 || systemctl start avahi-daemon >/dev/null 2>&1 || true
fi

if [ ! -f "$BUNDLE_SRC" ]; then
  log "ERROR: bundle not found at $BUNDLE_SRC"
  log "The wizard service will not be installed. Check the image system-boot/fhse directory."
  exit 1
fi

if [ ! -d "$BUNDLE_DIR" ]; then
  log "Extracting FHSE bundle into $INSTALL_ROOT"
  python3 - <<PY
import zipfile
from pathlib import Path
bundle = Path("$BUNDLE_SRC")
target = Path("$INSTALL_ROOT")
with zipfile.ZipFile(bundle) as zf:
    zf.extractall(target)
PY
else
  log "FHSE bundle already extracted at $BUNDLE_DIR"
fi

if [ ! -f "$BUNDLE_DIR/start-wizard-preview.sh" ]; then
  log "ERROR: wizard launcher not found at $BUNDLE_DIR/start-wizard-preview.sh"
  find "$INSTALL_ROOT" -maxdepth 4 -type f -name 'start-wizard-preview.sh' -print | tee -a "$LOG_FILE" || true
  exit 1
fi

chmod +x "$BUNDLE_DIR/start-wizard-preview.sh" || true
find "$BUNDLE_DIR/flatcms-home-server-edition/installer" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=FlatCMS Home Server Edition Wizard
Documentation=file:$BUNDLE_DIR/flatcms-home-server-edition/README.md
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BUNDLE_DIR
Environment=FLATCMS_WIZARD_HOST=0.0.0.0
Environment=FLATCMS_WIZARD_PORT=$PORT
ExecStart=/bin/bash $BUNDLE_DIR/start-wizard-preview.sh
Restart=always
RestartSec=5
StandardOutput=append:/var/log/flatcms-home-server/fhse-wizard.log
StandardError=append:/var/log/flatcms-home-server/fhse-wizard.log

[Install]
WantedBy=multi-user.target
SERVICE

chmod 0644 "$SERVICE_FILE"
systemctl daemon-reload

if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp >/dev/null 2>&1 || true
  ufw allow "$PORT/tcp" >/dev/null 2>&1 || true
fi

log "Starting FHSE wizard service"
systemctl enable fhse-wizard.service >/dev/null 2>&1 || true
systemctl restart fhse-wizard.service >/dev/null 2>&1 || systemctl start fhse-wizard.service >/dev/null 2>&1 || true

LOCAL_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)"
[ -n "$LOCAL_IP" ] || LOCAL_IP="$(hostname -I 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+\./) {print $i; exit}}')"

mkdir -p /etc/issue.d
cat > /etc/issue.d/fhse.issue <<ISSUE

FlatCMS Home Server Edition v0.18.2-rpi4.1 RC3.12 — Raspberry Pi / no legacy builders
Wizard local: http://fhse.local:$PORT
Wizard IP: http://${LOCAL_IP:-IP_DU_RASPBERRY}:$PORT
Emergency SSH: configure in wizard

ISSUE

log "Listening ports after bootstrap:"
ss -tlnp | tee -a "$LOG_FILE" || true
log "FHSE wizard service status:"
systemctl --no-pager --full status fhse-wizard.service | tee -a "$LOG_FILE" || true
log "FHSE wizard service installed and started."
log "Open local: http://fhse.local:$PORT"
log "Open IP: http://${LOCAL_IP:-IP_DU_RASPBERRY}:$PORT"
log "Bootstrap completed."
