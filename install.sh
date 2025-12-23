#!/bin/bash
# MedOrg Installer - РЕАЛЬНО РАБОЧАЯ ВЕРСИЯ (основана на ручной установке)
# by kubinets - https://github.com/kubinets

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Функции вывода
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}!${NC} $1"; }

# Проверка root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "Запустите с правами root: sudo $0"
    fi
}

# Получение текущего пользователя (не root)
get_current_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        # Находим первого не-root пользователя с /home директорией
        getent passwd | grep -E ':/home/' | grep -v 'nologin\|false' | cut -d: -f1 | head -1
    fi
}

# Установка зависимостей Fedora
install_dependencies() {
    log "Обновляем систему..."
    dnf update -y
    
    success "Обновление завершено"
    
    log "Устанавливаем основные зависимости..."
    dnf install -y wget cabextract p7zip p7zip-plugins unzip
    dnf install -y freetype fontconfig libX11 libXext libXcursor libXi libXrandr libXinerama libXcomposite mesa-libGLU
    dnf install -y cifs-utils nfs-utils
    
    success "Основные зависимости установлены"
    
    log "Устанавливаем Wine..."
    dnf install -y wine wine.i686
    
    success "Wine установлен"
    
    # Проверяем Wine
    log "Проверяем Wine..."
    wine --version
}

# Скачивание winetricks
install_winetricks() {
    log "Скачиваем winetricks..."
    
    if ! command -v winetricks >/dev/null 2>&1; then
        wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
        chmod +x winetricks
        mv winetricks /usr/local/bin/
        success "Winetricks установлен"
    else
        success "Winetricks уже установлен"
    fi
}

# Настройка Wine для пользователя
setup_wine_for_user() {
    local user="$1"
    local home_dir="$2"
    
    log "Настраиваем Wine для пользователя $user..."
    
    # Экспортируем переменные
    export WINEPREFIX="$home_dir/.wine_medorg"
    export WINEARCH=win32
    
    # Создаем wine prefix
    log "Создаем Wine prefix..."
    sudo -u "$user" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 winecfg &>/dev/null &
    sleep 3
    success "Wine prefix создан"
    
    # Устанавливаем компоненты через winetricks
    log "Устанавливаем компоненты Wine..."
    local components=("corefonts" "tahoma" "vcrun6" "vcrun2008" "mdac28" "jet40")
    
    for component in "${components[@]}"; do
        log "  Установка $component..."
        sudo -u "$user" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 winetricks -q "$component" 2>&1 | grep -v "fixme\|warn\|err" || true
    done
    
    success "Компоненты Wine установлены"
}

# Подключение сетевой папки и копирование
copy_programs() {
    local user="$1"
    local home_dir="$2"
    
    log "Подключаемся к сетевой папке..."
    
    # Создаем точку монтирования
    local mount_point="/mnt/medorg_share"
    mkdir -p "$mount_point"
    
    # Параметры подключения
    local server="//10.0.1.11/auto"
    local username="Администратор"
    local password="Ybyjxrf30lh*"
    
    # Монтируем
    mount -t cifs "$server" "$mount_point" -o "username=$username,password=$password,uid=$(id -u "$user"),gid=$(id -g "$user")"
    
    if [ $? -eq 0 ]; then
        success "Сетевая папка подключена"
        
        # Создаем целевую директорию
        local target_dir="$home_dir/.wine_medorg/drive_c/MedCTech/MedOrg"
        mkdir -p "$target_dir"
        chown -R "$user:$user" "$target_dir"
        
        # Копируем ВСЕ содержимое
        log "Копируем программы..."
        cp -r "$mount_point"/* "$target_dir"/
        chown -R "$user:$user" "$target_dir"/*
        
        success "Программы скопированы"
        
        # Отключаем
        umount "$mount_point"
        rmdir "$mount_point"
        
        # Показываем что скопировалось
        log "Скопированные модули:"
        ls -la "$target_dir" | head -20
    else
        error "Не удалось подключиться к сетевой папке"
    fi
}

# Исправление midas.dll (ВАЖНО!)
fix_midas() {
    local user="$1"
    local home_dir="$2"
    
    log "Исправляем midas.dll..."
    
    local wine_prefix="$home_dir/.wine_medorg"
    local lib_dir="$wine_prefix/drive_c/MedCTech/MedOrg/Lib"
    local system32="$wine_prefix/drive_c/windows/system32"
    
    # 1. Копируем midas.dll в system32
    if [ -f "$lib_dir/midas.dll" ]; then
        cp "$lib_dir/midas.dll" "$system32/"
        chown "$user:$user" "$system32/midas.dll"
        success "midas.dll скопирована в system32"
    fi
    
    # 2. Создаем ссылки
    log "Создаем ссылки..."
    cd "$lib_dir"
    
    # Создаем ссылки в Lib
    sudo -u "$user" ln -sf midas.dll MIDAS.DLL 2>/dev/null || true
    sudo -u "$user" ln -sf midas.dll Midas.dll 2>/dev/null || true
    sudo -u "$user" ln -sf midas.dll midas.DLL 2>/dev/null || true
    
    # Создаем ссылки в system32
    cd "$system32"
    sudo -u "$user" ln -sf midas.dll MIDAS.DLL 2>/dev/null || true
    sudo -u "$user" ln -sf midas.dll Midas.dll 2>/dev/null || true
    
    success "Ссылки созданы"
    
    # 3. Реестр
    log "Настраиваем реестр..."
    
    cat > /tmp/medorg_reg.reg << 'EOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine\Settings]
"INIT"="MINIMIZE RESOURCE USAGE"
EOF
    
    # Применяем реестр
    sudo -u "$user" env WINEPREFIX="$wine_prefix" WINEARCH=win32 wine regedit /tmp/medorg_reg.reg 2>/dev/null || true
    rm -f /tmp/medorg_reg.reg
    
    success "Реестр настроен"
}

# Создание скриптов запуска
create_launch_scripts() {
    local user="$1"
    local home_dir="$2"
    
    log "Создаем скрипты запуска..."
    
    local wine_prefix="$home_dir/.wine_medorg"
    local base_dir="$wine_prefix/drive_c/MedCTech/MedOrg"
    
    # Ищем все exe файлы
    find "$base_dir" -name "*.exe" -type f | while read -r exe_file; do
        local module_dir=$(dirname "$exe_file")
        local module_name=$(basename "$module_dir")
        local exe_name=$(basename "$exe_file" .exe)
        
        # Создаем скрипт запуска
        local script_path="$home_dir/start_${module_name}.sh"
        
        cat > "$script_path" << EOF
#!/bin/bash
export WINEPREFIX="$wine_prefix"
export WINEARCH=win32
export WINEDLLPATH="C:\\\\MedCTech\\\\MedOrg\\\\Lib"
export WINEDEBUG="-all"

cd "$module_dir"
wine "$(basename "$exe_file")"
EOF
        
        chmod +x "$script_path"
        chown "$user:$user" "$script_path"
        
        echo "  ✓ $module_name -> $exe_name.exe"
    done
    
    success "Скрипты запуска созданы"
}

# Создание ярлыков на рабочем столе
create_desktop_shortcuts() {
    local user="$1"
    local home_dir="$2"
    
    log "Создаем ярлыки на рабочем столе..."
    
    # Определяем рабочий стол
    local desktop_dir="$home_dir/Рабочий стол"
    [ ! -d "$desktop_dir" ] && desktop_dir="$home_dir/Desktop"
    [ ! -d "$desktop_dir" ] && mkdir -p "$desktop_dir" && chown "$user:$user" "$desktop_dir"
    
    # Создаем ярлыки для найденных скриптов
    find "$home_dir" -name "start_*.sh" -type f | while read -r script; do
        local module_name=$(basename "$script" .sh | sed 's/start_//')
        local desktop_file="$desktop_dir/$module_name.desktop"
        
        cat > "$desktop_file" << EOF
[Desktop Entry]
Name=$module_name
Comment=Медицинская программа
Exec=$script
Icon=wine
Terminal=false
Type=Application
Categories=Medical;
EOF
        
        chmod +x "$desktop_file"
        chown "$user:$user" "$desktop_file"
        
        echo "  ✓ Ярлык: $module_name"
    done
    
    success "Ярлыки созданы"
}

# Финальный фикс (из вашего скрипта)
create_final_fix() {
    local user="$1"
    local home_dir="$2"
    
    log "Создаем финальный фикс-скрипт..."
    
    cat > "$home_dir/final_fix_all.sh" << 'EOF'
#!/bin/bash
export WINEPREFIX="$HOME/.wine_medorg"

echo "=== ФИНАЛЬНЫЙ ФИКС ДЛЯ ВСЕХ МОДУЛЕЙ ==="

# 1. Создаем ссылки для регистра
echo "1. Создание ссылок для разных регистров..."
cd "$WINEPREFIX/drive_c/MedCTech/MedOrg/Lib"
ln -sf midas.dll MIDAS.DLL 2>/dev/null
ln -sf midas.dll Midas.dll 2>/dev/null
ln -sf midas.dll midas.DLL 2>/dev/null

# 2. Копируем в system32
echo "2. Копирование в system32..."
cp -f midas.dll "$WINEPREFIX/drive_c/windows/system32/" 2>/dev/null
cd "$WINEPREFIX/drive_c/windows/system32"
ln -sf midas.dll MIDAS.DLL 2>/dev/null
ln -sf midas.dll Midas.dll 2>/dev/null

# 3. В каждую папку модуля
echo "3. Копирование в папки модулей..."
for module_dir in "$WINEPREFIX/drive_c/MedCTech/MedOrg"/*/; do
    if [ -d "$module_dir" ]; then
        module=$(basename "$module_dir")
        cp -f "$WINEPREFIX/drive_c/MedCTech/MedOrg/Lib/midas.dll" "$module_dir/" 2>/dev/null
        cd "$module_dir"
        ln -sf midas.dll MIDAS.DLL 2>/dev/null
        ln -sf midas.dll Midas.dll 2>/dev/null
        echo "   ✓ $module"
    fi
done

# 4. Исправляем реестр
echo "4. Исправление реестра..."
cat > /tmp/final_fix.reg << 'REGEOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"
REGEOF

wine regedit /tmp/final_fix.reg 2>/dev/null
rm -f /tmp/final_fix.reg

echo ""
echo "=== Готово! ==="
echo "Запускайте программы через ярлыки на рабочем столе"
EOF
    
    chmod +x "$home_dir/final_fix_all.sh"
    chown "$user:$user" "$home_dir/final_fix_all.sh"
    
    success "Финальный фикс-скрипт создан: ~/final_fix_all.sh"
}

# Основная функция
main() {
    clear
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           УСТАНОВКА MEDORG (РАБОЧАЯ ВЕРСИЯ)                ║"
    echo "║         Основана на ручной установке пользователя           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Проверка прав
    check_root
    
    # Определяем пользователя
    local target_user=$(get_current_user)
    if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
        error "Не удалось определить пользователя для установки"
    fi
    
    local home_dir=$(getent passwd "$target_user" | cut -d: -f6)
    
    echo ""
    echo -e "${CYAN}Целевой пользователь:${NC} ${GREEN}$target_user${NC}"
    echo -e "${CYAN}Домашняя директория:${NC} ${YELLOW}$home_dir${NC}"
    echo ""
    
    # Подтверждение
    read -p "Продолжить установку? (Y/n): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    
    # 1. Установка зависимостей
    echo ""
    echo -e "${PURPLE}ШАГ 1: Установка зависимостей${NC}"
    echo "──────────────────────────────────"
    install_dependencies
    
    # 2. Установка winetricks
    echo ""
    echo -e "${PURPLE}ШАГ 2: Установка Winetricks${NC}"
    echo "────────────────────────────"
    install_winetricks
    
    # 3. Настройка Wine
    echo ""
    echo -e "${PURPLE}ШАГ 3: Настройка Wine${NC}"
    echo "──────────────────────"
    setup_wine_for_user "$target_user" "$home_dir"
    
    # 4. Копирование программ
    echo ""
    echo -e "${PURPLE}ШАГ 4: Копирование программ${NC}"
    echo "──────────────────────────"
    copy_programs "$target_user" "$home_dir"
    
    # 5. Исправление midas.dll
    echo ""
    echo -e "${PURPLE}ШАГ 5: Исправление midas.dll${NC}"
    echo "──────────────────────────"
    fix_midas "$target_user" "$home_dir"
    
    # 6. Создание скриптов запуска
    echo ""
    echo -e "${PURPLE}ШАГ 6: Создание скриптов запуска${NC}"
    echo "────────────────────────────────"
    create_launch_scripts "$target_user" "$home_dir"
    
    # 7. Создание ярлыков
    echo ""
    echo -e "${PURPLE}ШАГ 7: Создание ярлыков${NC}"
    echo "────────────────────────"
    create_desktop_shortcuts "$target_user" "$home_dir"
    
    # 8. Финальный фикс
    echo ""
    echo -e "${PURPLE}ШАГ 8: Финальный фикс${NC}"
    echo "────────────────────"
    create_final_fix "$target_user" "$home_dir"
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                УСТАНОВКА ЗАВЕРШЕНА!                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}ИТОГИ УСТАНОВКИ:${NC}"
    echo "────────────────"
    echo -e "Пользователь:        ${GREEN}$target_user${NC}"
    echo -e "Wine prefix:         ${YELLOW}$home_dir/.wine_medorg${NC}"
    echo -e "Программы:           ${YELLOW}$home_dir/.wine_medorg/drive_c/MedCTech/MedOrg/${NC}"
    echo ""
    
    echo -e "${CYAN}ЧТО ДЕЛАТЬ ДАЛЬШЕ:${NC}"
    echo "──────────────────"
    echo "1. Выйдите из системы root (команда: exit)"
    echo "2. Войдите в систему как пользователь: $target_user"
    echo "3. На рабочем столе появятся ярлыки программ"
    echo "4. Запускайте программы двойным кликом"
    echo ""
    
    echo -e "${CYAN}ЕСЛИ ЧТО-ТО НЕ РАБОТАЕТ:${NC}"
    echo "─────────────────────────"
    echo "1. Запустите финальный фикс:"
    echo -e "   ${YELLOW}sudo -u $target_user $home_dir/final_fix_all.sh${NC}"
    echo "2. Проверьте права:"
    echo -e "   ${YELLOW}sudo chown -R $target_user:$target_user $home_dir/.wine_medorg${NC}"
    echo ""
    
    echo -e "${GREEN}Установка завершена успешно!${NC}"
    echo ""
}

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Установка прервана${NC}"; exit 1' INT

# Запуск
main "$@"