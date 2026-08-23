#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$KIT_DIR/dist"
BOOT_OVERLAY="$KIT_DIR/system-boot"
VERSION="v0.18.2-rpi4.1-rc3.13"
IMAGE_NAME="fhse-rpi4-${VERSION}.img"
IMAGE_PATH="$DIST_DIR/$IMAGE_NAME"
IMAGE_XZ_PATH="$IMAGE_PATH.xz"
BASE_URL="https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz"
BASE_XZ="$DIST_DIR/ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz"
MNT_ROOT=""
MNT_BOOT=""
LOOP_DEV=""

need_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "ERROR: this builder must run on Linux with sudo/root." >&2
    echo "Run: sudo $0 --download" >&2
    exit 1
  fi
}

cleanup() {
  set +e
  sync
  if [ -n "$MNT_BOOT" ] && mountpoint -q "$MNT_BOOT"; then umount "$MNT_BOOT"; fi
  if [ -n "$MNT_ROOT" ] && mountpoint -q "$MNT_ROOT"; then umount "$MNT_ROOT"; fi
  if [ -n "$LOOP_DEV" ]; then losetup -d "$LOOP_DEV" >/dev/null 2>&1 || true; fi
  [ -n "$MNT_BOOT" ] && rmdir "$MNT_BOOT" >/dev/null 2>&1 || true
  [ -n "$MNT_ROOT" ] && rmdir "$MNT_ROOT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

need_root
mkdir -p "$DIST_DIR"

if [ "${1:-}" = "--download" ] || [ ! -f "$BASE_XZ" ]; then
  echo "Downloading official Ubuntu Raspberry Pi Server image..."
  curl -L --fail --progress-bar "$BASE_URL" -o "$BASE_XZ"
fi

bash "$SCRIPT_DIR/validate-no-builders.sh"

rm -f "$IMAGE_PATH" "$IMAGE_XZ_PATH"
echo "Decompressing base image to: $IMAGE_PATH"
xz -dc "$BASE_XZ" > "$IMAGE_PATH"

sync
LOOP_DEV="$(losetup --find --partscan --show "$IMAGE_PATH")"
echo "Loop device: $LOOP_DEV"

# Recent Ubuntu kernels can register the loop device before exposing its
# partition nodes. Refresh the partition table and wait for udev before mount.
partprobe "$LOOP_DEV" || true
partx -u "$LOOP_DEV" || true
udevadm settle || true
for _ in {1..20}; do
  if [ -b "${LOOP_DEV}p1" ] && [ -b "${LOOP_DEV}p2" ]; then
    break
  fi
  sleep 0.25
done
if [ ! -b "${LOOP_DEV}p1" ] || [ ! -b "${LOOP_DEV}p2" ]; then
  echo "ERROR: image partitions were not exposed for $LOOP_DEV." >&2
  lsblk "$LOOP_DEV" >&2 || true
  exit 1
fi

MNT_BOOT="$(mktemp -d)"
MNT_ROOT="$(mktemp -d)"
mount "${LOOP_DEV}p1" "$MNT_BOOT"
mount "${LOOP_DEV}p2" "$MNT_ROOT"

echo "Installing FHSE boot payload..."
rsync -rLt --no-owner --no-group --no-perms --exclude='.DS_Store' --exclude='._*' "$BOOT_OVERLAY/" "$MNT_BOOT/"

# Keep cloud-init files as optional fallback, but RC3 does not depend on them.
if ! grep -q 'ds=nocloud;s=/boot/firmware/' "$MNT_BOOT/cmdline.txt"; then
  sed -i 's|$| ds=nocloud;s=/boot/firmware/|' "$MNT_BOOT/cmdline.txt"
fi

echo "Patching root filesystem directly: systemd appliance mode"
install -d -m 0755 "$MNT_ROOT/usr/local/sbin" "$MNT_ROOT/etc/systemd/system" "$MNT_ROOT/etc/systemd/system/multi-user.target.wants" "$MNT_ROOT/var/log/flatcms-home-server" "$MNT_ROOT/etc/issue.d" "$MNT_ROOT/etc/ssh/sshd_config.d" "$MNT_ROOT/opt/flatcms-home-server"

echo "Creating technical access account in locked state"
# Ensure admin group/user exist before first boot. UID/GID 1999 avoids common default-user collisions.
grep -q '^admin:' "$MNT_ROOT/etc/group" || echo 'admin:x:1999:' >> "$MNT_ROOT/etc/group"
grep -q '^admin:' "$MNT_ROOT/etc/passwd" || echo 'admin:x:1999:1999:FlatCMS Home Server Edition Admin:/home/admin:/bin/bash' >> "$MNT_ROOT/etc/passwd"
if grep -q '^admin:' "$MNT_ROOT/etc/shadow"; then
  sed -i "s|^admin:[^:]*:|admin:!:|" "$MNT_ROOT/etc/shadow"
else
  echo "admin:!:19700:0:99999:7:::" >> "$MNT_ROOT/etc/shadow"
fi
grep -q '^admin:' "$MNT_ROOT/etc/gshadow" || echo 'admin:!::' >> "$MNT_ROOT/etc/gshadow"
for g in sudo adm; do
  if grep -q "^${g}:" "$MNT_ROOT/etc/group"; then
    sed -i "/^${g}:/ { /admin/! s/$/,admin/; s/:,/:/; }" "$MNT_ROOT/etc/group"
  fi
done
install -d -m 0755 "$MNT_ROOT/home/admin"
chown 1999:1999 "$MNT_ROOT/home/admin" || true
echo 'admin ALL=(ALL) NOPASSWD:ALL' > "$MNT_ROOT/etc/sudoers.d/90-fhse-admin"
chmod 0440 "$MNT_ROOT/etc/sudoers.d/90-fhse-admin"

echo "Disabling SSH password authentication until the wizard configures it"
cat > "$MNT_ROOT/etc/ssh/sshd_config.d/99-fhse-password-auth.conf" <<'SSHCFG'
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PermitRootLogin no
SSHCFG
ln -sf /lib/systemd/system/ssh.service "$MNT_ROOT/etc/systemd/system/multi-user.target.wants/ssh.service" 2>/dev/null || true

echo "Extracting FHSE bundle into rootfs for direct wizard service"
python3 - <<PYROOT
import zipfile
from pathlib import Path
bundle = Path(r"$BOOT_OVERLAY/fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip")
target = Path(r"$MNT_ROOT/opt/flatcms-home-server")
target.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(bundle) as zf:
    zf.extractall(target)
PYROOT
chmod +x "$MNT_ROOT/opt/flatcms-home-server/flatcms-home-server-bundle-v0.18.2/start-wizard-preview.sh" || true

cat > "$MNT_ROOT/etc/systemd/system/fhse-wizard.service" <<'WIZARDSERVICE'
[Unit]
Description=FlatCMS Home Server Edition Wizard
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
WIZARDSERVICE
ln -sf /etc/systemd/system/fhse-wizard.service "$MNT_ROOT/etc/systemd/system/multi-user.target.wants/fhse-wizard.service"


cat > "$MNT_ROOT/usr/local/sbin/fhse-rootfs-firstboot.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
LOG_DIR="/var/log/flatcms-home-server"
LOG_FILE="$LOG_DIR/rootfs-firstboot.log"
mkdir -p "$LOG_DIR"
exec >> "$LOG_FILE" 2>&1

echo "[FHSE] rootfs firstboot started: $(date -Is)"

hostnamectl set-hostname fhse || echo fhse > /etc/hostname
if grep -q '^127\.0\.1\.1' /etc/hosts; then
  sed -i 's/^127\.0\.1\.1.*/127.0.1.1\tfhse/' /etc/hosts || true
else
  printf '127.0.1.1\tfhse\n' >> /etc/hosts
fi

# Technical access account, created here instead of relying on cloud-init.
if ! id admin >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo,adm admin || true
fi
passwd -l admin >/dev/null 2>&1 || usermod -L admin >/dev/null 2>&1 || true
usermod -aG sudo,adm admin || true
echo 'admin ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-fhse-admin
chmod 0440 /etc/sudoers.d/90-fhse-admin

ssh-keygen -A || true
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-fhse-password-auth.conf <<'SSHCFG'
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PermitRootLogin no
SSHCFG
systemctl unmask ssh || true
systemctl enable ssh || true
systemctl restart ssh || systemctl start ssh || true

export DEBIAN_FRONTEND=noninteractive
if ! command -v avahi-daemon >/dev/null 2>&1; then
  apt-get update -y || true
  apt-get install -y avahi-daemon || true
fi
systemctl enable avahi-daemon || true
systemctl restart avahi-daemon || systemctl start avahi-daemon || true

if [ -x /boot/firmware/fhse/fhse-firstboot.sh ]; then
  /bin/bash /boot/firmware/fhse/fhse-firstboot.sh || true
else
  echo "[FHSE] ERROR: /boot/firmware/fhse/fhse-firstboot.sh not found"
fi

cat > /etc/issue.d/fhse.issue <<ISSUE

FlatCMS Home Server Edition
Open: http://fhse.local:8080
Fallback: http://IP_DU_RASPBERRY:8080
Emergency SSH: configure in wizard

ISSUE

systemctl disable fhse-rootfs-firstboot.service || true
echo "[FHSE] rootfs firstboot finished: $(date -Is)"
SCRIPT
chmod 0755 "$MNT_ROOT/usr/local/sbin/fhse-rootfs-firstboot.sh"

cat > "$MNT_ROOT/etc/systemd/system/fhse-rootfs-firstboot.service" <<'SERVICE'
[Unit]
Description=FlatCMS Home Server Edition rootfs first boot bootstrap
Wants=network-online.target
After=local-fs.target network-online.target
ConditionPathExists=/boot/firmware/fhse/fhse-firstboot.sh

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/fhse-rootfs-firstboot.sh
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE

ln -sf /etc/systemd/system/fhse-rootfs-firstboot.service "$MNT_ROOT/etc/systemd/system/multi-user.target.wants/fhse-rootfs-firstboot.service"

# Pre-seed hostname visibly in rootfs too.
echo 'fhse' > "$MNT_ROOT/etc/hostname"
if grep -q '^127\.0\.1\.1' "$MNT_ROOT/etc/hosts"; then
  sed -i 's/^127\.0\.1\.1.*/127.0.1.1\tfhse/' "$MNT_ROOT/etc/hosts" || true
else
  printf '127.0.1.1\tfhse\n' >> "$MNT_ROOT/etc/hosts"
fi

echo "Validating appliance files..."
test -f "$MNT_BOOT/fhse/fhse-firstboot.sh"
test -f "$MNT_ROOT/etc/systemd/system/fhse-rootfs-firstboot.service"
test -L "$MNT_ROOT/etc/systemd/system/multi-user.target.wants/fhse-rootfs-firstboot.service"
test -f "$MNT_ROOT/etc/systemd/system/fhse-wizard.service"
test -L "$MNT_ROOT/etc/systemd/system/multi-user.target.wants/fhse-wizard.service"
test -f "$MNT_ROOT/etc/ssh/sshd_config.d/99-fhse-password-auth.conf"
grep -q '^admin:' "$MNT_ROOT/etc/passwd"
grep -q '^admin:' "$MNT_ROOT/etc/shadow"
ADMIN_SHADOW_LINE="$(grep '^admin:' "$MNT_ROOT/etc/shadow")"
case "$ADMIN_SHADOW_LINE" in
  'admin:!:'*) ;;
  *)
    echo "ERROR: admin technical account is not locked as expected in /etc/shadow." >&2
    echo "Found: $ADMIN_SHADOW_LINE" >&2
    exit 1
    ;;
esac
grep -q 'PasswordAuthentication no' "$MNT_ROOT/etc/ssh/sshd_config.d/99-fhse-password-auth.conf"
grep -q 'ExecStart=/bin/bash /opt/flatcms-home-server/flatcms-home-server-bundle-v0.18.2/start-wizard-preview.sh' "$MNT_ROOT/etc/systemd/system/fhse-wizard.service"
test -x "$MNT_ROOT/opt/flatcms-home-server/flatcms-home-server-bundle-v0.18.2/start-wizard-preview.sh"
test -f "$MNT_ROOT/opt/flatcms-home-server/flatcms-home-server-bundle-v0.18.2/wizard-preview/server.py"
grep -q 'fhse' "$MNT_ROOT/etc/hostname"

echo "Unmounting and compressing..."
cleanup
trap - EXIT
xz -T0 -9 -k "$IMAGE_PATH"

cd "$DIST_DIR"
sha256sum "$IMAGE_NAME" "$IMAGE_NAME.xz" > "$IMAGE_NAME.sha256"
cat "$IMAGE_NAME.sha256"

echo
printf 'Done. Flash with Raspberry Pi Imager:\n  %s\n\n' "$IMAGE_PATH"
printf 'Compressed release candidate:\n  %s\n' "$IMAGE_XZ_PATH"
