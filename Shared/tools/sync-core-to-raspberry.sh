#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="$ROOT_DIR/Shared/core-bundle-source/flatcms-home-server-bundle-v0.18.2/"
DST_DIR="$ROOT_DIR/Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/"

if [ ! -d "$SRC_DIR" ]; then
  echo "Missing shared source: $SRC_DIR" >&2
  exit 1
fi

if [ ! -d "$DST_DIR" ]; then
  echo "Missing Raspberry target source: $DST_DIR" >&2
  exit 1
fi

rsync -a --delete \
  --exclude '.DS_Store' \
  --exclude 'packages/flatcms.zip' \
  "$SRC_DIR" "$DST_DIR"

echo "Synchronized shared core into Raspberry target source."

