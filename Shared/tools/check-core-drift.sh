#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="$ROOT_DIR/Shared/core-bundle-source/flatcms-home-server-bundle-v0.18.2"
DST_DIR="$ROOT_DIR/Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2"

rsync -rcn --delete --out-format='%n' \
  --exclude '.DS_Store' \
  --exclude 'packages/flatcms.zip' \
  --exclude 'packages/README.md' \
  --exclude 'packages/flatcms.zip.sha256' \
  "$SRC_DIR/" "$DST_DIR/"
