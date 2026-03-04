#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

log "Installing official packages..."

require_command pacman
require_sudo

package_file="$ARCH_SETUP_ROOT/packages/official.txt"
read_package_list "$package_file" packages

if [[ "${#packages[@]}" -eq 0 ]]; then
  die "No packages found in $package_file"
fi

if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
  warn "Skipping package availability validation in dry-run mode."
else
  missing_pkgs=()
  for pkg in "${packages[@]}"; do
    if ! pacman -Si "$pkg" >/dev/null 2>&1; then
      missing_pkgs+=("$pkg")
    fi
  done

  if [[ "${#missing_pkgs[@]}" -gt 0 ]]; then
    warn "Unavailable official packages:"
    printf '  - %s\n' "${missing_pkgs[@]}"
    die "Resolve missing packages or repositories before continuing."
  fi
fi

sudo_cmd pacman -Syu --noconfirm
sudo_cmd pacman -S --needed --noconfirm "${packages[@]}"

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
  run_cmd xdg-user-dirs-update
fi

success "Official package installation complete."
