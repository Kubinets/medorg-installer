#!/bin/bash
# Создание ярлыков

create_launchers() {
    local user="$1"
    local choice="$2"
    local home="$(getent passwd "$user" | cut -d: -f6)"
    
    echo "Создание ярлыков..."
    
    # Папка ярлыков
    DESKTOP="$home/Рабочий стол/Медицинские программы"
    sudo -u "$user" mkdir -p "$DESKTOP"
    
    # Определяем модули
    case "$choice" in
        1) MODULES=("StatStac" "StatPol" "StatYear") ;;
        2) MODULES=("RegPol" "RegPeople") ;;
        3) MODULES=("WrachPol" "DopDisp") ;;
        4) MODULES=("BolList" "DayStac" "Dispanser" "DopDisp" "OtdelStac" 
                   "Pokoy" "RegPeople" "RegPol" "StatPol" "StatStac" 
                   "StatYear" "WrachPol") ;;
        *) MODULES=("StatStac") ;;
    esac
    
    # Создаем ярлыки
    for module in "${MODULES[@]}"; do
        if [ -d "$home/.wine_medorg/drive_c/MedCTech/MedOrg/$module" ]; then
            sudo -u "$user" bash << EOF
cat > "$DESKTOP/$module.desktop" << 'DESKEOF'
[Desktop Entry]
Name=MedOrg $module
Exec=bash -c "cd '$home/.wine_medorg/drive_c/MedCTech/MedOrg/$module' && wine *.exe"
Icon=wine
Terminal=false
Type=Application
Categories=Medical;
DESKEOF
chmod +x "$DESKTOP/$module.desktop"
EOF
        fi
    done
    
    # Лаунчер
    sudo -u "$user" bash << 'EOF'
cat > "$home/medorg_launcher.sh" << 'SCRIPTEOF'
#!/bin/bash
export WINEPREFIX="$HOME/.wine_medorg"
export WINEARCH=win32

BASE="$WINEPREFIX/drive_c/MedCTech/MedOrg"
modules=()

for dir in "$BASE"/*/; do
    if [ -d "$dir" ] && ls "$dir"/*.exe 1>/dev/null 2>&1; then
        modules+=("$(basename "$dir")")
    fi
done

echo "Выберите модуль:"
for i in "${!modules[@]}"; do
    echo "$((i+1)). ${modules[i]}"
done

read -p "Ваш выбор: " choice
if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#modules[@]} ]; then
    cd "$BASE/${modules[$((choice-1))]}"
    wine *.exe
fi
SCRIPTEOF

chmod +x "$home/medorg_launcher.sh"
EOF
    
    echo "Ярлыки созданы"
}

if [ $# -eq 2 ]; then
    create_launchers "$1" "$2"
fi