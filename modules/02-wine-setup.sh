#!/bin/bash
# Настройка Wine

setup_wine() {
    local user="$1"
    local home="$(getent passwd "$user" | cut -d: -f6)"
    
    echo "Настройка Wine для $user..."
    
    # Создаем префикс
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 wineboot --init 2>/dev/null
    
    # Компоненты
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
        winetricks -q corefonts vcrun6 mdac28 2>/dev/null
    
    echo "Wine настроен"
}

if [ $# -eq 1 ]; then
    setup_wine "$1"
fi