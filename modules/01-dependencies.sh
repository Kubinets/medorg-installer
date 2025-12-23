#!/bin/bash
# Установка системных зависимостей

install_dependencies() {
    echo "Установка зависимостей..."
    
    # Обновление
    dnf update -y
    
    # Основные утилиты
    dnf install -y wget curl cabextract p7zip unzip
    
    # Графические библиотеки
    dnf install -y freetype fontconfig libX11 libXext libXcursor libXi
    dnf install -y libXrandr libXinerama libXcomposite mesa-libGLU
    
    # Сеть
    dnf install -y cifs-utils nfs-utils
    
    # Wine
    dnf install -y wine wine.i686
    
    # Для иконок
    dnf install -y icoutils ImageMagick
    
    # Winetricks
    wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
    chmod +x winetricks
    mv winetricks /usr/local/bin/
    
    echo "Зависимости установлены"
}

install_dependencies