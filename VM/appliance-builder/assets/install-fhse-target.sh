#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_HOSTNAME="${1:-fhse}"
INSTALL_ROOT="/opt/flatcms-home-server"
INSTALL_CACHE_DIR="/var/lib/flatcms-home-server/install"
LOG_DIR="/var/log/flatcms-home-server"
BUNDLE_NAME="flatcms-home-server-bundle-v0.18.2-no-builders.zip"
BUNDLE_ZIP="$INSTALL_CACHE_DIR/$BUNDLE_NAME"
BUNDLE_DIR="$INSTALL_ROOT/flatcms-home-server-bundle-v0.18.2"
SERVICE_FILE="/etc/systemd/system/fhse-wizard.service"
SSH_CONFIG_FILE="/etc/ssh/sshd_config.d/99-fhse-password-auth.conf"

mkdir -p "$INSTALL_ROOT" "$INSTALL_CACHE_DIR" "$LOG_DIR" /etc/issue.d /etc/ssh/sshd_config.d /etc/systemd/system/multi-user.target.wants

if [ ! -f "$BUNDLE_ZIP" ]; then
  echo "Missing FHSE bundle on target: $BUNDLE_ZIP" >&2
  exit 1
fi

hostnamectl set-hostname "$TARGET_HOSTNAME" >/dev/null 2>&1 || echo "$TARGET_HOSTNAME" > /etc/hostname
if grep -q '^127\.0\.1\.1' /etc/hosts; then
  sed -i "s/^127\\.0\\.1\\.1.*/127.0.1.1\t${TARGET_HOSTNAME}/" /etc/hosts || true
else
  printf '127.0.1.1\t%s\n' "$TARGET_HOSTNAME" >> /etc/hosts
fi

if ! id admin >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo,adm admin
fi
usermod -aG sudo,adm admin >/dev/null 2>&1 || true
passwd -l admin >/dev/null 2>&1 || usermod -L admin >/dev/null 2>&1 || true
printf 'admin ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-fhse-admin
chmod 0440 /etc/sudoers.d/90-fhse-admin

cat > "$SSH_CONFIG_FILE" <<'SSHCFG'
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PermitRootLogin no
SSHCFG

python3 - <<'PY'
from pathlib import Path
import shutil
import zipfile

install_root = Path("/opt/flatcms-home-server")
bundle_dir = install_root / "flatcms-home-server-bundle-v0.18.2"
bundle_zip = Path("/var/lib/flatcms-home-server/install/flatcms-home-server-bundle-v0.18.2-no-builders.zip")

if bundle_dir.exists():
    shutil.rmtree(bundle_dir)

with zipfile.ZipFile(bundle_zip) as zf:
    zf.extractall(install_root)
PY

chmod +x "$BUNDLE_DIR/start-wizard-preview.sh" || true
find "$BUNDLE_DIR/flatcms-home-server-edition/installer" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

cat > "$SERVICE_FILE" <<'SERVICE'
[Unit]
Description=FlatCMS Home Server Edition Wizard
Documentation=file:/opt/flatcms-home-server/flatcms-home-server-bundle-v0.18.2/flatcms-home-server-edition/README.md
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/flatcms-home-server/flatcms-home-server-bundle-v0.18.2
Environment=FLATCMS_WIZARD_HOST=0.0.0.0
Environment=FLATCMS_WIZARD_PORT=8080
ExecStart=/bin/bash /opt/flatcms-home-server/flatcms-home-server-bundle-v0.18.2/start-wizard-preview.sh
Restart=always
RestartSec=5
StandardOutput=append:/var/log/flatcms-home-server/fhse-wizard.log
StandardError=append:/var/log/flatcms-home-server/fhse-wizard.log

[Install]
WantedBy=multi-user.target
SERVICE

chmod 0644 "$SERVICE_FILE"
ln -sf /etc/systemd/system/fhse-wizard.service /etc/systemd/system/multi-user.target.wants/fhse-wizard.service

if [ -f /lib/systemd/system/ssh.service ]; then
  ln -sf /lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service
fi

if [ -f /lib/systemd/system/avahi-daemon.service ]; then
  ln -sf /lib/systemd/system/avahi-daemon.service /etc/systemd/system/multi-user.target.wants/avahi-daemon.service
fi

cat > /etc/issue.d/fhse.issue <<EOF

FlatCMS Home Server Edition
Open: http://${TARGET_HOSTNAME}.local:8080
Fallback: http://IP_DE_LA_VM:8080
Emergency SSH: configure in wizard

EOF
