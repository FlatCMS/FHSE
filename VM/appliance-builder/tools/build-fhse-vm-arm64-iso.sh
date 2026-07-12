#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$BUILDER_DIR/../.." && pwd)"
DIST_DIR="$BUILDER_DIR/dist"
RELEASE_DIR="$ROOT_DIR/images/VM"
WORKSPACE_DIR="$BUILDER_DIR/workspace"
BUILD_DIR="$WORKSPACE_DIR/build"
ISO_ROOT_DIR="$BUILD_DIR/iso-root"
CONFIG_PATH="$BUILDER_DIR/examples/fhse-vm-arm64.env.example"
BASE_ISO_URL="https://cdimages.ubuntu.com/ubuntu/releases/22.04/release/ubuntu-22.04.5-live-server-arm64.iso"
BASE_ISO_PATH="$DIST_DIR/ubuntu-22.04.5-live-server-arm64.iso"
VERSION="$(tr -d '\n' < "$BUILDER_DIR/VERSION.txt")"
OUTPUT_ISO_PATH="$RELEASE_DIR/fhse-vm-${VERSION}.iso"
OUTPUT_SHA256_PATH="${OUTPUT_ISO_PATH}.sha256"
BUNDLE_PREPARE_SCRIPT="$BUILDER_DIR/tools/prepare-fhse-core-bundle.sh"
RENDER_SCRIPT="$BUILDER_DIR/tools/render-autoinstall-user-data.sh"
INSTALL_SCRIPT_SOURCE="$BUILDER_DIR/assets/install-fhse-target.sh"
DOWNLOAD_BASE_ISO=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --config PATH      FHSE VM ARM64 config file
  --base-iso PATH    Ubuntu Server ARM64 base ISO
  --output PATH      Output FHSE ISO path
  --download         Download the Ubuntu base ISO if missing
  --help             Show this help
EOF
}

need_supported_host() {
  case "$(uname -s)" in
    Linux|Darwin)
      ;;
    *)
      echo "ERROR: this VM ISO builder currently supports Linux and macOS only." >&2
      exit 1
      ;;
  esac
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $1" >&2
    exit 1
  fi
}

run_xorriso_tolerant() {
  set +e
  "$@"
  local status=$?
  set -e

  case "$status" in
    0|32)
      return 0
      ;;
  esac

  return "$status"
}

prepare_clean_dir() {
  local target_dir="$1"
  if [ -d "$target_dir" ]; then
    chmod -R u+w "$target_dir" 2>/dev/null || true
    find "$target_dir" -type d -exec chmod u+rwx {} + 2>/dev/null || true
    rm -rf "$target_dir"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --base-iso)
      BASE_ISO_PATH="$2"
      shift 2
      ;;
    --output)
      OUTPUT_ISO_PATH="$2"
      OUTPUT_SHA256_PATH="${OUTPUT_ISO_PATH}.sha256"
      shift 2
      ;;
    --download)
      DOWNLOAD_BASE_ISO=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

need_supported_host
need_cmd curl
need_cmd openssl
need_cmd python3
need_cmd rsync
need_cmd shasum
need_cmd xorriso

assert_extracted_bootable_iso_root() {
  local iso_root="$1"

  if [ ! -f "$iso_root/boot/grub/grub.cfg" ] \
    || [ ! -f "$iso_root/md5sum.txt" ] \
    || [ ! -d "$iso_root/casper" ] \
    || [ ! -d "$iso_root/efi" ]; then
    echo "ERROR: extracted ISO root is incomplete." >&2
    echo "       Expected boot files were not found under: $iso_root" >&2
    echo "       This usually means the base ISO could not be read correctly." >&2
    echo "       On macOS, avoid protected paths like Desktop/Downloads if xorriso cannot read them." >&2
    echo "       Use a readable ISO path inside the workspace or reuse a known bootable FHSE ISO as base." >&2
    exit 1
  fi
}

mkdir -p "$DIST_DIR" "$BUILD_DIR" "$RELEASE_DIR"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "ERROR: missing config file: $CONFIG_PATH" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$CONFIG_PATH"
set +a

: "${FHSE_OS_HOSTNAME:?Missing FHSE_OS_HOSTNAME}"
: "${FHSE_OS_USERNAME:?Missing FHSE_OS_USERNAME}"
: "${FHSE_OS_PASSWORD:?Missing FHSE_OS_PASSWORD}"

if [ "$DOWNLOAD_BASE_ISO" -eq 1 ] || [ ! -f "$BASE_ISO_PATH" ]; then
  echo "Downloading Ubuntu Server ARM64 base ISO..."
  curl -L --fail --progress-bar "$BASE_ISO_URL" -o "$BASE_ISO_PATH"
fi

if [ ! -f "$BASE_ISO_PATH" ]; then
  echo "ERROR: missing base ISO: $BASE_ISO_PATH" >&2
  exit 1
fi

"$BUNDLE_PREPARE_SCRIPT"
"$RENDER_SCRIPT" "$CONFIG_PATH" "$WORKSPACE_DIR/user-data"

prepare_clean_dir "$ISO_ROOT_DIR"
mkdir -p "$ISO_ROOT_DIR/autoinstall" "$ISO_ROOT_DIR/fhse"

echo "Extracting Ubuntu ARM64 base ISO..."
run_xorriso_tolerant xorriso -osirrox on -indev "$BASE_ISO_PATH" -extract / "$ISO_ROOT_DIR" >/dev/null 2>&1
chmod -R u+w "$ISO_ROOT_DIR"
assert_extracted_bootable_iso_root "$ISO_ROOT_DIR"

cp "$WORKSPACE_DIR/user-data" "$ISO_ROOT_DIR/autoinstall/user-data"
cp "$BUILDER_DIR/autoinstall/meta-data" "$ISO_ROOT_DIR/autoinstall/meta-data"
cp "$INSTALL_SCRIPT_SOURCE" "$ISO_ROOT_DIR/fhse/install-fhse-target.sh"
chmod 0755 "$ISO_ROOT_DIR/fhse/install-fhse-target.sh"
cp "$BUILDER_DIR/assets/flatcms-home-server-bundle-v0.18.2-no-builders.zip" "$ISO_ROOT_DIR/fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip"

python3 - "$ISO_ROOT_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
seed = " autoinstall ds=nocloud\\;s=/cdrom/autoinstall/ "

def patch(path: Path) -> None:
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    changed = False
    lines = []
    for line in text.splitlines():
        updated = line
        stripped = line.lstrip()
        if "autoinstall ds=nocloud\\;s=/cdrom/autoinstall/" not in line:
            if stripped.startswith("linux") or stripped.startswith("append"):
                updated = re.sub(r"\s+---", f"{seed}---", line, count=1)
                if updated != line:
                    changed = True
        lines.append(updated)
    if changed:
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")

for relative in (
    "boot/grub/grub.cfg",
    "boot/grub/loopback.cfg",
    "isolinux/txt.cfg",
):
    patch(root / relative)
PY

if [ -f "$ISO_ROOT_DIR/md5sum.txt" ]; then
  echo "Refreshing md5sum.txt..."
  (
    cd "$ISO_ROOT_DIR"
    find . -type f ! -name md5sum.txt -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 md5sum > md5sum.txt
  )
fi

rm -f "$OUTPUT_ISO_PATH" "$OUTPUT_SHA256_PATH"
echo "Building FHSE VM ARM64 ISO..."
run_xorriso_tolerant xorriso \
  -indev "$BASE_ISO_PATH" \
  -outdev "$OUTPUT_ISO_PATH" \
  -boot_image any replay \
  -overwrite on \
  -update_r "$ISO_ROOT_DIR" / \
  -commit \
  -end >/dev/null 2>&1

shasum -a 256 "$OUTPUT_ISO_PATH" > "$OUTPUT_SHA256_PATH"

echo "FHSE VM ARM64 ISO built:"
echo "  $OUTPUT_ISO_PATH"
echo "FHSE VM ARM64 ISO checksum:"
echo "  $OUTPUT_SHA256_PATH"
