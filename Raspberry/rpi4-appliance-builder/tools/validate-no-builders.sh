#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUNDLE="$ROOT_DIR/system-boot/fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$BUNDLE" ]; then
  echo "ERROR: bundle not found: $BUNDLE"
  exit 1
fi

unzip -q "$BUNDLE" -d "$TMP"
FLATCMS_ZIP="$TMP/flatcms-home-server-bundle-v0.18.2/packages/flatcms.zip"

if [ ! -f "$FLATCMS_ZIP" ]; then
  echo "ERROR: flatcms.zip not found inside FHSE bundle."
  exit 1
fi

if zipinfo -1 "$FLATCMS_ZIP" | grep -E 'app/Modules/(PagesBuilder|MenuBuilder|FooterBuilder)(/|$)|builders-launch|pages-builder\.json|footer-builder\.json' >/dev/null; then
  echo "ERROR: legacy builders still found in FlatCMS package."
  zipinfo -1 "$FLATCMS_ZIP" | grep -E 'app/Modules/(PagesBuilder|MenuBuilder|FooterBuilder)(/|$)|builders-launch|pages-builder\.json|footer-builder\.json'
  exit 1
fi

echo "OK: no legacy builders found in bundled flatcms.zip"
