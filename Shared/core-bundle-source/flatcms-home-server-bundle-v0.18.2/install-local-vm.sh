#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$BUNDLE_DIR/flatcms-home-server-edition"
BASE_CONFIG="$INSTALLER_DIR/examples/flatcms-home-server-arm64-vm.env.example"
PACKAGE_ZIP="$BUNDLE_DIR/packages/flatcms.zip"
RUNTIME_CONFIG="/tmp/flatcms-home-server-arm64-vm.env"

if [ ! -f "$PACKAGE_ZIP" ]; then
  echo "Missing package: $PACKAGE_ZIP"
  exit 1
fi

cp "$BASE_CONFIG" "$RUNTIME_CONFIG"
sed -i "s#^FLATCMS_PACKAGE_ZIP=.*#FLATCMS_PACKAGE_ZIP=$PACKAGE_ZIP#" "$RUNTIME_CONFIG"

echo "Using FlatCMS package: $PACKAGE_ZIP"
echo "Using runtime config: $RUNTIME_CONFIG"

sudo "$INSTALLER_DIR/installer/install.sh" "$RUNTIME_CONFIG"

