#!/bin/bash
# Настройка Wine

log() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m✓\033[0m $1"; }

setup_wine() {
    local user="$1"
    local home="$2"
    
    log "Настройка Wine для $user..."
    
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
        wineboot --init 2>/dev/null
    
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
        winetricks -q corefonts vcrun6 mdac28 2>/dev/null
    
    success "Wine настроен"
}

if [ -n "$TARGET_USER" ] && [ -n "$TARGET_HOME" ]; then
    setup_wine "$TARGET_USER" "$TARGET_HOME"
fi