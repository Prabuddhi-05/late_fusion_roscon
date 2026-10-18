#!/usr/bin/env bash
set -euo pipefail

# Native Ubuntu on the workshop workstation needs host build networking.
# Docker Desktop under WSL 2 keeps Docker's default build network.
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -f "$here/.env" ]] && ! grep -qi microsoft /proc/sys/kernel/osrelease; then
  printf 'ROSCON_BUILD_NETWORK=host\n' > "$here/.env"
fi
