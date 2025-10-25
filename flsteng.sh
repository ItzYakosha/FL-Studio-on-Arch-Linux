#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=================================================="
echo "              FL Studio installation"
echo "=================================================="
echo ""
echo "WARNING: For Arch Linux only. Maybe I'll make it for other distros later."
echo "1. You need the FL Studio installer file (FLStudio_Installer.exe)"
echo "2. Download it from the official website: https://www.image-line.com/fl-studio-download/"
echo "3. Save it to ~/Downloads/FLStudio/FLStudio_Installer.exe"
echo "4. Make sure the file exists before continuing installation"
echo ""
echo "This script will install:"
echo "- Bottles (from AUR)"
echo "- Wine and dependencies"
echo "- Create a dedicated bottle for FL Studio"
echo "- Install required components"
echo ""
echo -n "Continue installation? (y/N): "
read -r answer

if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "Installation cancelled"
    exit 0
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

install_dependencies() {
    log_info "Updating system and installing dependencies..."

    sudo pacman -Syu --noconfirm

    sudo pacman -S --noconfirm \
        curl \
        wget \
        git \
        wine \
        winetricks \
        cabextract \
        p7zip \
        zenity \
        fuse2 \
        base-devel \
        mesa \
        lib32-mesa \
        vulkan-intel \
        lib32-vulkan-intel \
        vulkan-radeon \
        lib32-vulkan-radeon \
        lib32-gcc-libs \
        lib32-libx11 \
        lib32-libxext \
        lib32-alsa-plugins
}

install_bottles() {
    log_info "Installing Bottles..."

    if pacman -Qi bottles &>/dev/null; then
        log_info "Bottles is already installed"
        return
    fi

    if command -v yay &>/dev/null; then
        log_info "Installing Bottles via yay..."
        yay -S --noconfirm bottles
    elif command -v paru &>/dev/null; then
        log_info "Installing Bottles via paru..."
        paru -S --noconfirm bottles
    else
        log_warn "Neither yay nor paru found. Installing manually..."
        install_bottles_manual
    fi
}

install_bottles_manual() {
    log_info "Manual Bottles installation from AUR..."

    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    git clone https://aur.archlinux.org/bottles.git
    cd bottles
    makepkg -si --noconfirm

    cd /
    rm -rf "$TEMP_DIR"
}

setup_bottles_config() {
    log_info "Configuring Bottles for FL Studio..."

    mkdir -p ~/.var/app/com.usebottles.bottles/config/bottles/

    cat > ~/.var/app/com.usebottles.bottles/config/bottles/bottles.conf << 'EOF'
[General]
auto_close_bottles=false
check_updates=true
dark_theme=true
experimental_features=false
notifications=true
release_candidate=false
steam_support=false
temp=false
update_date=0
window_height=720
window_width=1280

[Models]
LibraryListSort=0
LibraryListSortNew=0

[Wine]
auto_close_bottles=false
batch_size=1024
language=sys
sync=fsync
EOF
}

create_flstudio_bottle() {
    log_info "Creating FL Studio bottle..."

    if command -v bottles-cli &>/dev/null; then
        bottles-cli new --name "FLStudio" --environment gaming
    else
        log_warn "bottles-cli not found. Please create the bottle manually via GUI"
        log_info "Launch Bottles and create a new bottle named 'FLStudio' with the 'Gaming' environment"
    fi
}

install_bottle_components() {
    log_info "Installing components into the bottle..."

    COMPONENTS=(
        "dotnet48"
        "vcrun2019"
        "corefonts"
        "directx9"
        "xna40"
    )

    for component in "${COMPONENTS[@]}"; do
        log_info "Installing component: $component"
        if command -v bottles-cli &>/dev/null; then
            bottles-cli install --bottle "FLStudio" --component "$component"
        else
            winetricks --force -q "$component"
        fi
        sleep 2
    done
}

download_flstudio_installer() {
    log_info "Checking for FL Studio installer..."

    mkdir -p ~/Downloads

    if [ -f ~/Downloads/FLStudio_Installer.exe ]; then
        log_info "FL Studio installer found"
        return
    fi

    log_error "FL Studio installer not found!"
    log_info "Download FLStudio_Installer.exe from https://www.image-line.com/fl-studio-download/"
    log_info "Save it to: ~/Downloads/FLStudio_Installer.exe"
    log_info "Run this script again after downloading"
    exit 1
}

install_flstudio() {
    log_info "Installing FL Studio..."

    if [ ! -f ~/Downloads/FLStudio_Installer.exe ]; then
        log_error "FL Studio installer not found!"
        exit 1
    fi

    if command -v bottles-cli &>/dev/null; then
        bottles-cli run --bottle "FLStudio" --executable ~/Downloads/FLStudio_Installer.exe
    else
        log_info "Launching installer via wine..."
        wine ~/Downloads/FLStudio_Installer.exe
    fi
}

create_desktop_shortcut() {
    log_info "Creating desktop shortcut..."

    cat > ~/Desktop/FLStudio.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=FL Studio
Comment=Digital Audio Workstation
Exec=bottles -b FLStudio -e "FL64.exe"
Icon=wine
Terminal=false
Categories=Audio;Music;
EOF

    chmod +x ~/Desktop/FLStudio.desktop
}

final_setup() {
    log_info "Final setup..."

    if pacman -Qi pulseaudio &>/dev/null; then
        sudo usermod -aG audio "$USER"
    fi

    if ! grep -q "@audio" /etc/security/limits.conf; then
        log_info "Configuring realtime priorities for audio group..."
        echo "@audio - rtprio 99" | sudo tee -a /etc/security/limits.conf
        echo "@audio - memlock unlimited" | sudo tee -a /etc/security/limits.conf
    fi

    sudo usermod -aG audio "$USER"
}

main() {
    log_info "Starting FL Studio installation on Arch Linux"

    check_arch
    install_dependencies
    install_bottles
    setup_bottles_config
    create_flstudio_bottle
    install_bottle_components
    download_flstudio_installer

    log_warn "FL Studio installation will now begin"
    log_info "Follow the installer instructions"
    echo
    log_info "Press Enter to start FL Studio installation..."
    read -r

    install_flstudio
    create_desktop_shortcut
    final_setup

    log_info "Installation complete!"
    log_info "Launch FL Studio via Bottles or the desktop shortcut"
    log_info "A reboot may be required for group changes to take effect"
    log_info "Activation will also be required!"
    log_info "i_y."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
