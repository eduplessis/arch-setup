#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

if [[ "$ARCH_SETUP_SKIP_AUR" == "1" ]]; then
  log "Skipping AUR stage because --no-aur was provided."
  exit 0
fi

require_command git mktemp

install_yay_if_missing() {
  local tmp_dir

  if command -v yay >/dev/null 2>&1; then
    log "yay is already installed."
    return
  fi

  log "Installing yay..."
  sudo_cmd pacman -S --needed --noconfirm git base-devel

  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    return
  fi

  tmp_dir="$(mktemp -d /tmp/arch-setup-yay.XXXXXX)"
  trap 'rm -rf "$tmp_dir"' RETURN

  git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
  pushd "$tmp_dir/yay" >/dev/null
  makepkg -si --noconfirm --needed
  popd >/dev/null
}

install_yay_if_missing

package_file="$ARCH_SETUP_ROOT/packages/aur.txt"
read_package_list "$package_file" aur_packages

if [[ "${#aur_packages[@]}" -eq 0 ]]; then
  log "No AUR packages defined."
  if [[ "$ARCH_SETUP_DRY_RUN" == "0" ]]; then
    rm -f "$ARCH_SETUP_FAILED_AUR_FILE" "$ARCH_SETUP_DEGRADED_FILE"
  fi
  exit 0
fi

if [[ "$ARCH_SETUP_DRY_RUN" == "0" ]]; then
  rm -f "$ARCH_SETUP_FAILED_AUR_FILE" "$ARCH_SETUP_DEGRADED_FILE"
fi

failed_packages=()
for pkg in "${aur_packages[@]}"; do
  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN: yay -S --needed --noconfirm $pkg"
    continue
  fi

  log "Installing AUR package: $pkg"
  set +e
  yay -S --needed --noconfirm "$pkg"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    warn "Failed to install AUR package: $pkg"
    failed_packages+=("$pkg")
  fi
done

if [[ "${#failed_packages[@]}" -gt 0 ]]; then
  if [[ "$ARCH_SETUP_DRY_RUN" == "0" ]]; then
    printf '%s\n' "${failed_packages[@]}" > "$ARCH_SETUP_FAILED_AUR_FILE"
    : > "$ARCH_SETUP_DEGRADED_FILE"
  fi

  if [[ "$ARCH_SETUP_STRICT_AUR" == "1" ]]; then
    die "AUR package installation failed and --strict-aur is enabled."
  fi

  warn "AUR stage completed with failures (degraded mode)."
  exit 0
fi

if [[ "$ARCH_SETUP_DRY_RUN" == "0" ]]; then
  rm -f "$ARCH_SETUP_FAILED_AUR_FILE" "$ARCH_SETUP_DEGRADED_FILE"
fi

success "AUR package installation complete."
