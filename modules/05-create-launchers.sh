#!/bin/bash
# Создание ярлыков (без лаунчера)

log() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m✓\033[0m $1"; }

create_shortcuts() {
    log "Создание ярлыков..."
    
    DESKTOP="$TARGET_HOME/Рабочий стол/Медицинские программы"
    sudo -u "$TARGET_USER" mkdir -p "$DESKTOP"
    
    # Создаем ярлыки для выбранных модулей
    ALL_MODULES_FOR_SHORTCUTS=("${SELECTED_MODULES[@]}")
    
    for module in "${ALL_MODULES_FOR_SHORTCUTS[@]}"; do
        if [ -d "$TARGET_HOME/.wine_medorg/drive_c/MedCTech/MedOrg/$module" ]; then
            sudo -u "$TARGET_USER" bash << EOF
cat > "$DESKTOP/${module}.desktop" << 'DESKEOF'
[Desktop Entry]
Name=MedOrg $module
Exec=bash -c "export WINEPREFIX='$TARGET_HOME/.wine_medorg' && export WINEARCH=win32 && cd '$TARGET_HOME/.wine_medorg/drive_c/MedCTech/MedOrg/$module' && wine *.exe"
Icon=wine
Terminal=false
Type=Application
Categories=Medical;
DESKEOF
chmod +x "$DESKTOP/${module}.desktop"
EOF
            log "  Ярлык: $module"
        fi
    done
    
    success "Ярлыки созданы в: $DESKTOP"
}

if [ -n "$TARGET_USER" ] && [ -n "$TARGET_HOME" ] && [ -n "$SELECTED_MODULES" ]; then
    create_shortcuts
fi