#!/bin/bash
# Копирование программы

copy_program() {
    local user="$1"
    local choice="$2"
    local home="$(getent passwd "$user" | cut -d: -f6)"
    
    echo "Копирование программы..."
    
    # Определяем какие папки копировать
    case "$choice" in
        1) FOLDERS=("StatStac" "StatPol" "StatYear") ;;
        2) FOLDERS=("RegPol" "RegPeople") ;;
        3) FOLDERS=("WrachPol" "DopDisp") ;;
        4) FOLDERS=("BolList" "DayStac" "Dispanser" "DopDisp" "OtdelStac" 
                   "Pokoy" "RegPeople" "RegPol" "StatPol" "StatStac" 
                   "StatYear" "WrachPol") ;;
        *) FOLDERS=("StatStac") ;;
    esac
    
    # Обязательные папки
    REQUIRED=("Lib" "LibDRV" "LibLinux")
    
    # Монтируем
    MNT="/tmp/medorg_mount"
    mkdir -p "$MNT"
    
    mount -t cifs //10.0.1.11/auto "$MNT" -o username=Администратор,password=Ybyjxrf30lh* || {
        echo "Ошибка подключения к сетевой шаре"
        return 1
    }
    
    # Целевая папка
    TARGET="$home/.wine_medorg/drive_c/MedCTech/MedOrg"
    mkdir -p "$TARGET"
    
    # Копируем обязательные
    for folder in "${REQUIRED[@]}"; do
        if [ -d "$MNT/$folder" ]; then
            cp -r "$MNT/$folder" "$TARGET/"
        fi
    done
    
    # Копируем выбранные
    for folder in "${FOLDERS[@]}"; do
        if [ -d "$MNT/$folder" ]; then
            cp -r "$MNT/$folder" "$TARGET/"
        fi
    done
    
    # Отключаем
    umount "$MNT"
    
    # Права
    chown -R "$user:$user" "$home/.wine_medorg"
    
    echo "Программа скопирована"
}

if [ $# -eq 2 ]; then
    copy_program "$1" "$2"
fi