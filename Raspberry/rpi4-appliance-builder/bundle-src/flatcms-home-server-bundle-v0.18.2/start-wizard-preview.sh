#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${FLATCMS_WIZARD_HOST:-0.0.0.0}"
PORT="${FLATCMS_WIZARD_PORT:-8080}"

if [ "${EUID}" -ne 0 ]; then
  echo "The wizard preview must run as root so it can launch the installer."
  echo "Re-running with sudo..."
  exec sudo FLATCMS_WIZARD_HOST="$HOST" FLATCMS_WIZARD_PORT="$PORT" "$0" "$@"
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${PORT}/tcp" 2>/dev/null || true
fi

echo "FlatCMS Home Server Installer V0.18.2 RC3.11"
echo "Open: http://$(hostname -I | awk '{print $1}'):${PORT}"
echo

exec python3 "$BUNDLE_DIR/wizard-preview/server.py" --host "$HOST" --port "$PORT"
