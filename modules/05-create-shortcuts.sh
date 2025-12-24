#!/bin/bash
# Создание ярлыков - улучшенная версия с извлечением иконок

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
    
    # Пробуем разные варианты с учетом возможных кавычек
    local desktop_paths=(
        "$HOME_DIR/Рабочий стол"
        "$HOME_DIR/Desktop" 
        "$HOME_DIR/рабочий стол"
        "$HOME_DIR/desktop"
        "$HOME_DIR/'Рабочий стол'"
    )
    
    # Удаляем кавычки для проверки существования
    for path in "${desktop_paths[@]}"; do
        # Удаляем одинарные кавычки
        clean_path="${path//\'/}"
        # Удаляем двойные кавычки
        clean_path="${clean_path//\"/}"
        
        if [ -d "$clean_path" ]; then
            DESKTOP_DIR="$clean_path"
            success "Найден рабочий стол: $DESKTOP_DIR"
            return 0
        fi
    done
    
    # Если не нашли, создаем стандартный (без кавычек)
    DESKTOP_DIR="$HOME_DIR/Desktop"
    mkdir -p "$DESKTOP_DIR"
    chown "$USER:$USER" "$DESKTOP_DIR"
    warning "Создан рабочий стол: $DESKTOP_DIR"
}

# Проверка наличия инструментов для извлечения иконок
check_icon_tools() {
    log "Проверка инструментов для работы с иконками..."
    
    HAS_WRESTOOL=false
    HAS_CONVERT=false
    
    if command -v wrestool >/dev/null 2>&1; then
        HAS_WRESTOOL=true
        echo -e "  ${GREEN}✓${NC} wrestool найден"
    else
        echo -e "  ${YELLOW}!${NC} wrestool не найден (установите: sudo dnf install icoutils)"
    fi
    
    if command -v convert >/dev/null 2>&1; then
        HAS_CONVERT=true
        echo -e "  ${GREEN}✓${NC} convert (ImageMagick) найден"
    else
        echo -e "  ${YELLOW}!${NC} ImageMagick не найден (установите: sudo dnf install ImageMagick)"
    fi
    
    if [ "$HAS_WRESTOOL" = true ] && [ "$HAS_CONVERT" = true ]; then
        CAN_EXTRACT_ICONS=true
        success "Все инструменты для извлечения иконок доступны"
    else
        CAN_EXTRACT_ICONS=false
        warning "Не все инструменты для извлечения иконок доступны"
        log "Будут использоваться стандартные иконки Wine"
    fi
}

# Извлечение иконок из EXE файлов
extract_exe_icons() {
    local install_dir="$1"
    local icon_dir="$2"
    
    if [ "$CAN_EXTRACT_ICONS" != true ]; then
        return
    fi
    
    log "Извлечение иконок из EXE файлов..."
    
    # Создаем директории для иконок
    mkdir -p "$icon_dir/64"
    mkdir -p "$icon_dir/48"
    mkdir -p "$icon_dir/32"
    mkdir -p "$icon_dir/16"
    
    # Ищем все поддиректории с .exe файлами
    find "$install_dir" -type f -name "*.exe" | while read -r exe_file; do
        local module_dir=$(dirname "$exe_file")
        local module_name=$(basename "$module_dir")
        local exe_name=$(basename "$exe_file" .exe)
        
        # Пропускаем, если уже есть иконка для этого модуля
        if [ -f "$icon_dir/64/$module_name.png" ]; then
            continue
        fi
        
        echo -n "  $module_name... "
        
        # Извлекаем иконку во временный файл
        local temp_ico="/tmp/${module_name}_icon_$$.ico"
        cd "$module_dir"
        
        if wrestool -x -o "$temp_ico" "$exe_name.exe" 2>/dev/null; then
            # Конвертируем в PNG разных размеров
            if [ -f "$temp_ico" ]; then
                # Извлекаем первое изображение из ICO (самое большое)
                convert "$temp_ico[0]" "$icon_dir/64/${module_name}.png" 2>/dev/null && \
                convert "$icon_dir/64/${module_name}.png" -resize 48x48 "$icon_dir/48/${module_name}.png" 2>/dev/null && \
                convert "$icon_dir/64/${module_name}.png" -resize 32x32 "$icon_dir/32/${module_name}.png" 2>/dev/null && \
                convert "$icon_dir/64/${module_name}.png" -resize 16x16 "$icon_dir/16/${module_name}.png" 2>/dev/null
                
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}!${NC}"
            fi
            
            # Удаляем временный файл
            rm -f "$temp_ico"
        else
            echo -e "${YELLOW}!${NC}"
        fi
    done
    
    # Устанавливаем права на иконки
    chown -R "$USER:$USER" "$icon_dir"
    
    success "Иконки извлечены в: $icon_dir/"
}

# Получение пути к иконке для модуля
get_module_icon() {
    local module_name="$1"
    local icon_dir="$2"
    
    # Пробуем разные размеры иконок
    local icon_sizes=("64" "48" "32" "16")
    
    for size in "${icon_sizes[@]}"; do
        if [ -f "$icon_dir/$size/${module_name}.png" ]; then
            echo "$icon_dir/$size/${module_name}.png"
            return 0
        fi
    done
    
    # Если не нашли извлеченную иконку, используем стандартные варианты
    if [ -f "/usr/share/icons/gnome/32x32/apps/wine.png" ]; then
        echo "/usr/share/icons/gnome/32x32/apps/wine.png"
    elif [ -f "/usr/share/icons/hicolor/32x32/apps/wine.png" ]; then
        echo "/usr/share/icons/hicolor/32x32/apps/wine.png"
    else
        echo "wine"  # Используем системное имя иконки
    fi
}

# Поиск и создание ярлыков
create_shortcuts() {
    log "Создание ярлыков..."
    
    local install_dir="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    local icon_dir="$HOME_DIR/.local/share/icons/medorg"
    
    if [ ! -d "$install_dir" ]; then
        warning "Директория с программами не найдена: $install_dir"
        return
    fi
    
    # Извлекаем иконки перед созданием ярлыков
    extract_exe_icons "$install_dir" "$icon_dir"
    
    # Создаем папку для ярлыков (без кавычек в пути)
    local program_dir="$DESKTOP_DIR/Медицинские программы"
    mkdir -p "$program_dir"
    chown -R "$USER:$USER" "$program_dir"
    
    success "Папка для ярлыков создана: $program_dir"
    
    # Ищем все exe файлы
    local created=0
    find "$install_dir" -name "*.exe" -type f | while read -r exe_file; do
        local module_dir=$(dirname "$exe_file")
        local module_name=$(basename "$module_dir")
        local exe_name=$(basename "$exe_file" .exe)
        
        # Получаем путь к иконке
        local icon_path=$(get_module_icon "$module_name" "$icon_dir")
        
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
        
        # Показываем какие иконки удалось извлечь
        echo ""
        log "Извлеченные иконки:"
        if [ -d "$icon_dir/64" ]; then
            ls "$icon_dir/64"/*.png 2>/dev/null | xargs -I {} basename {} .png | tr '\n' ' ' | fold -s
            echo ""
        fi
    else
        warning "Не найдено .exe файлов для создания ярлыков"
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
    success "Создан: Исправить_права.sh"
    
    # Скрипт обновления иконок
    cat > "$script_dir/Обновить_иконки.sh" << EOF
#!/bin/bash
# Скрипт для извлечения иконок из EXE файлов

export WINEPREFIX="\$HOME/.wine_medorg"
BASE_PATH="\$WINEPREFIX/drive_c/MedCTech/MedOrg"
ICON_DIR="\$HOME/.local/share/icons/medorg"

# Создаем директории для иконок
mkdir -p "\$ICON_DIR/64"
mkdir -p "\$ICON_DIR/48"
mkdir -p "\$ICON_DIR/32"
mkdir -p "\$ICON_DIR/16"

echo "Извлечение иконок из EXE файлов..."
echo ""

# Ищем все EXE файлы
find "\$BASE_PATH" -name "*.exe" -type f | while read -r exe_file; do
    module_dir=\$(dirname "\$exe_file")
    module_name=\$(basename "\$module_dir")
    exe_name=\$(basename "\$exe_file" .exe)
    
    echo -n "  \$module_name... "
    
    # Извлекаем иконку
    cd "\$module_dir"
    
    if wrestool -x -o /tmp/\${module_name}_icon.ico "\$exe_name.exe" 2>/dev/null; then
        # Конвертируем в PNG разных размеров
        if command -v convert &> /dev/null; then
            convert /tmp/\${module_name}_icon.ico[0] "\$ICON_DIR/64/\${module_name}.png" 2>/dev/null
            convert "\$ICON_DIR/64/\${module_name}.png" -resize 48x48 "\$ICON_DIR/48/\${module_name}.png" 2>/dev/null
            convert "\$ICON_DIR/64/\${module_name}.png" -resize 32x32 "\$ICON_DIR/32/\${module_name}.png" 2>/dev/null
            convert "\$ICON_DIR/64/\${module_name}.png" -resize 16x16 "\$ICON_DIR/16/\${module_name}.png" 2>/dev/null
            
            echo "✓"
        else
            echo "⚠ (ImageMagick не найден)"
        fi
        
        rm -f /tmp/\${module_name}_icon.ico
    else
        echo "✗"
    fi
done

echo ""
echo "Готово! Иконки сохранены в: \$ICON_DIR/"
EOF
    
    chmod +x "$script_dir/Обновить_иконки.sh"
    chown "$USER:$USER" "$script_dir/Обновить_иконки.sh"
    success "Создан: Обновить_иконки.sh"
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
    
    # Создание ярлыков
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
    echo -e "  ${GREEN}•${NC} Обновить_иконки.sh - повторное извлечение иконок"
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
