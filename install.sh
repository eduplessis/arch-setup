#!/bin/bash
#
# Arch Linux Setup Script
# Configures niri + DMS (DankLinux Material Shell) environment
# For Framework Laptop with AMD Ryzen 7 7840U
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Check if running on Arch Linux
check_arch() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS. Are you running Arch Linux?"
    fi
    
    if ! grep -q "^ID=arch" /etc/os-release; then
        error "This script is designed for Arch Linux only."
    fi
    
    success "Arch Linux detected"
}

# Check for sudo access
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log "This script requires sudo privileges"
        sudo -v || error "Failed to obtain sudo access"
    fi
    # Keep sudo alive
    while true; do
        sudo -n true
        sleep 60
    done 2>/dev/null &
    SUDO_PID=$!
    success "Sudo access confirmed"
}

# Update system
update_system() {
    log "Updating system packages..."
    sudo pacman -Syu --noconfirm
    success "System updated"
}

# Install yay (AUR helper) if not present
install_yay() {
    if command -v yay &>/dev/null; then
        success "yay already installed"
        return
    fi
    
    log "Installing yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm git base-devel
    
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
    rm -rf /tmp/yay
    
    success "yay installed"
}

# Install packages from official repos
install_official_packages() {
    log "Installing packages from official repositories..."
    
    sudo pacman -S --needed --noconfirm - < "$SCRIPT_DIR/packages/official.txt"
    success "Official packages installed"
}

# Install packages from AUR
install_aur_packages() {
    log "Installing AUR packages..."
    
    yay -S --needed --noconfirm - < "$SCRIPT_DIR/packages/aur.txt"
    success "AUR packages installed"
}

# Configure keyboard layout (Canadian Multilingual)
configure_keyboard() {
    log "Configuring Canadian Multilingual keyboard layout..."
    sudo localectl set-x11-keymap ca "" multix
    success "Keyboard layout configured"
}

# Configure USB autosuspend fix for mouse and keyboard
configure_usb_autosuspend() {
    log "Configuring USB autosuspend fixes..."
    
    sudo cp "$SCRIPT_DIR/udev/50-usb-no-autosuspend.rules" /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    
    # Trigger for existing devices
    sudo udevadm trigger --attr-match=idVendor=2516 --attr-match=idProduct=012f 2>/dev/null || true
    sudo udevadm trigger --attr-match=idVendor=0483 --attr-match=idProduct=5232 2>/dev/null || true
    
    success "USB autosuspend fixes applied"
}

# Copy configuration files
setup_configs() {
    log "Setting up configuration files..."
    
    # Backup existing configs
    if [[ -d ~/.config/niri ]]; then
        BACKUP_DIR="$HOME/.config/niri.backup.$(date +%Y%m%d_%H%M%S)"
        mv ~/.config/niri "$BACKUP_DIR"
        warn "Existing niri config backed up to $BACKUP_DIR"
    fi
    
    # Copy niri config
    cp -r "$SCRIPT_DIR/configs/niri" ~/.config/
    
    # Copy DMS config
    mkdir -p ~/.config/DankMaterialShell
    cp "$SCRIPT_DIR/configs/DankMaterialShell/settings.json" ~/.config/DankMaterialShell/
    
    # Copy environment.d
    mkdir -p ~/.config/environment.d
    cp "$SCRIPT_DIR/configs/environment.d/"*.conf ~/.config/environment.d/ 2>/dev/null || true
    
    success "Configuration files installed"
}

# Enable system services
enable_services() {
    log "Enabling system services..."
    
    # Power management
    sudo systemctl enable --now power-profiles-daemon
    
    # Audio
    systemctl --user enable --now pipewire pipewire-pulse wireplumber
    
    # Display manager (greetd)
    sudo systemctl enable --now greetd
    
    # Podman (rootless containers)
    systemctl --user enable --now podman.socket
    
    success "Services enabled"
}

# Configure podman
setup_podman() {
    log "Configuring Podman..."
    
    # Enable rootless podman
    sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER" 2>/dev/null || true
    
    # Create podman config dir
    mkdir -p ~/.config/containers
    
    # Basic containers.conf
    cat > ~/.config/containers/containers.conf << 'EOF'
[containers]
netns="slirp4netns"
EOF
    
    success "Podman configured"
}

# Setup greetd
setup_greetd() {
    log "Configuring greetd..."
    
    # Create greetd config if it doesn't exist
    if [[ ! -f /etc/greetd/config.toml ]]; then
        sudo mkdir -p /etc/greetd
        sudo tee /etc/greetd/config.toml > /dev/null << 'EOF'
[terminal]
vt = 1

[default_session]
command = "agreety --cmd niri-session"
user = "greeter"
EOF
    fi
    
    success "greetd configured"
}

# Post-install message
post_install() {
    echo ""
    echo "==================================="
    echo "  Installation Complete!"
    echo "==================================="
    echo ""
    echo "Next steps:"
    echo "  1. Reboot your system: sudo reboot"
    echo "  2. Login at greetd and niri will start automatically"
    echo "  3. Run 'vicinae server' if the launcher doesn't start"
    echo ""
    echo "Keyboard: Canadian Multilingual (CAN/CSA)"
    echo "  - Dead keys for accents: ' + e = é"
    echo "  - € on AltGr+5"
    echo ""
    echo "Key bindings:"
    echo "  - Mod+Space: Open launcher (Vicinae)"
    echo "  - Mod+Alt+L: Lock screen"
    echo "  - Mod+Shift+P: Power off monitors"
    echo ""
    echo "For issues, check ~/.local/share/niri/niri.log"
    echo ""
}

# Cleanup
cleanup() {
    if [[ -n "${SUDO_PID:-}" ]]; then
        kill "$SUDO_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Main installation
main() {
    echo "==================================="
    echo "  Arch Linux + niri + DMS Setup"
    echo "==================================="
    echo ""
    
    check_arch
    check_sudo
    update_system
    install_yay
    install_official_packages
    install_aur_packages
    configure_keyboard
    configure_usb_autosuspend
    setup_configs
    setup_greetd
    setup_podman
    enable_services
    post_install
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
