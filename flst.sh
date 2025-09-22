#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=================================================="
echo "              Установщик FL Studio"
echo "=================================================="
echo ""
echo "ПРЕДУПРЕЖДЕНИЕ: ПОКА ЧТО ТОЛЬКО Arch Linux! В будущем может сделаю еще для других дистрибутивов."
echo "1. Вам потребуется УСТАНОВОЧНЫЙ ФАЙЛ FL Studio (FLStudio_Installer.exe)"
echo "2. Скачайте его с официального сайта: https://www.image-line.com/fl-studio-download/"
echo "3. Сохраните в ~/Downloads/FLStudio/FLStudio_Installer.exe"
echo "4. Убедитесь что файл существует перед продолжением"
echo ""
echo "Скрипт установит:"
echo "- Bottles (из AUR)"
echo "- Wine и зависимости"
echo "- Создаст бутылку для FL Studio"
echo "- Установит необходимые компоненты"
echo ""
echo -n "Продолжить установку? (y/N): "
read -r answer

if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "Установка отменена"
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
    log_info "Обновление системы и установка зависимостей..."

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
    log_info "Установка Bottles..."

    if pacman -Qi bottles &>/dev/null; then
        log_info "Bottles уже установлен"
        return
    fi

    if command -v yay &>/dev/null; then
        log_info "Установка Bottles через yay..."
        yay -S --noconfirm bottles
    elif command -v paru &>/dev/null; then
        log_info "Установка Bottles через paru..."
        paru -S --noconfirm bottles
    else
        log_warn "yay или paru не найдены. Установка вручную..."
        install_bottles_manual
    fi
}

install_bottles_manual() {
    log_info "Ручная установка Bottles из AUR..."

    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    git clone https://aur.archlinux.org/bottles.git
    cd bottles
    makepkg -si --noconfirm

    cd /
    rm -rf "$TEMP_DIR"
}

setup_bottles_config() {
    log_info "Настройка Bottles для FL Studio..."

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
    log_info "Создание бутылки для FL Studio..."

    if command -v bottles-cli &>/dev/null; then
        bottles-cli new --name "FLStudio" --environment gaming
    else
        log_warn "bottles-cli не найден, создайте бутылку вручную через GUI"
        log_info "Запустите Bottles и создайте новую бутылку с именем 'FLStudio' и окружением 'Gaming'"
    fi
}

install_bottle_components() {
    log_info "Установка компонентов в бутылку..."

    COMPONENTS=(
        "dotnet48"
        "vcrun2019"
        "corefonts"
        "directx9"
        "xna40"
    )

    for component in "${COMPONENTS[@]}"; do
        log_info "Установка компонента: $component"
        if command -v bottles-cli &>/dev/null; then
            bottles-cli install --bottle "FLStudio" --component "$component"
        else
            winetricks --force -q "$component"
        fi
        sleep 2
    done
}

download_flstudio_installer() {
    log_info "Проверка установщика FL Studio..."

    mkdir -p ~/Downloads

    if [ -f ~/Downloads/FLStudio_Installer.exe ]; then
        log_info "Установщик FL Studio найден"
        return
    fi

    log_error "Установщик FL Studio не найден!"
    log_info "Скачайте FLStudio_Installer.exe с https://www.image-line.com/fl-studio-download/"
    log_info "Сохраните в: ~/Downloads/FLStudio_Installer.exe"
    log_info "Запустите скрипт снова после загрузки"
    exit 1
}

install_flstudio() {
    log_info "Установка FL Studio..."

    if [ ! -f ~/Downloads/FLStudio_Installer.exe ]; then
        log_error "Установщик FL Studio не найден!"
        exit 1
    fi

    if command -v bottles-cli &>/dev/null; then
        bottles-cli run --bottle "FLStudio" --executable ~/Downloads/FLStudio_Installer.exe
    else
        log_info "Запуск установщика через wine..."
        wine ~/Downloads/FLStudio_Installer.exe
    fi
}

create_desktop_shortcut() {
    log_info "Создание ярлыка на рабочем столе..."

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
    log_info "Финальная настройка..."

    if pacman -Qi pulseaudio &>/dev/null; then
        sudo usermod -aG audio "$USER"
    fi

    if ! grep -q "@audio" /etc/security/limits.conf; then
        log_info "Настройка realtime приоритетов для audio группы..."
        echo "@audio - rtprio 99" | sudo tee -a /etc/security/limits.conf
        echo "@audio - memlock unlimited" | sudo tee -a /etc/security/limits.conf
    fi

    sudo usermod -aG audio "$USER"
}

main() {
    log_info "Начало установки FL Studio на Arch Linux"

    check_arch
    install_dependencies
    install_bottles
    setup_bottles_config
    create_flstudio_bottle
    install_bottle_components
    download_flstudio_installer

    log_warn "Сейчас будет запущена установка FL Studio"
    log_info "Следуйте инструкциям установщика"
    echo
    log_info "Нажмите Enter чтобы начать установку FL Studio..."
    read -r

    install_flstudio
    create_desktop_shortcut
    final_setup

    log_info "Установка завершена!"
    log_info "Запустите FL Studio через Bottles или ярлык на рабочем столе"
    log_info "Может потребоваться перезагрузка для применения изменений групп"
    log_info "Также потребуется активация!"
    log_info "i_y. "
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
