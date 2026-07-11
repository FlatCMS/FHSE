#!/usr/bin/env bash
set -Eeuo pipefail

OFFICIAL_URL="https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BASE_INPUT="${1:-}"
OUT_NAME="${2:-fhse-rpi4-v0.18.2-rpi4.1-rc3.11.img}"
OUT_IMG="$DIST_DIR/$OUT_NAME"
OUT_XZ="$OUT_IMG.xz"

usage() {
  cat <<USAGE
Usage:
  $0 /path/to/ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz [output.img]
  $0 --download [output.img]

Recommended first validation with Raspberry Pi Imager:
  Use the uncompressed .img generated in dist/.

Examples:
  $0 ~/Downloads/ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz
  $0 --download fhse-rpi4-v0.18.2-rpi4.1-rc3.11.img
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1"; exit 1; }
}

if [ -z "$BASE_INPUT" ] || [ "$BASE_INPUT" = "-h" ] || [ "$BASE_INPUT" = "--help" ]; then
  usage
  exit 0
fi

require_cmd hdiutil
require_cmd diskutil
require_cmd xz
require_cmd rsync
require_cmd shasum
require_cmd awk
require_cmd grep
require_cmd sed

mkdir -p "$DIST_DIR"

BASE_XZ="$BASE_INPUT"
if [ "$BASE_INPUT" = "--download" ]; then
  require_cmd curl
  BASE_XZ="$DIST_DIR/ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz"
  if [ ! -f "$BASE_XZ" ]; then
    echo "Downloading official Ubuntu Raspberry Pi Server image..."
    curl -L --fail --progress-bar "$OFFICIAL_URL" -o "$BASE_XZ"
  else
    echo "Official Ubuntu image already present: $BASE_XZ"
  fi
fi

if [ ! -f "$BASE_XZ" ]; then
  echo "ERROR: base image not found: $BASE_XZ"
  exit 1
fi

if ! xz -t "$BASE_XZ"; then
  echo "ERROR: base image XZ integrity check failed: $BASE_XZ"
  exit 1
fi

rm -f "$OUT_IMG" "$OUT_XZ"

"$SCRIPT_DIR/validate-no-builders.sh"

echo "Decompressing base image to: $OUT_IMG"
xz -dc "$BASE_XZ" > "$OUT_IMG"

DISK_DEV=""
BOOT_DEV=""
BOOT_MOUNT=""

cleanup() {
  set +e
  if [ -n "$BOOT_MOUNT" ]; then
    diskutil unmount "$BOOT_MOUNT" >/dev/null 2>&1 || true
  fi
  if [ -n "$DISK_DEV" ]; then
    hdiutil detach "$DISK_DEV" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

attach_image() {
  local image="$1"
  ATTACH_OUTPUT="$(hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage "$image")"
  echo "$ATTACH_OUTPUT"
  DISK_DEV="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/FDisk_partition_scheme|GUID_partition_scheme/ {print $1; exit}')"
  BOOT_DEV="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Windows_FAT|DOS_FAT|FAT32|Microsoft Basic Data/ {print $1; exit}')"
  if [ -z "$DISK_DEV" ] || [ -z "$BOOT_DEV" ]; then
    echo "ERROR: unable to detect image boot partition."
    exit 1
  fi
}

mount_boot() {
  echo "Mounting boot partition: $BOOT_DEV"
  diskutil mount "$BOOT_DEV" >/dev/null
  BOOT_MOUNT="$(diskutil info "$BOOT_DEV" | awk -F': *' '/Mount Point/ {print $2; exit}')"
  if [ -z "$BOOT_MOUNT" ] || [ ! -d "$BOOT_MOUNT" ]; then
    echo "ERROR: unable to find boot mount point."
    exit 1
  fi
}

unmount_image() {
  if [ -n "$BOOT_MOUNT" ]; then
    diskutil unmount "$BOOT_MOUNT" >/dev/null
    BOOT_MOUNT=""
  fi
  if [ -n "$DISK_DEV" ]; then
    hdiutil detach "$DISK_DEV" >/dev/null
    DISK_DEV=""
  fi
  sync
}

echo "Attaching image for overlay installation..."
attach_image "$OUT_IMG"
mount_boot

echo "Installing FHSE overlay into image boot partition: $BOOT_MOUNT"
"$SCRIPT_DIR/mac-install-overlay.sh" "$BOOT_MOUNT"

# Verify while mounted.
test -f "$BOOT_MOUNT/user-data"
test -f "$BOOT_MOUNT/meta-data"
test -f "$BOOT_MOUNT/network-config"
test -f "$BOOT_MOUNT/fhse/fhse-firstboot.sh"
test -f "$BOOT_MOUNT/fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip"
test -f "$BOOT_MOUNT/meta-data"
grep -q 'lock_passwd: true' "$BOOT_MOUNT/user-data"
grep -q 'fhse-rpi4-rc3-11-20260711' "$BOOT_MOUNT/meta-data"
grep -q 'hostname: fhse' "$BOOT_MOUNT/user-data"
grep -q 'fhse-rpi4-rc3-11-20260711' "$BOOT_MOUNT/meta-data"
grep -q 'fhse-firstboot.sh' "$BOOT_MOUNT/user-data"
grep -q 'ds=nocloud;s=/boot/firmware/' "$BOOT_MOUNT/cmdline.txt"

echo "Unmounting image..."
unmount_image

# Re-attach once to validate persistence after detach.
echo "Re-attaching image for persistence validation..."
attach_image "$OUT_IMG"
mount_boot
test -f "$BOOT_MOUNT/user-data"
test -f "$BOOT_MOUNT/fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip"
test -f "$BOOT_MOUNT/meta-data"
grep -q 'lock_passwd: true' "$BOOT_MOUNT/user-data"
grep -q 'fhse-rpi4-rc3-11-20260711' "$BOOT_MOUNT/meta-data"
grep -q 'ds=nocloud;s=/boot/firmware/' "$BOOT_MOUNT/cmdline.txt"
echo "Image boot partition validation: OK"
unmount_image
trap - EXIT

sync

echo "Compressing final image: $OUT_XZ"
xz -T0 -6 -k "$OUT_IMG"
xz -t "$OUT_XZ"

(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$OUT_IMG")" "$(basename "$OUT_XZ")" > SHA256SUMS
)

echo
echo "Done. For Alain's first validation, flash the uncompressed image with Raspberry Pi Imager:"
echo "  $OUT_IMG"
echo
echo "Compressed image also available after validation:"
echo "  $OUT_XZ"
echo
echo "Checksums:"
cat "$DIST_DIR/SHA256SUMS"
