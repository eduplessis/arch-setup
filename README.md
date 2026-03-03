# Arch Linux + niri + DMS Setup

Automated setup script for Arch Linux with niri compositor and DankLinux Material Shell (DMS).

## Overview

This repository contains everything needed to replicate my Arch Linux setup on a fresh install.

**Target Hardware:** Framework Laptop with AMD Ryzen 7 7840U

**Software Stack:**
- **OS:** Arch Linux
- **Compositor:** niri (Wayland)
- **Shell:** DankLinux Material Shell (DMS)
- **Display Manager:** greetd
- **Audio:** PipeWire + WirePlumber
- **Launcher:** Vicinae
- **Browser:** Zen Browser (Firefox-based)
- **Editor:** VS Code
- **Containers:** Podman (rootless)

## Features

### 🖥️ Display
- HiDPI support with 1.25 scale
- 2560x1600 @ 240Hz (Framework laptop display)
- Proper scaling for GTK, Qt, and Electron apps

### ⌨️ Input
- **Keyboard:** Canadian Multilingual Standard (CAN/CSA)
- **Touchpad:** Natural scroll, tap to click
- **USB fixes:** No autosuspend lag on mouse/keyboard

### 🎨 Theming
- Dynamic theming with matugen
- Elementary icon theme
- Rounded corners (12px radius)

### ⚡ Power Management
- power-profiles-daemon
- USB autosuspend disabled for input devices
- Battery optimizations

## Quick Start

### 1. Install Arch Linux

Follow the [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide) with these notes:

```bash
# Create a user
useradd -m -G wheel -s /bin/bash eduplessis
passwd eduplessis

# Enable sudo for wheel group
EDITOR=vim visudo
# Uncomment: %wheel ALL=(ALL:ALL) ALL
```

### 2. Clone and Run Setup

```bash
# Install git first
sudo pacman -S git

# Clone this repository
git clone https://github.com/yourusername/arch-setup.git ~/.config/arch-setup
cd ~/.config/arch-setup

# Run the installer
./install.sh
```

### 3. Reboot

```bash
sudo reboot
```

## Post-Installation

### First Login

1. Login at greetd
2. niri will start automatically
3. Vicinae launcher should start (Mod+Space to open)

### Essential Commands

```bash
# Lock screen
dms ipc call lock lock

# Control brightness
dms ipc brightness increment 5
dms ipc brightness decrement 5

# Idle inhibit (prevent screen off)
dms ipc inhibit enable
dms ipc inhibit disable

# Display power
dms dpms off
dms dpms on
```

## Keyboard Layout

**Canadian Multilingual Standard (CAN/CSA Z243.200-92)**

| Key Combination | Result |
|-----------------|--------|
| `'` + `e` | é |
| `` ` `` + `e` | è |
| `^` + `e` | ê |
| `¨` + `e` | ë |
| AltGr + 5 | € |

## Key Bindings

| Key | Action |
|-----|--------|
| Mod+Space | Open launcher (Vicinae) |
| Mod+Alt+L | Lock screen |
| Mod+Shift+P | Power off monitors |
| Mod+M | Task manager |
| Mod+N | Notification center |
| Mod+[1-9] | Switch to workspace |
| Mod+Shift+[1-9] | Move window to workspace |

## Troubleshooting

### Mouse/Keyboard Delay

If input devices lag after the script:

```bash
# Apply immediate fix
./scripts/apply-usb-fix.sh

# Check device paths
ls /sys/bus/usb/devices/*/product

# Edit udev rule with correct paths
sudo vim /etc/udev/rules.d/50-usb-no-autosuspend.rules
sudo udevadm control --reload-rules
```

### Display Issues

```bash
# Check outputs
niri msg outputs

# View logs
journalctl --user -u niri
```

### Audio Not Working

```bash
# Restart PipeWire
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### Podman Issues

```bash
# Check podman status
podman info

# Rootless mode not working (requires logout/login after first install)
podman run hello-world

# Enable podman socket for Docker compatibility
systemctl --user enable --now podman.socket
```

## Applications Included

### Development
- **VS Code** - Code editor with Wayland support
- **Podman** - Rootless container engine

### Web Browsing
- **Zen Browser** - Firefox-based browser optimized for vertical tabs
- **Firefox** - Backup browser

### System
- **Vicinae** - Application launcher
- **Thunar** - File manager

## Repository Structure

```
.
├── install.sh              # Main installation script
├── README.md               # This file
├── packages/
│   ├── official.txt        # Pacman packages
│   └── aur.txt             # AUR packages
├── udev/
│   └── 50-usb-no-autosuspend.rules  # USB fixes
├── scripts/
│   └── apply-usb-fix.sh    # Manual USB fix script
└── configs/
    ├── niri/               # niri window manager config
    │   ├── config.kdl
    │   └── dms/
    ├── DankMaterialShell/  # DMS settings
    │   └── settings.json
    └── environment.d/      # Environment variables
        └── wayland.conf
```

## Customization

### Adding New USB Devices

Edit `udev/50-usb-no-autosuspend.rules`:

```bash
# Find your device
lsusb

# Add rule
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="XXXX", ATTR{idProduct}=="XXXX", ATTR{power/control}="on"
```

### Changing Keyboard Layout

Edit `configs/niri/config.kdl`:

```kdl
keyboard {
    xkb {
        layout "ca"       # Layout code
        variant "multix"  # Variant (optional)
    }
}
```

Then run:
```bash
sudo localectl set-x11-keymap ca "" multix
```

## Credits

- [niri](https://github.com/YaLTeR/niri) - Scrollable-tiling Wayland compositor
- [DankLinux Material Shell](https://github.com/dank-linux) - Material Design shell for Wayland
- [Vicinae](https://aur.archlinux.org/packages/vicinae) - Launcher for Wayland

## License

MIT License - Feel free to use and modify for your own setup.
