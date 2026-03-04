#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

log "Running preflight checks..."

if [[ "$EUID" -eq 0 ]]; then
  die "Run this installer as a regular user, not root."
fi

if [[ ! -f /etc/os-release ]] || ! grep -q '^ID=arch' /etc/os-release; then
  die "This setup supports Arch Linux only."
fi

require_command bash sudo pacman systemctl getent
require_sudo

[[ -f "$ARCH_SETUP_ROOT/packages/official.txt" ]] || die "Missing packages/official.txt"
[[ -f "$ARCH_SETUP_ROOT/configs/niri/config.kdl" ]] || die "Missing niri config"
[[ -f "$ARCH_SETUP_ROOT/configs/DankMaterialShell/settings.json" ]] || die "Missing DMS settings"
[[ -f "$ARCH_SETUP_ROOT/$USB_UDEV_RULE_SOURCE" ]] || die "Missing udev rule file: $USB_UDEV_RULE_SOURCE"

if [[ "$ARCH_SETUP_SKIP_AUR" != "1" ]]; then
  [[ -f "$ARCH_SETUP_ROOT/packages/aur.txt" ]] || die "Missing packages/aur.txt"
fi

if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
  warn "Skipping network/DNS validation in dry-run mode."
else
  if ! getent ahosts archlinux.org >/dev/null 2>&1; then
    die "Network/DNS check failed (could not resolve archlinux.org)."
  fi
fi

run_cmd mkdir -p "$ARCH_SETUP_STATE_DIR" "$ARCH_SETUP_STAGE_STATE_DIR" "$ARCH_SETUP_BACKUP_ROOT"

success "Preflight checks passed."
