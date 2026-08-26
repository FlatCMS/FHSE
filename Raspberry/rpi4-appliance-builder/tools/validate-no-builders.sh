#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUNDLE="$ROOT_DIR/system-boot/fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip"
EXPECTED_CORE_VERSION="${1:-}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$BUNDLE" ]; then
  echo "ERROR: bundle not found: $BUNDLE"
  exit 1
fi

unzip -q "$BUNDLE" -d "$TMP"
FLATCMS_ZIP="$TMP/flatcms-home-server-bundle-v0.18.2/packages/flatcms.zip"
FLATCMS_CHECKSUM="$FLATCMS_ZIP.sha256"

if [ ! -f "$FLATCMS_ZIP" ]; then
  echo "ERROR: flatcms.zip not found inside FHSE bundle."
  exit 1
fi

if [ ! -f "$FLATCMS_CHECKSUM" ]; then
  echo "ERROR: flatcms.zip.sha256 not found inside FHSE bundle."
  exit 1
fi

(
  cd "$(dirname "$FLATCMS_ZIP")"
  sha256sum -c "$(basename "$FLATCMS_CHECKSUM")"
)

"$ROOT_DIR/../../Shared/tools/validate-flatcms-payload.sh" "$FLATCMS_ZIP" "$EXPECTED_CORE_VERSION"

if zipinfo -1 "$FLATCMS_ZIP" | grep -E 'app/Modules/(PagesBuilder|MenuBuilder|FooterBuilder)(/|$)|builders-launch|pages-builder\.json|footer-builder\.json' >/dev/null; then
  echo "ERROR: legacy builders still found in FlatCMS package."
  zipinfo -1 "$FLATCMS_ZIP" | grep -E 'app/Modules/(PagesBuilder|MenuBuilder|FooterBuilder)(/|$)|builders-launch|pages-builder\.json|footer-builder\.json'
  exit 1
fi

echo "OK: no legacy builders found in bundled flatcms.zip"
