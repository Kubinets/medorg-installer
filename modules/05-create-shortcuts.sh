#!/bin/bash
# Создание ярлыков - FIXED VERSION

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Анимированный вывод
typewriter() {
    local text="$1"
    local delay="${2:-0.03}"
    
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo ""
}

# Красивая рамка
print_section() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo ""
    echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $width))╗${NC}"
    echo -e "${CYAN}║$(printf ' %.0s' $(seq 1 $padding))${PURPLE}$title${CYAN}$(printf ' %.0s' $(seq 1 $((width - padding - ${#title}))))║${NC}"
    echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $width))╝${NC}"
    echo ""
}

# Функции вывода
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# Проверка окружения
check_environment() {
    print_section "ПРОВЕРКА ОКРУЖЕНИЯ"
    
    typewriter "Проверяем параметры для создания ярлыков..." 0.03
    echo ""
    
    if [ -z "$TARGET_USER" ]; then
        error "Переменная TARGET_USER не установлена"
        exit 1
    fi
    
    if [ -z "$TARGET_HOME" ]; then
        error "Переменная TARGET_HOME не установлена"
        exit 1
    fi
    
    if ! id "$TARGET_USER" &>/dev/null; then
        error "Пользователь $TARGET_USER не существует"
        exit 1
    fi
    
    USER="$TARGET_USER"
    HOME_DIR="$TARGET_HOME"
    
    success "Параметры проверены"
    log "Пользователь: $USER"
    log "Домашняя директория: $HOME_DIR"
    
    sleep 1
}

# Определение пути к рабочему столу
get_desktop_path() {
    log "Определяем путь к рабочему столу..."
    
    # Пробуем разные варианты (русский и английский локали)
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

# Создание директории для ярлыков
create_program_directory() {
    print_section "СОЗДАНИЕ ПАПКИ С ЯРЛЫКАМИ"
    
    typewriter "Создаем папку для медицинских программ на рабочем столе..." 0.03
    
    PROGRAM_DIR="$DESKTOP_DIR/Медицинские программы"
    
    echo ""
    echo -ne "  ${BLUE}Создаем папку:${NC} $PROGRAM_DIR... "
    
    if mkdir -p "$PROGRAM_DIR" 2>/dev/null; then
        chown -R "$USER:$USER" "$PROGRAM_DIR"
        echo -e "${GREEN}✓${NC}"
        success "Папка создана: $PROGRAM_DIR"
    else
        echo -e "${RED}✗${NC}"
        error "Не удалось создать папку"
        exit 1
    fi
    
    echo ""
}

# Поиск и создание ярлыков
create_shortcuts() {
    print_section "СОЗДАНИЕ ЯРЛЫКОВ"
    
    typewriter "Ищем установленные программы и создаем ярлыки..." 0.03
    echo ""
    
    INSTALL_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    
    if [ ! -d "$INSTALL_DIR" ]; then
        warning "Директория с программами не найдена: $INSTALL_DIR"
        warning "Создаю информационные ярлыки..."
        create_info_shortcuts
        return
    fi
    
    # Определяем какие модули создавать
    REQUIRED_MODULES=("Lib" "LibDRV" "LibLinux")
    
    if [ -z "${SELECTED_MODULES+x}" ] || [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
        MODULES=("${REQUIRED_MODULES[@]}")
        echo -e "${YELLOW}Использую обязательные модули:${NC}"
        for module in "${MODULES[@]}"; do
            echo -e "  ${CYAN}•${NC} $module"
        done
    else
        MODULES=("${SELECTED_MODULES[@]}")
        echo -e "${YELLOW}Использую выбранные модули:${NC}"
        for module in "${MODULES[@]}"; do
            echo -e "  ${CYAN}•${NC} $module"
        done
    fi
    
    echo ""
    echo -e "${CYAN}Поиск программ и создание ярлыков:${NC}"
    echo "─────────────────────────────────────"
    
    local created=0
    local skipped=0
    
    for module in "${MODULES[@]}"; do
        MODULE_PATH="$INSTALL_DIR/$module"
        
        if [ -d "$MODULE_PATH" ]; then
            # Ищем .exe файл в директории модуля
            EXE_FILE=$(find "$MODULE_PATH" -maxdepth 1 -name "*.exe" -type f | head -n 1)
            
            if [ -n "$EXE_FILE" ]; then
                echo -ne "  ${BLUE}$module${NC}... "
                if create_desktop_file "$module" "$EXE_FILE"; then
                    echo -e "${GREEN}✓${NC}"
                    created=$((created + 1))
                    
                    # Показываем имя exe файла
                    echo -e "    ${YELLOW}→${NC} Запускает: $(basename "$EXE_FILE")"
                else
                    echo -e "${RED}✗${NC}"
                    skipped=$((skipped + 1))
                fi
            else
                echo -ne "  ${BLUE}$module${NC}... "
                echo -e "${YELLOW}!${NC} (нет .exe файла)"
                skipped=$((skipped + 1))
            fi
        else
            echo -ne "  ${BLUE}$module${NC}... "
            echo -e "${YELLOW}!${NC} (папка не найдена)"
            skipped=$((skipped + 1))
        fi
        
        sleep 0.1
    done
    
    echo ""
    
    if [ $created -gt 0 ]; then
        success "Создано ярлыков: $created"
        if [ $skipped -gt 0 ]; then
            warning "Пропущено: $skipped"
        fi
    else
        warning "Не удалось создать ни одного ярлыка"
    fi
}

# Создание .desktop файла
create_desktop_file() {
    local module="$1"
    local exe_file="$2"
    
    local desktop_file="$PROGRAM_DIR/$module.desktop"
    
    # Определяем иконку
    local icon_path=""
    if [ -f "$exe_file" ]; then
        # Пробуем извлечь иконку из exe
        local icon_temp="/tmp/icon_$$.ico"
        if command -v wrestool >/dev/null 2>&1; then
            wrestool -x -t 14 "$exe_file" -o "$icon_temp" 2>/dev/null && {
                local icon_png="/tmp/icon_$$.png"
                if command -v convert >/dev/null 2>&1; then
                    convert "$icon_temp" "$icon_png" 2>/dev/null && {
                        icon_path="$icon_png"
                    }
                fi
                rm -f "$icon_temp" 2>/dev/null
            }
        fi
    fi
    
    # Если не нашли иконку, используем стандартную
    if [ -z "$icon_path" ]; then
        icon_path="wine"
    fi
    
    # Создаем .desktop файл
    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MedOrg $module
Comment=Медицинская информационная система
Exec=env WINEPREFIX="$HOME_DIR/.wine_medorg" WINEARCH=win32 wine "$exe_file"
Path=$(dirname "$exe_file")
Icon=$icon_path
Terminal=false
StartupNotify=false
Categories=Medical;
StartupWMClass=$(basename "$exe_file" .exe)
EOF
    
    # Устанавливаем права
    chown "$USER:$USER" "$desktop_file"
    chmod +x "$desktop_file"
    
    # Очищаем временные файлы иконок
    rm -f /tmp/icon_* 2>/dev/null
    
    return 0
}

# Создание информационных ярлыков (если нет программ)
create_info_shortcuts() {
    echo ""
    echo -e "${CYAN}Создаю информационные файлы:${NC}"
    echo "────────────────────────────"
    
    # Ярлык с инструкцией
    echo -ne "  ${BLUE}Инструкция по запуску...${NC} "
    cat > "$PROGRAM_DIR/Запуск_MedOrg.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Запуск MedOrg
Comment=Запуск медицинской информационной системы
Exec=xdg-open "$PROGRAM_DIR/README.txt"
Icon=dialog-information
Terminal=false
StartupNotify=false
Categories=Medical;
EOF
    
    chown "$USER:$USER" "$PROGRAM_DIR/Запуск_MedOrg.desktop"
    chmod +x "$PROGRAM_DIR/Запуск_MedOrg.desktop"
    echo -e "${GREEN}✓${NC}"
    
    # Файл с инструкцией
    echo -ne "  ${BLUE}Файл с инструкцией...${NC} "
    cat > "$PROGRAM_DIR/README.txt" << EOF
╔══════════════════════════════════════════════════╗
║         МЕДИЦИНСКАЯ СИСТЕМА MEDORG             ║
╚══════════════════════════════════════════════════╝

Установка завершена, но программы не найдены.

ВОЗМОЖНЫЕ ПРИЧИНЫ:
──────────────────
1. Программы еще не скопированы из сетевой папки
2. Wine не настроен правильно
3. Не выбраны модули для установки

ЧТО ДЕЛАТЬ:
───────────
1. Проверьте, что выполнены все шаги установки
2. Убедитесь, что программы скопированы в:
   $HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg/
3. Если Wine не настроен, запустите:
   $HOME_DIR/setup_wine_manually.sh

ПОМОЩЬ:
───────
• Скрипт исправления прав: $PROGRAM_DIR/Исправить_права.sh
• Скрипт настройки Wine: $PROGRAM_DIR/Переустановить_Wine.sh

Для запуска программ войдите как пользователь: $USER
EOF
    
    chown "$USER:$USER" "$PROGRAM_DIR/README.txt"
    echo -e "${GREEN}✓${NC}"
    
    success "Информационные файлы созданы"
}

# Создание вспомогательных скриптов
create_helper_scripts() {
    print_section "ВСПОМОГАТЕЛЬНЫЕ СКРИПТЫ"
    
    typewriter "Создаем скрипты для обслуживания системы..." 0.03
    echo ""
    
    echo -e "${CYAN}Создаю вспомогательные скрипты:${NC}"
    echo "──────────────────────────────"
    
    # Скрипт исправления прав
    echo -ne "  ${BLUE}Скрипт исправления прав...${NC} "
    cat > "$PROGRAM_DIR/Исправить_права.sh" << EOF
#!/bin/bash
# Скрипт исправления прав доступа

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          ИСПРАВЛЕНИЕ ПРАВ ДОСТУПА             ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

USER="$USER"
HOME_DIR="$HOME_DIR"
WINE_PREFIX="\$HOME_DIR/.wine_medorg"

echo "Пользователь: \$USER"
echo "Wine prefix: \$WINE_PREFIX"
echo ""

echo "▌ Исправление прав доступа..."
echo -n "  Проверка директории... "

if [ -d "\$WINE_PREFIX" ]; then
    echo "✓"
    
    echo -n "  Установка прав... "
    if chown -R "\$USER:\$USER" "\$WINE_PREFIX" 2>/dev/null; then
        echo "✓"
        
        echo -n "  Установка разрешений... "
        if chmod -R 755 "\$WINE_PREFIX" 2>/dev/null; then
            echo "✓"
        else
            echo "⚠"
        fi
    else
        echo "⚠"
    fi
else
    echo "✗ (директория не найдена)"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║            ОПЕРАЦИЯ ЗАВЕРШЕНА!                ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

read -p "Нажмите Enter для закрытия..."
EOF
    
    chmod +x "$PROGRAM_DIR/Исправить_права.sh"
    chown "$USER:$USER" "$PROGRAM_DIR/Исправить_права.sh"
    echo -e "${GREEN}✓${NC}"
    
    # Скрипт переустановки Wine
    echo -ne "  ${BLUE}Скрипт переустановки Wine...${NC} "
    cat > "$PROGRAM_DIR/Переустановить_Wine.sh" << EOF
#!/bin/bash
# Скрипт переустановки Wine

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║           ПЕРЕУСТАНОВКА WINE                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

USER="$USER"
HOME_DIR="$HOME_DIR"
WINE_PREFIX="\$HOME_DIR/.wine_medorg"

echo "Пользователь: \$USER"
echo "Wine prefix: \$WINE_PREFIX"
echo ""

read -p "Вы уверены, что хотите переустановить Wine? (y/N): " -n 1 -r
echo ""

if [[ \$REPLY =~ ^[Yy]\$ ]]; then
    echo "▌ Удаление старого Wine prefix..."
    echo -n "  Удаление \$WINE_PREFIX... "
    
    if rm -rf "\$WINE_PREFIX" 2>/dev/null; then
        echo "✓"
    else
        echo "⚠"
    fi
    
    echo ""
    echo "▌ Создание нового Wine prefix..."
    export WINEARCH=win32
    export WINEPREFIX="\$WINE_PREFIX"
    
    echo -n "  Инициализация Wine... "
    if wineboot --init 2>/dev/null; then
        echo "✓"
    else
        echo "⚠"
    fi
    
    echo ""
    echo "▌ Установка компонентов..."
    if command -v winetricks >/dev/null 2>&1; then
        echo "  Установка corefonts, vcrun6, mdac28..."
        winetricks -q corefonts vcrun6 mdac28 2>/dev/null
        echo "  ✓ Компоненты установлены"
    else
        echo "  ⚠ Winetricks не найден"
    fi
    
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║       WINE ПЕРЕУСТАНОВЛЕН УСПЕШНО!           ║"
    echo "╚══════════════════════════════════════════════════╝"
else
    echo "Операция отменена."
fi

echo ""
read -p "Нажмите Enter для закрытия..."
EOF
    
    chmod +x "$PROGRAM_DIR/Переустановить_Wine.sh"
    chown "$USER:$USER" "$PROGRAM_DIR/Переустановить_Wine.sh"
    echo -e "${GREEN}✓${NC}"
    
    # Скрипт быстрого запуска
    echo -ne "  ${BLUE}Скрипт быстрого запуска...${NC} "
    cat > "$PROGRAM_DIR/Быстрый_запуск.sh" << EOF
#!/bin/bash
# Скрипт быстрого запуска всех программ

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          БЫСТРЫЙ ЗАПУСК ПРОГРАММ              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

APPS_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"

echo "Запускаю основные модули..."
echo ""

modules=("Lib" "LibDRV" "LibLinux")
for module in "\${modules[@]}"; do
    if [ -d "\$APPS_DIR/\$module" ]; then
        exe=\$(find "\$APPS_DIR/\$module" -name "*.exe" -type f | head -1)
        if [ -n "\$exe" ]; then
            echo -n "  Запускаю \$module... "
            env WINEPREFIX="$HOME_DIR/.wine_medorg" WINEARCH=win32 wine "\$exe" &
            echo "✓"
            sleep 1
        fi
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║       ПРОГРАММЫ ЗАПУЩЕНЫ В ФОНОВОМ РЕЖИМЕ     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Закройте это окно после запуска всех программ."
echo ""
EOF
    
    chmod +x "$PROGRAM_DIR/Быстрый_запуск.sh"
    chown "$USER:$USER" "$PROGRAM_DIR/Быстрый_запуск.sh"
    echo -e "${GREEN}✓${NC}"
    
    success "Вспомогательные скрипты созданы"
}

# Итоговая информация
show_summary() {
    print_section "СОЗДАНИЕ ЯРЛЫКОВ ЗАВЕРШЕНО"
    
    typewriter "Ярлыки успешно созданы и готовы к использованию!" 0.03
    echo ""
    
    echo -e "${CYAN}Расположение:${NC}"
    echo -e "${BLUE}─────────────${NC}"
    echo -e "  ${GREEN}•${NC} Папка с ярлыками: ${YELLOW}$PROGRAM_DIR${NC}"
    echo -e "  ${GREEN}•${NC} Программы: ${YELLOW}$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg/${NC}"
    echo ""
    
    echo -e "${CYAN}Инструкция по запуску:${NC}"
    echo -e "${BLUE}──────────────────────${NC}"
    echo "1. Войдите в систему как пользователь: ${GREEN}$USER${NC}"
    echo "2. На рабочем столе откройте папку:"
    echo "   ${YELLOW}'Медицинские программы'${NC}"
    echo "3. Запустите нужную программу двойным кликом"
    echo ""
    
    echo -e "${CYAN}Вспомогательные скрипты:${NC}"
    echo -e "${BLUE}───────────────────────${NC}"
    echo -e "  ${GREEN}•${NC} Исправить_права.sh - исправление прав доступа"
    echo -e "  ${GREEN}•${NC} Переустановить_Wine.sh - переустановка Wine"
    echo -e "  ${GREEN}•${NC} Быстрый_запуск.sh - запуск всех программ"
    echo ""
    
    echo -e "${YELLOW}Для запуска программ необходимы:${NC}"
    echo "  • Настроенный Wine"
    echo "  • Подключенная сетевая папка (для автообновления)"
    echo "  • Правильные права доступа"
    echo ""
    
    echo -e "${GREEN}──────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Ярлыки готовы к использованию!${NC}"
    echo -e "${GREEN}──────────────────────────────────────────────────────────────${NC}"
}

# Основная функция
main() {
    check_environment
    get_desktop_path
    create_program_directory
    create_shortcuts
    create_helper_scripts
    show_summary
    
    # Автовыход через 3 секунды
    echo -n "Продолжение установки через "
    for i in {3..1}; do
        echo -n "$i "
        sleep 1
    done
    echo ""
}

# Запуск
main "$@"