#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

log "Applying hardware/profile settings..."
require_sudo

if [[ -n "${KEYBOARD_LAYOUT:-}" ]]; then
  if [[ -n "${KEYBOARD_VARIANT:-}" ]]; then
    sudo_cmd localectl set-x11-keymap "$KEYBOARD_LAYOUT" "" "$KEYBOARD_VARIANT"
  else
    sudo_cmd localectl set-x11-keymap "$KEYBOARD_LAYOUT"
  fi
fi

udev_source="$ARCH_SETUP_ROOT/$USB_UDEV_RULE_SOURCE"
[[ -f "$udev_source" ]] || die "USB udev source missing: $udev_source"

backup_system_file "/etc/udev/rules.d/50-usb-no-autosuspend.rules"
sudo_cmd install -Dm644 "$udev_source" /etc/udev/rules.d/50-usb-no-autosuspend.rules
sudo_cmd udevadm control --reload-rules

if [[ "${#USB_INPUT_IDS[@]}" -gt 0 ]]; then
  for pair in "${USB_INPUT_IDS[@]}"; do
    vendor="${pair%%:*}"
    product="${pair##*:}"
    log "Triggering udev for USB device $vendor:$product"
    sudo_cmd udevadm trigger --attr-match=idVendor="$vendor" --attr-match=idProduct="$product" 2>/dev/null || true
  done
fi

success "Hardware/profile settings applied."
