#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

log "Configuring system services..."
require_sudo

if [[ "$ARCH_SETUP_DRY_RUN" != "1" ]] && ! command -v dms >/dev/null 2>&1; then
  die "dms command not found. Ensure DankMaterialShell is installed before this stage."
fi

backup_system_file "/etc/greetd/config.toml"

log "Configuring greetd with DankGreeter..."
run_cmd dms greeter enable
run_cmd dms greeter sync
sudo_cmd systemctl enable --now greetd

for svc in "${SYSTEM_SERVICES[@]}"; do
  log "Enabling system service: $svc"
  sudo_cmd systemctl enable --now "$svc"
done

success "System services configured."
