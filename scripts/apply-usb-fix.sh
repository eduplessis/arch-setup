#!/usr/bin/env bash

set -euo pipefail

TARGET_IDS=(
  "2516:012f"
  "0483:5232"
)

echo "Applying USB autosuspend fix..."

set_device_on() {
  local dev_path="$1"

  if [[ ! -f "$dev_path/power/control" ]]; then
    return
  fi

  echo "on" | sudo tee "$dev_path/power/control" >/dev/null
}

matched=0
for dev in /sys/bus/usb/devices/*; do
  [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]] || continue

  vendor="$(<"$dev/idVendor")"
  product="$(<"$dev/idProduct")"
  id="$vendor:$product"

  for target in "${TARGET_IDS[@]}"; do
    if [[ "$id" == "$target" ]]; then
      name="unknown"
      [[ -f "$dev/product" ]] && name="$(<"$dev/product")"
      echo "Found target device $id ($name)"
      set_device_on "$dev"
      echo "  -> power/control set to on"
      matched=$((matched + 1))
      break
    fi
  done
done

if [[ "$matched" -eq 0 ]]; then
  echo "No known device IDs found, trying generic input-device heuristic..."
  for dev in /sys/bus/usb/devices/*; do
    [[ -f "$dev/product" && -f "$dev/power/control" ]] || continue
    product_name="$(tr '[:upper:]' '[:lower:]' < "$dev/product")"

    if [[ "$product_name" == *"mouse"* || "$product_name" == *"keyboard"* ]]; then
      echo "Matched by name: $(<"$dev/product")"
      set_device_on "$dev"
      echo "  -> power/control set to on"
      matched=$((matched + 1))
    fi
  done
fi

if [[ "$matched" -eq 0 ]]; then
  echo "No USB input devices were updated."
else
  echo "Done. Updated $matched device(s)."
fi
