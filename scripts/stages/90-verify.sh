#!/usr/bin/env bash

set -euo pipefail

ARCH_SETUP_ROOT="${ARCH_SETUP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

load_profile

if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
  warn "Skipping verification checks in dry-run mode."
  exit 0
fi

pass_count=0
warn_count=0
fail_count=0

report() {
  local status="$1"
  local scope="$2"
  local check="$3"
  local detail="${4:-}"

  printf '%-5s %-10s %-32s %s\n' "$status" "$scope" "$check" "$detail"

  case "$status" in
    PASS) ((pass_count+=1)) ;;
    WARN) ((warn_count+=1)) ;;
    FAIL) ((fail_count+=1)) ;;
  esac
}

check_binary() {
  local binary="$1"
  local required="$2"

  if command -v "$binary" >/dev/null 2>&1; then
    report PASS binary "$binary" "found"
  elif [[ "$required" == "1" ]]; then
    report FAIL binary "$binary" "missing"
  else
    report WARN binary "$binary" "missing"
  fi
}

check_system_service() {
  local service="$1"

  if sudo systemctl is-enabled "$service" >/dev/null 2>&1 && sudo systemctl is-active "$service" >/dev/null 2>&1; then
    report PASS service "$service" "enabled+active"
  else
    report FAIL service "$service" "not enabled/active"
  fi
}

check_user_service() {
  local service="$1"

  if systemctl --user is-enabled "$service" >/dev/null 2>&1 && systemctl --user is-active "$service" >/dev/null 2>&1; then
    report PASS user-svc "$service" "enabled+active"
  else
    report FAIL user-svc "$service" "not enabled/active"
  fi
}

check_file_present() {
  local file="$1"
  local required="$2"

  if [[ -f "$file" ]]; then
    report PASS file "$file" "present"
  elif [[ "$required" == "1" ]]; then
    report FAIL file "$file" "missing"
  else
    report WARN file "$file" "missing"
  fi
}

check_file_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$file" ]]; then
    report FAIL file "$label" "missing file"
    return
  fi

  if grep -Eq "$pattern" "$file"; then
    report PASS file "$label" "matched"
  else
    report FAIL file "$label" "missing expected content"
  fi
}

printf '\nVerification Results\n'
printf '%-5s %-10s %-32s %s\n' "-----" "----------" "--------------------------------" "----------------"

for bin in "${ESSENTIAL_BINARIES[@]}"; do
  check_binary "$bin" "1"
done

for bin in "${OPTIONAL_BINARIES[@]}"; do
  check_binary "$bin" "0"
done

for svc in "${SYSTEM_SERVICES[@]}"; do
  check_system_service "$svc"
done
check_system_service "greetd"

for svc in "${USER_SERVICES[@]}"; do
  check_user_service "$svc"
done

check_file_present "$HOME/.config/niri/config.kdl" "1"
check_file_present "$HOME/.config/DankMaterialShell/settings.json" "1"
check_file_present "$HOME/.config/environment.d/wayland.conf" "1"
check_file_present "/etc/greetd/config.toml" "1"
check_file_contains "/etc/greetd/config.toml" "dms-greeter" "/etc/greetd/config.toml:dms-greeter"
check_file_present "/etc/udev/rules.d/50-usb-no-autosuspend.rules" "1"

if dms greeter status >/dev/null 2>&1; then
  report PASS greeter "dms greeter status" "ok"
else
  report FAIL greeter "dms greeter status" "not healthy"
fi

if command -v localectl >/dev/null 2>&1; then
  if localectl status | grep -q "X11 Layout: ${KEYBOARD_LAYOUT}"; then
    report PASS keyboard "layout=$KEYBOARD_LAYOUT" "configured"
  else
    report FAIL keyboard "layout=$KEYBOARD_LAYOUT" "not configured"
  fi

  if [[ -n "${KEYBOARD_VARIANT:-}" ]]; then
    if localectl status | grep -q "X11 Variant: ${KEYBOARD_VARIANT}"; then
      report PASS keyboard "variant=$KEYBOARD_VARIANT" "configured"
    else
      report FAIL keyboard "variant=$KEYBOARD_VARIANT" "not configured"
    fi
  fi
fi

if [[ -f "$ARCH_SETUP_DEGRADED_FILE" ]]; then
  report WARN aur degraded "AUR stage had failures"
  if [[ -f "$ARCH_SETUP_FAILED_AUR_FILE" ]]; then
    while IFS= read -r failed_pkg || [[ -n "$failed_pkg" ]]; do
      [[ -n "$failed_pkg" ]] && report WARN aur "$failed_pkg" "failed install"
    done < "$ARCH_SETUP_FAILED_AUR_FILE"
  fi
fi

printf '\nSummary: PASS=%d WARN=%d FAIL=%d\n' "$pass_count" "$warn_count" "$fail_count"

if [[ "$fail_count" -gt 0 ]]; then
  die "Verification failed with essential errors."
fi

success "Verification passed."
