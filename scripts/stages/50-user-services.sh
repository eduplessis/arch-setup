#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

log "Configuring user services..."

for svc in "${USER_SERVICES[@]}"; do
  log "Enabling user service: $svc"
  run_cmd systemctl --user enable --now "$svc"
done

success "User services configured."
