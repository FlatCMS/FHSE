#!/usr/bin/env bash
set -Eeuo pipefail

BOOT_MOUNT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY="$ROOT_DIR/system-boot"

if [ -z "$BOOT_MOUNT" ]; then
  echo "Usage: $0 /Volumes/system-boot"
  exit 1
fi

if [ ! -d "$BOOT_MOUNT" ]; then
  echo "ERROR: boot mount not found: $BOOT_MOUNT"
  exit 1
fi

if [ ! -d "$OVERLAY/fhse" ] || [ ! -f "$OVERLAY/user-data" ] || [ ! -f "$OVERLAY/meta-data" ] || [ ! -f "$OVERLAY/network-config" ]; then
  echo "ERROR: invalid overlay directory: $OVERLAY"
  exit 1
fi

mkdir -p "$BOOT_MOUNT/fhse"
rsync -a --delete "$OVERLAY/fhse/" "$BOOT_MOUNT/fhse/"
cp "$OVERLAY/user-data" "$BOOT_MOUNT/user-data"
cp "$OVERLAY/meta-data" "$BOOT_MOUNT/meta-data"
cp "$OVERLAY/network-config" "$BOOT_MOUNT/network-config"

# Keep the local NoCloud seed on the Raspberry Pi boot partition for the legacy Mac overlay flow.
# Without this, some images boot and get DHCP but never apply user-data, which leaves SSH and the wizard disabled.
if [ -f "$BOOT_MOUNT/cmdline.txt" ]; then
  if ! grep -q 'ds=nocloud;s=/boot/firmware/' "$BOOT_MOUNT/cmdline.txt"; then
    printf 'Patching cmdline.txt with local NoCloud datasource...\n'
    perl -0pi -e 's/\s+$//' "$BOOT_MOUNT/cmdline.txt"
    printf ' ds=nocloud;s=/boot/firmware/' >> "$BOOT_MOUNT/cmdline.txt"
  fi
else
  echo "ERROR: cmdline.txt not found on boot partition: $BOOT_MOUNT"
  exit 1
fi

find "$BOOT_MOUNT" -name "._*" -delete 2>/dev/null || true
sync

echo "FHSE overlay installed on $BOOT_MOUNT"
echo "You can now eject the SD card cleanly."
