#!/usr/bin/env bash
set -Eeuo pipefail

echo "Mounted volumes:"
ls -1 /Volumes || true

echo
echo "Look for a volume named system-boot after flashing the official Ubuntu Raspberry Pi image."
