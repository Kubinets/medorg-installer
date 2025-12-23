#!/bin/bash
# MedOrg Installer v2.1
# Выборочная установка модулей MedOrg

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
INSTALL_DIR="/tmp/medorg-installer-$$"

# Функции вывода
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Списки папок
REQUIRED_FOLDERS=("Lib" "LibDRV" "LibLinux")  # Обязательные (всегда копируются)
OPTIONAL_FOLDERS=("BolList" "DayStac" "Dispanser" "DopDisp" "OtdelStac" 
                  "Pokoy" "RegPeople" "RegPol" "StatPol" "StatStac" 
                  "StatYear" "WrachPol")  # Опциональные (по выбору)

# Проверка прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Запустите с правами root: sudo $0"
        exit 1
    fi
}

# Выбор пользователя
select_user() {
    echo ""
    echo "╔════════════════════════════════════════════════════╗"
    echo "║         Установка медицинской программы           ║"
    echo "║                  MedOrg v2.1                       ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""
    
    # Автоопределение пользователя
    if [ -n "$SUDO_USER" ]; then
        DEFAULT_USER="$SUDO_USER"
    else
        DEFAULT_USER=$(logname 2>/dev/null || echo "")
    fi
    
    if [ -z "$DEFAULT_USER" ] || [ "$DEFAULT_USER" = "root" ]; then
        DEFAULT_USER="meduser"
    fi
    
    read -p "Введите имя пользователя для установки [$DEFAULT_USER]: " TARGET_USER
    TARGET_USER=${TARGET_USER:-$DEFAULT_USER}
    
    # Проверка существования пользователя
    if ! id "$TARGET_USER" &>/dev/null; then
        log_warning "Пользователь '$TARGET_USER' не существует!"
        read -p "Создать пользователя '$TARGET_USER'? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            useradd -m -s /bin/bash "$TARGET_USER"
            echo "Установите пароль для нового пользователя:"
            passwd "$TARGET_USER"
            log_success "Пользователь '$TARGET_USER' создан"
        else
            log_error "Установка отменена"
            exit 1
        fi
    fi
    
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    log_success "Установка для пользователя: $TARGET_USER"
    log_success "Домашняя директория: $TARGET_HOME"
}

# Выбор опциональных модулей
select_optional_modules() {
    echo ""
    echo "╔════════════════════════════════════════════════════╗"
    echo "║         ВЫБОР ДОПОЛНИТЕЛЬНЫХ МОДУЛЕЙ              ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""
    echo "Обязательные модули (будут установлены автоматически):"
    echo "  ${REQUIRED_FOLDERS[*]}"
    echo ""
    echo "Выберите дополнительные модули:"
    echo ""
    
    # Отображаем опциональные модули с номерами
    declare -A module_names
    module_names=(
        ["1"]="BolList" ["2"]="DayStac" ["3"]="Dispanser" ["4"]="DopDisp"
        ["5"]="OtdelStac" ["6"]="Pokoy" ["7"]="RegPeople" ["8"]="RegPol"
        ["9"]="StatPol" ["10"]="StatStac" ["11"]="StatYear" ["12"]="WrachPol"
    )
    
    # Показываем меню
    for i in {1..12}; do
        folder="${module_names[$i]}"
        echo "  $i. $folder"
    done
    
    echo ""
    echo "  13. Все дополнительные модули"
    echo "  14. Без дополнительных модулей"
    echo ""
    
    SELECTED_MODULES=()
    
    while true; do
        read -p "Введите номера через пробел (1-14): " choices
        
        if [ -z "$choices" ]; then
            log_warning "Не сделан выбор!"
            continue
        fi
        
        # Обрабатываем выбор
        for choice in $choices; do
            case $choice in
                13)  # Все модули
                    SELECTED_MODULES=("${OPTIONAL_FOLDERS[@]}")
                    echo ""
                    log_success "Выбраны ВСЕ дополнительные модули"
                    return
                    ;;
                14)  # Без дополнительных
                    SELECTED_MODULES=()
                    echo ""
                    log_success "Без дополнительных модулей"
                    return
                    ;;
                [1-9]|1[0-2])  # Номера 1-12
                    folder="${module_names[$choice]}"
                    SELECTED_MODULES+=("$folder")
                    ;;
                *)
                    log_warning "Неверный выбор: $choice"
                    continue 2
                    ;;
            esac
        done
        
        # Удаляем дубликаты
        SELECTED_MODULES=($(echo "${SELECTED_MODULES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        
        if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            break
        else
            log_warning "Не выбрано ни одного модуля!"
        fi
    done
    
    echo ""
    log_success "Выбраны дополнительные модули:"
    for module in "${SELECTED_MODULES[@]}"; do
        echo "  • $module"
    done
}

# Установка зависимостей
install_dependencies() {
    log_info "Установка системных зависимостей..."
    
    # Обновление системы
    dnf update -y || log_warning "Не удалось обновить систему"
    
    # Основные утилиты
    dnf install -y wget curl cabextract p7zip unzip tar
    
    # Графические библиотеки
    dnf install -y freetype fontconfig libX11 libXext libXcursor libXi \
                   libXrandr libXinerama libXcomposite mesa-libGLU
    
    # Сетевые утилиты
    dnf install -y cifs-utils nfs-utils
    
    # Wine
    dnf install -y wine wine.i686
    
    # Для иконок
    dnf install -y icoutils ImageMagick
    
    # Winetricks
    if [ ! -f /usr/local/bin/winetricks ]; then
        wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
        chmod +x winetricks
        mv winetricks /usr/local/bin/
    fi
    
    log_success "Зависимости установлены"
}

# Настройка Wine
setup_wine() {
    local user="$1"
    local home="$2"
    
    log_info "Настройка Wine..."
    
    # Создаем Wine префикс
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 wineboot --init 2>/dev/null
    
    # Устанавливаем компоненты через winetricks
    log_info "Установка компонентов Wine..."
    
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
        winetricks -q corefonts 2>/dev/null || true
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
        winetricks -q vcrun6 2>/dev/null || true
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
        winetricks -q mdac28 2>/dev/null || true
    
    log_success "Wine настроен"
}

# Копирование файлов
copy_files() {
    local user="$1"
    local home="$2"
    
    log_info "Подключение к сетевой шаре..."
    
    # Создаем точку монтирования
    MOUNT_POINT="/tmp/medorg_mount_$$"
    mkdir -p "$MOUNT_POINT"
    
    # Монтируем сетевую шару
    if mount -t cifs //10.0.1.11/auto "$MOUNT_POINT" -o username=Администратор,password=Ybyjxrf30lh* 2>/dev/null; then
        log_success "Сетевая шара подключена"
        
        # Создаем целевую директорию
        TARGET_DIR="$home/.wine_medorg/drive_c/MedCTech/MedOrg"
        mkdir -p "$TARGET_DIR"
        
        # ВСЕГДА копируем обязательные папки
        log_info "Копирование обязательных папок:"
        for folder in "${REQUIRED_FOLDERS[@]}"; do
            if [ -d "$MOUNT_POINT/$folder" ]; then
                cp -r "$MOUNT_POINT/$folder" "$TARGET_DIR/"
                log_info "  ✓ $folder"
            else
                log_warning "  ✗ $folder не найдена"
            fi
        done
        
        # Копируем выбранные опциональные папки
        if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            log_info "Копирование выбранных модулей:"
            for folder in "${SELECTED_MODULES[@]}"; do
                if [ -d "$MOUNT_POINT/$folder" ]; then
                    cp -r "$MOUNT_POINT/$folder" "$TARGET_DIR/"
                    log_info "  ✓ $folder"
                else
                    log_warning "  ✗ $folder не найдена"
                fi
            done
        fi
        
        # Копируем midasregMedOrg.cmd если есть
        if [ -f "$MOUNT_POINT/midasregMedOrg.cmd" ]; then
            cp "$MOUNT_POINT/midasregMedOrg.cmd" "$TARGET_DIR/"
        fi
        
        # Права доступа
        chown -R "$user:$user" "$home/.wine_medorg"
        
        # Отключаем шару
        umount "$MOUNT_POINT"
        rmdir "$MOUNT_POINT"
        
        log_success "Файлы скопированы"
    else
        log_error "Не удалось подключиться к сетевой шаре!"
        log_info "Убедитесь что:"
        echo "  1. Сервер 10.0.1.11 доступен"
        echo "  2. Логин/пароль правильные"
        echo "  3. Папка 'auto' существует на сервере"
        exit 1
    fi
}

# Регистрация библиотек
register_libraries() {
    local user="$1"
    local home="$2"
    
    log_info "Регистрация библиотек..."
    
    sudo -u "$user" bash << USER_EOF
export WINEPREFIX="\$HOME/.wine_medorg"
export WINEARCH=win32

# Копируем midas.dll
if [ -f "\$WINEPREFIX/drive_c/MedCTech/MedOrg/Lib/midas.dll" ]; then
    cp "\$WINEPREFIX/drive_c/MedCTech/MedOrg/Lib/midas.dll" "\$WINEPREFIX/drive_c/windows/system32/"
    log_info "midas.dll скопирована"
fi

# Регистрируем в реестре
cat > /tmp/medorg_reg.reg << 'REGEOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\\\windows\\\\system32"
"CONFIGFILE01"="C:\\\\windows\\\\system32\\\\DBE.CFG"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\\\windows\\\\system32"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Borland\Database Engine]
"DLLPATH"="C:\\\\windows\\\\system32"
REGEOF

wine regedit /tmp/medorg_reg.reg 2>/dev/null
rm -f /tmp/medorg_reg.reg

USER_EOF
    
    log_success "Библиотеки зарегистрированы"
}

# Создание ярлыков
create_launchers() {
    local user="$1"
    local home="$2"
    
    log_info "Создание ярлыков..."
    
    # Создаем рабочий стол
    DESKTOP_DIR="$home/Рабочий стол"
    MEDORG_DESKTOP="$DESKTOP_DIR/Медицинские программы"
    
    sudo -u "$user" mkdir -p "$MEDORG_DESKTOP"
    
    # Создаем ярлыки для выбранных модулей
    ALL_MODULES=("${SELECTED_MODULES[@]}")
    
    for module in "${ALL_MODULES[@]}"; do
        # Проверяем что папка существует
        if [ -d "$home/.wine_medorg/drive_c/MedCTech/MedOrg/$module" ]; then
            sudo -u "$user" bash << USER_EOF
cat > "$MEDORG_DESKTOP/${module}.desktop" << 'DESKTOPEOF'
[Desktop Entry]
Name=MedOrg ${module}
Comment=Модуль ${module}
Exec=bash -c "cd '$home/.wine_medorg/drive_c/MedCTech/MedOrg/${module}' && wine *.exe"
Icon=wine
Terminal=false
Type=Application
Categories=Medical;
DESKTOPEOF
chmod +x "$MEDORG_DESKTOP/${module}.desktop"
USER_EOF
            
            log_info "  Создан ярлык: $module"
        fi
    done
    
    # Создаем лаунчер
    sudo -u "$user" bash << 'USER_EOF'
cat > "$home/medorg_launcher.sh" << 'LAUNCHEREOF'
#!/bin/bash
export WINEPREFIX="\$HOME/.wine_medorg"
export WINEARCH=win32

BASE="\$WINEPREFIX/drive_c/MedCTech/MedOrg"
modules=()

# Находим модули с exe файлами
for dir in "\$BASE"/*/; do
    if [ -d "\$dir" ] && [ -n "\$(find "\$dir" -name '*.exe' -type f 2>/dev/null)" ]; then
        modules+=("\$(basename "\$dir")")
    fi
done

if [ \${#modules[@]} -eq 0 ]; then
    echo "Модули не найдены!"
    exit 1
fi

echo "=== MedOrg Launcher ==="
echo ""
for i in "\${!modules[@]}"; do
    echo "\$((i+1)). \${modules[\$i]}"
done

echo ""
read -p "Выберите модуль (1-\${#modules[@]}): " choice

if [[ "\$choice" =~ ^[0-9]+\$ ]] && [ "\$choice" -ge 1 ] && [ "\$choice" -le \${#modules[@]} ]; then
    cd "\$BASE/\${modules[\$((choice-1))]}"
    wine *.exe
fi
LAUNCHEREOF

chmod +x "$home/medorg_launcher.sh"

# Ярлык лаунчера
cat > "$MEDORG_DESKTOP/MedOrg_Launcher.desktop" << 'DESKTOPEOF'
[Desktop Entry]
Name=MedOrg Launcher
Comment=Запуск всех модулей
Exec=$home/medorg_launcher.sh
Icon=wine
Terminal=true
Type=Application
Categories=Medical;
DESKTOPEOF
chmod +x "$MEDORG_DESKTOP/MedOrg_Launcher.desktop"
USER_EOF
    
    log_success "Ярлыки созданы в: $MEDORG_DESKTOP"
}

# Извлечение иконок
extract_icons() {
    local user="$1"
    local home="$2"
    
    log_info "Извлечение иконок..."
    
    sudo -u "$user" bash << 'USER_EOF'
export WINEPREFIX="\$HOME/.wine_medorg"
ICON_DIR="\$HOME/.local/share/icons/medorg"

mkdir -p "\$ICON_DIR/64"

ALL_MODULES=(${SELECTED_MODULES[@]})

for module in "\${ALL_MODULES[@]}"; do
    module_path="\$WINEPREFIX/drive_c/MedCTech/MedOrg/\$module"
    exe_file=\$(find "\$module_path" -name "*.exe" -type f | head -1)
    
    if [ -n "\$exe_file" ]; then
        cd "\$module_path"
        if wrestool -x -o /tmp/\${module}.ico "\$(basename "\$exe_file")" 2>/dev/null; then
            if magick /tmp/\${module}.ico "\$ICON_DIR/64/\${module}.png" 2>/dev/null; then
                # Обновляем ярлык
                if [ -f "$MEDORG_DESKTOP/\${module}.desktop" ]; then
                    sed -i "s|^Icon=.*|Icon=\$ICON_DIR/64/\${module}.png|" "$MEDORG_DESKTOP/\${module}.desktop"
                fi
            fi
            rm -f /tmp/\${module}.ico
        fi
    fi
done
USER_EOF
    
    log_success "Иконки извлечены"
}

# Завершение установки
finish_installation() {
    echo ""
    echo "╔════════════════════════════════════════════════════╗"
    echo "║        УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!               ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""
    echo "Установлено для пользователя: $TARGET_USER"
    echo ""
    echo "Обязательные модули:"
    for folder in "${REQUIRED_FOLDERS[@]}"; do
        echo "  ✓ $folder"
    done
    echo ""
    
    if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
        echo "Дополнительные модули:"
        for module in "${SELECTED_MODULES[@]}"; do
            echo "  ✓ $module"
        done
        echo ""
    fi
    
    echo "Ярлыки созданы в:"
    echo "  $TARGET_HOME/Рабочий стол/Медицинские программы/"
    echo ""
    echo "Для запуска:"
    echo "  1. Войдите как пользователь '$TARGET_USER'"
    echo "  2. На рабочем столе откройте 'Медицинские программы'"
    echo "  3. Запустите нужный модуль двойным кликом"
    echo ""
    echo "Или из терминала:"
    echo "  sudo -u $TARGET_USER -i"
    echo "  ~/medorg_launcher.sh"
    echo ""
}

# Основной процесс
main() {
    check_root
    select_user
    select_optional_modules
    install_dependencies
    setup_wine "$TARGET_USER" "$TARGET_HOME"
    copy_files "$TARGET_USER" "$TARGET_HOME"
    register_libraries "$TARGET_USER" "$TARGET_HOME"
    create_launchers "$TARGET_USER" "$TARGET_HOME"
    extract_icons "$TARGET_USER" "$TARGET_HOME"
    finish_installation
    
    # Очистка
    rm -rf "$INSTALL_DIR" 2>/dev/null
}

# Запуск
main "$@"