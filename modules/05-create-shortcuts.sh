#!/bin/bash
# Создание ярлыков - исправленная версия (только установленные модули)

set -e

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
warning() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# Проверка окружения
check_environment() {
    log "Проверка окружения..."
    
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        error "Переменные TARGET_USER и TARGET_HOME не установлены"
        exit 1
    fi
    
    USER="$TARGET_USER"
    HOME_DIR="$TARGET_HOME"
    
    if ! id "$USER" &>/dev/null; then
        error "Пользователь $USER не существует"
        exit 1
    fi
    
    success "Параметры проверены"
    log "Пользователь: $USER"
    log "Домашняя директория: $HOME_DIR"
}

# Определение пути к рабочему столу
get_desktop_path() {
    log "Определение пути к рабочему столу..."
    
    # Пробуем разные варианты
    local desktop_paths=(
        "$HOME_DIR/Рабочий стол"
        "$HOME_DIR/Desktop" 
        "$HOME_DIR/рабочий стол"
        "$HOME_DIR/desktop"
    )
    
    for path in "${desktop_paths[@]}"; do
        if [ -d "$path" ]; then
            DESKTOP_DIR="$path"
            success "Найден рабочий стол: $DESKTOP_DIR"
            return 0
        fi
    done
    
    # Если не нашли, создаем стандартный
    DESKTOP_DIR="$HOME_DIR/Рабочий стол"
    mkdir -p "$DESKTOP_DIR"
    chown "$USER:$USER" "$DESKTOP_DIR"
    warning "Создан рабочий стол: $DESKTOP_DIR"
}

# Проверка инструментов для иконок
check_icon_tools() {
    log "Проверка инструментов для работы с иконками..."
    
    if command -v wrestool >/dev/null 2>&1 && command -v convert >/dev/null 2>&1; then
        HAS_ICON_TOOLS=true
        success "Инструменты для иконок доступны"
    else
        HAS_ICON_TOOLS=false
        warning "Инструменты для иконок недоступны"
        log "Установите: sudo dnf install icoutils ImageMagick"
    fi
}

# Извлечение иконок из EXE файлов (только для установленных модулей)
extract_icons() {
    local install_dir="$1"
    local icon_dir="$2"
    
    if [ "$HAS_ICON_TOOLS" != true ]; then
        return
    fi
    
    log "Извлечение иконок из EXE файлов..."
    
    # Создаем директории для иконок
    mkdir -p "$icon_dir/64"
    mkdir -p "$icon_dir/32"
    mkdir -p "$icon_dir/16"
    
    # Получаем список установленных модулей
    local installed_modules=()
    if [ -d "$install_dir" ]; then
        for dir in "$install_dir"/*/; do
            local module_name=$(basename "$dir")
            # Исключаем служебные модули
            if [[ "$module_name" != "Lib" && "$module_name" != "LibDRV" && "$module_name" != "LibLinux" ]]; then
                installed_modules+=("$module_name")
            fi
        done
    fi
    
    # Извлекаем иконки только для установленных модулей
    for module_name in "${installed_modules[@]}"; do
        local module_dir="$install_dir/$module_name"
        
        # Ищем EXE файл в папке модуля
        local exe_file=$(find "$module_dir" -maxdepth 1 -name "*.exe" -type f | head -1)
        
        if [ -n "$exe_file" ]; then
            echo -n "  $module_name... "
            
            # Извлекаем иконку
            cd "$(dirname "$exe_file")"
            if wrestool -x -o "/tmp/${module_name}_icon.ico" "$(basename "$exe_file")" 2>/dev/null; then
                # Конвертируем в PNG
                if convert "/tmp/${module_name}_icon.ico[0]" "$icon_dir/64/${module_name}.png" 2>/dev/null; then
                    convert "$icon_dir/64/${module_name}.png" -resize 32x32 "$icon_dir/32/${module_name}.png" 2>/dev/null
                    convert "$icon_dir/64/${module_name}.png" -resize 16x16 "$icon_dir/16/${module_name}.png" 2>/dev/null
                    echo -e "${GREEN}✓${NC}"
                else
                    echo -e "${YELLOW}!${NC}"
                fi
                rm -f "/tmp/${module_name}_icon.ico"
            else
                echo -e "${YELLOW}!${NC}"
            fi
        fi
    done
    
    # Устанавливаем права
    chown -R "$USER:$USER" "$icon_dir" 2>/dev/null || true
}

# Получение пути к иконке
get_icon_path() {
    local module_name="$1"
    local icon_dir="$2"
    
    if [ "$HAS_ICON_TOOLS" = true ] && [ -f "$icon_dir/32/${module_name}.png" ]; then
        echo "$icon_dir/32/${module_name}.png"
    elif [ -f "/usr/share/icons/gnome/32x32/apps/wine.png" ]; then
        echo "/usr/share/icons/gnome/32x32/apps/wine.png"
    else
        echo "wine"
    fi
}

# Создание ярлыков (только для установленных модулей)
create_shortcuts() {
    log "Создание ярлыков..."
    
    local install_dir="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    local icon_dir="$HOME_DIR/.local/share/icons/medorg"
    
    # Создаем папку для ярлыков
    local program_dir="$DESKTOP_DIR/Медицинские программы"
    mkdir -p "$program_dir"
    chown -R "$USER:$USER" "$program_dir"
    
    success "Папка для ярлыков создана: $program_dir"
    
    # Извлекаем иконки
    extract_icons "$install_dir" "$icon_dir"
    
    # Проверяем наличие установленных модулей
    if [ ! -d "$install_dir" ]; then
        warning "Директория с программами не найдена: $install_dir"
        return
    fi
    
    # Получаем список установленных модулей (кроме служебных)
    local installed_modules=()
    for dir in "$install_dir"/*/; do
        local module_name=$(basename "$dir")
        # Исключаем служебные модули
        if [[ "$module_name" != "Lib" && "$module_name" != "LibDRV" && "$module_name" != "LibLinux" ]]; then
            installed_modules+=("$module_name")
        fi
    done
    
    if [ ${#installed_modules[@]} -eq 0 ]; then
        warning "Нет установленных модулей (кроме служебных)"
        return
    fi
    
    log "Найдены модули: ${installed_modules[*]}"
    
    # Создаем ярлыки для каждого установленного модуля
    local created=0
    for module_name in "${installed_modules[@]}"; do
        local module_dir="$install_dir/$module_name"
        
        # Ищем EXE файл в папке модуля
        local exe_file=$(find "$module_dir" -maxdepth 1 -name "*.exe" -type f | head -1)
        
        if [ -z "$exe_file" ]; then
            warning "EXE файл не найден в модуле $module_name"
            continue
        fi
        
        local exe_name=$(basename "$exe_file" .exe)
        
        # Получаем путь к иконке
        local icon_path=$(get_icon_path "$module_name" "$icon_dir")
        
        # Создаем скрипт запуска
        local script_path="$program_dir/$module_name.sh"
        
        cat > "$script_path" << EOF
#!/bin/bash
export WINEPREFIX="$HOME_DIR/.wine_medorg"
export WINEARCH=win32
export WINEDLLPATH="C:\\\\MedCTech\\\\MedOrg\\\\Lib"
export WINEDEBUG="-all"

cd "$module_dir"
wine "$(basename "$exe_file")"
EOF
        
        chmod +x "$script_path"
        chown "$USER:$USER" "$script_path"
        
        # Создаем .desktop файл
        local desktop_file="$program_dir/$module_name.desktop"
        
        cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$module_name
Comment=Медицинская программа
Exec=$script_path
Icon=$icon_path
Terminal=false
Categories=Medical;
StartupWMClass=$exe_name.exe
EOF
        
        chmod +x "$desktop_file"
        chown "$USER:$USER" "$desktop_file"
        
        created=$((created + 1))
        echo -e "  ${GREEN}✓${NC} $module_name"
    done
    
    if [ $created -gt 0 ]; then
        success "Создано ярлыков: $created"
    else
        warning "Не удалось создать ярлыки"
    fi
}

# Создание вспомогательных скриптов
create_helper_scripts() {
    log "Создание вспомогательных скриптов..."
    
    local script_dir="$HOME_DIR"
    
    # Скрипт исправления прав
    cat > "$script_dir/Исправить_права.sh" << EOF
#!/bin/bash
echo "Исправление прав доступа..."
chown -R $USER:$USER ~/.wine_medorg
chmod -R 755 ~/.wine_medorg
echo "Готово!"
EOF
    
    chmod +x "$script_dir/Исправить_права.sh"
    chown "$USER:$USER" "$script_dir/Исправить_права.sh"
    
    # Скрипт обновления ярлыков
    cat > "$script_dir/Обновить_ярлыки.sh" << EOF
#!/bin/bash
echo "Обновление ярлыков медицинских программ..."
echo ""

# Удаляем старую папку с ярлыками
rm -rf "\$HOME/Рабочий стол/Медицинские программы" 2>/dev/null
rm -rf "\$HOME/Desktop/Медицинские программы" 2>/dev/null

# Запускаем создание ярлыков
if [ -f "/tmp/medorg_create_shortcuts.sh" ]; then
    bash /tmp/medorg_create_shortcuts.sh
else
    echo "Ошибка: скрипт создания ярлыков не найден"
    echo "Переустановите программы: curl -sSL https://raw.githubusercontent.com/kubinets/medorg-installer/main/install.sh | sudo bash"
fi
EOF
    
    chmod +x "$script_dir/Обновить_ярлыки.sh"
    chown "$USER:$USER" "$script_dir/Обновить_ярлыки.sh"
    
    success "Вспомогательные скрипты созданы"
}

# Основная функция
main() {
    echo ""
    echo -e "${CYAN}СОЗДАНИЕ ЯРЛЫКОВ И СКРИПТОВ${NC}"
    echo ""
    
    # Проверка окружения
    check_environment
    
    # Определение рабочего стола
    get_desktop_path
    
    # Проверка инструментов для иконок
    check_icon_tools
    
    # Создание ярлыков (только для установленных модулей)
    create_shortcuts
    
    # Создание вспомогательных скриптов
    create_helper_scripts
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      ЯРЛЫКИ УСПЕШНО СОЗДАНЫ!                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Расположение:${NC}"
    echo -e "${BLUE}─────────────${NC}"
    echo -e "  ${GREEN}•${NC} Папка с ярлыками: ${YELLOW}$DESKTOP_DIR/Медицинские программы/${NC}"
    echo -e "  ${GREEN}•${NC} Иконки программ: ${YELLOW}$HOME_DIR/.local/share/icons/medorg/${NC}"
    echo -e "  ${GREEN}•${NC} Исходные программы: ${YELLOW}$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg/${NC}"
    echo ""
    
    echo -e "${CYAN}Вспомогательные скрипты:${NC}"
    echo -e "${BLUE}───────────────────────${NC}"
    echo -e "  ${GREEN}•${NC} Исправить_права.sh - исправление прав доступа"
    echo -e "  ${GREEN}•${NC} Обновить_ярлыки.sh - повторное создание ярлыков"
    echo ""
    
    echo -e "${CYAN}Для запуска:${NC}"
    echo -e "${BLUE}────────────${NC}"
    echo "1. Войдите как пользователь: $USER"
    echo "2. На рабочем столе откройте папку 'Медицинские программы'"
    echo "3. Запускайте программы двойным кликом по ярлыкам"
    echo ""
}

# Обработка прерывания
trap 'echo -e "\n${RED}Создание ярлыков прервано${NC}"; exit 1' INT

# Запуск
main "$@"