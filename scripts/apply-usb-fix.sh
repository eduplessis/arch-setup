#!/bin/bash
#
# Apply USB autosuspend fix for current session
# Run this if you need immediate fix without rebooting
#

set -e

echo "Applying USB autosuspend fixes..."

# Cooler Master MM710 Gaming Mouse
echo "on" | sudo tee /sys/bus/usb/devices/7-1.1.2/power/control 2>/dev/null || echo "Mouse device not found (may need to find correct path)"

# 68EC-S Keyboard
echo "on" | sudo tee /sys/bus/usb/devices/7-1.1.3/power/control 2>/dev/null || echo "Keyboard device not found (may need to find correct path)"

# Alternative: Find and fix all input devices
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/product" ]; then
        product=$(cat "$dev/product" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [[ "$product" == *"mouse"* ]] || [[ "$product" == *"keyboard"* ]] || [[ "$product" == *"mm710"* ]] || [[ "$product" == *"68ec"* ]]; then
            echo "Found: $(cat $dev/product)"
            echo "on" | sudo tee "$dev/power/control" 2>/dev/null || true
            echo "  -> Fixed"
        fi
    fi
done

echo "Done!"
