#!/bin/bash
# Установка системных зависимостей

log() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m✓\033[0m $1"; }

install_dependencies() {
    log "Установка системных зависимостей..."
    
    dnf update -y
    dnf install -y wget curl cabextract p7zip unzip
    dnf install -y freetype fontconfig libX11 libXext libXcursor libXi
    dnf install -y libXrandr libXinerama libXcomposite mesa-libGLU
    dnf install -y cifs-utils nfs-utils
    dnf install -y wine wine.i686 icoutils ImageMagick
    
    # Winetricks
    wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
    chmod +x winetricks
    mv winetricks /usr/local/bin/
    
    success "Зависимости установлены"
}

install_dependencies