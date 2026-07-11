#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 installer/steps/XX-step.sh"
  exit 1
fi

bash "$1"

