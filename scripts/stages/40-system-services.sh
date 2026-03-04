#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

log "Configuring system services..."
require_sudo

greetd_source="$ARCH_SETUP_ROOT/$GREETD_CONFIG_RELATIVE_PATH"
[[ -f "$greetd_source" ]] || die "greetd config source is missing: $greetd_source"

backup_system_file "/etc/greetd/config.toml"
sudo_cmd install -Dm644 "$greetd_source" /etc/greetd/config.toml

for svc in "${SYSTEM_SERVICES[@]}"; do
  log "Enabling system service: $svc"
  sudo_cmd systemctl enable --now "$svc"
done

success "System services configured."
