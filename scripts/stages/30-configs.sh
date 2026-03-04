#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

log "Deploying configuration files (backup then replace)..."

run_cmd mkdir -p "$HOME/.config"

copy_dir_with_backup() {
  local src="$1"
  local dest="$2"

  [[ -d "$src" ]] || die "Source directory not found: $src"

  if [[ -e "$dest" ]]; then
    backup_user_path "$dest"
  fi

  run_cmd cp -a "$src" "$dest"
}

copy_dir_with_backup "$ARCH_SETUP_ROOT/configs/niri" "$HOME/.config/niri"
copy_dir_with_backup "$ARCH_SETUP_ROOT/configs/DankMaterialShell" "$HOME/.config/DankMaterialShell"

run_cmd mkdir -p "$HOME/.config/environment.d"
for src_file in "$ARCH_SETUP_ROOT/configs/environment.d"/*.conf; do
  [[ -f "$src_file" ]] || continue
  dest_file="$HOME/.config/environment.d/$(basename "$src_file")"
  if [[ -e "$dest_file" ]]; then
    backup_user_path "$dest_file"
  fi
  run_cmd install -m 0644 "$src_file" "$dest_file"
done

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
  run_cmd xdg-user-dirs-update
fi

success "User configuration deployment complete."
