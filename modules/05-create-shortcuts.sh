#!/bin/bash
# Создание ярлыков - исправленная версия

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
    DESKTOP_DIR="$HOME_DIR/Desktop"
    mkdir -p "$DESKTOP_DIR"
    chown "$USER:$USER" "$DESKTOP_DIR"
    warning "Создан рабочий стол: $DESKTOP_DIR"
}

# Поиск и создание ярлыков
create_shortcuts() {
    log "Создание ярлыков..."
    
    INSTALL_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    
    if [ ! -d "$INSTALL_DIR" ]; then
        warning "Директория с программами не найдена: $INSTALL_DIR"
        return
    fi
    
    # Создаем папку для ярлыков
    PROGRAM_DIR="$DESKTOP_DIR/Медицинские программы"
    mkdir -p "$PROGRAM_DIR"
    chown -R "$USER:$USER" "$PROGRAM_DIR"
    
    success "Папка для ярлыков создана: $PROGRAM_DIR"
    
    # Ищем все exe файлы
    local created=0
    find "$INSTALL_DIR" -name "*.exe" -type f | while read -r exe_file; do
        local module_dir=$(dirname "$exe_file")
        local module_name=$(basename "$module_dir")
        local exe_name=$(basename "$exe_file" .exe)
        
        # Создаем скрипт запуска
        local script_path="$PROGRAM_DIR/$module_name.sh"
        
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
        local desktop_file="$PROGRAM_DIR/$module_name.desktop"
        
        cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$module_name
Comment=Медицинская программа
Exec=$script_path
Icon=wine
Terminal=false
Type=Application
Categories=Medical;
EOF
        
        chmod +x "$desktop_file"
        chown "$USER:$USER" "$desktop_file"
        
        created=$((created + 1))
        echo -e "  ${GREEN}✓${NC} $module_name"
    done
    
    if [ $created -gt 0 ]; then
        success "Создано ярлыков: $created"
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
    
    # Скрипт запуска всех программ
    cat > "$script_dir/Запуск_всех_программ.sh" << EOF
#!/bin/bash
echo "Запуск всех медицинских программ..."
cd ~/.wine_medorg/drive_c/MedCTech/MedOrg
find . -name "*.exe" -type f -exec bash -c 'echo "Запуск {}"; wine "{}" &' \;
echo "Программы запущены!"
EOF
    
    chmod +x "$script_dir/Запуск_всех_программ.sh"
    chown "$USER:$USER" "$script_dir/Запуск_всех_программ.sh"
    
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
    echo -e "  ${GREEN}•${NC} Программы: ${YELLOW}$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg/${NC}"
    echo ""
    
    echo -e "${CYAN}Для запуска:${NC}"
    echo -e "${BLUE}────────────${NC}"
    echo "1. Войдите как пользователь: $USER"
    echo "2. На рабочем столе откройте папку 'Медицинские программы'"
    echo "3. Запускайте программы двойным кликом"
    echo ""
}

# Обработка прерывания
trap 'echo -e "\n${RED}Создание ярлыков прервано${NC}"; exit 1' INT

# Запуск
main "$@"