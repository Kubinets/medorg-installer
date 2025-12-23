#!/bin/bash
# Настройка Wine - красивая версия

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
    local delay="${2:-0.01}"
    
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo ""
}

# Красивая рамка
print_section() {
    local title="$1"
    local width=50
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

# Анимированный прогресс-бар
progress_bar() {
    local duration=${1:-0.05}
    local width=${2:-40}
    
    for ((i=0; i<=width; i++)); do
        echo -ne "\r["
        for ((j=0; j<i; j++)); do echo -ne "█"; done
        for ((j=i; j<width; j++)); do echo -ne "░"; done
        echo -ne "] $((i*100/width))%"
        sleep $duration
    done
    echo ""
}

# Проверка окружения
check_environment() {
    print_section "ПРОВЕРКА ОКРУЖЕНИЯ"
    
    typewriter "Проверяем параметры установки..." 0.03
    echo ""
    
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        error "Переменные TARGET_USER и TARGET_HOME не установлены"
        echo "Убедитесь, что основной скрипт экспортирует эти переменные"
        exit 1
    fi
    
    USER="$TARGET_USER"
    HOME_DIR="$TARGET_HOME"
    WINE_PREFIX="$HOME_DIR/.wine_medorg"
    
    log "Пользователь: $USER"
    log "Домашняя директория: $HOME_DIR"
    log "Wine prefix: $WINE_PREFIX"
    
    # Проверяем существование пользователя
    if ! id "$USER" >/dev/null 2>&1; then
        error "Пользователь $USER не существует"
        exit 1
    fi
    
    # Проверяем установлен ли Wine
    if ! command -v wine >/dev/null 2>&1; then
        error "Wine не установлен"
        echo "Сначала установите зависимости через:"
        echo "  sudo dnf install wine wine.i686"
        exit 1
    fi
    
    success "Окружение проверено"
    sleep 1
}

# Подготовка Wine prefix
prepare_wine_prefix() {
    print_section "ПОДГОТОВКА WINE"
    
    typewriter "Подготовка Wine окружения..." 0.03
    echo ""
    
    # Удаляем старый wine prefix, если есть
    if [ -d "$WINE_PREFIX" ]; then
        log "Удаляем старый Wine prefix..."
        rm -rf "$WINE_PREFIX"
        success "Старый prefix удален"
    fi
    
    # Устанавливаем правильные права
    log "Устанавливаем права доступа..."
    chown -R "$USER:$USER" "$HOME_DIR" 2>/dev/null || true
    success "Права установлены"
    
    sleep 1
}

# Создание скрипта настройки Wine
create_wine_setup_script() {
    log "Создание скрипта настройки Wine..."
    
    SCRIPT_PATH="/tmp/wine_setup_$$.sh"
    
    cat > "$SCRIPT_PATH" << 'WINE_SCRIPT'
#!/bin/bash
# Внутренний скрипт настройки Wine

USER="$1"
HOME_DIR="$2"
WINE_PREFIX="$HOME_DIR/.wine_medorg"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║           НАСТРОЙКА WINE PREFIX                ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

echo "Пользователь: $USER"
echo "Директория: $WINE_PREFIX"
echo ""

# Экспортируем переменные окружения
export WINEARCH=win32
export WINEPREFIX="$WINE_PREFIX"
export WINEDEBUG=-all
export DISPLAY=:0
export HOME="$HOME_DIR"

# Переходим в домашнюю директорию
cd "$HOME_DIR"

# Создаем wine prefix
echo "▌ Создание Wine prefix..."
echo -n "  Прогресс: "
for i in {1..20}; do
    echo -n "."
    sleep 0.1
done
echo ""

timeout 60 wineboot --init 2>&1 | grep -v "fixme\|warn\|err" || true

# Проверяем результат
if [ -f "$WINE_PREFIX/system.reg" ]; then
    echo "  ✓ Prefix создан успешно"
else
    echo "  ⚠ Возможны проблемы с созданием prefix"
fi

sleep 1

# Устанавливаем компоненты через Winetricks
if command -v winetricks >/dev/null 2>&1; then
    echo ""
    echo "▌ Установка компонентов Wine..."
    
    components=("corefonts" "vcrun6" "mdac28")
    for component in "${components[@]}"; do
        echo -n "  Установка $component... "
        if winetricks -q "$component" 2>&1 | grep -q "already installed\|already set\|wine cmd.exe"; then
            echo "✓"
        else
            echo "⚠"
        fi
        sleep 1
    done
else
    echo "  ⚠ Winetricks не найден, пропускаем"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║      НАСТРОЙКА WINE ЗАВЕРШЕНА                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
WINE_SCRIPT
    
    chmod +x "$SCRIPT_PATH"
    success "Скрипт настройки создан"
}

# Запуск настройки Wine
setup_wine() {
    print_section "ЗАПУСК НАСТРОЙКИ WINE"
    
    echo -ne "${BLUE}Запуск настройки Wine для пользователя ${PURPLE}$USER${BLUE}...${NC}"
    echo ""
    
    # Запускаем скрипт от имени пользователя
    if sudo -u "$USER" DISPLAY=:0 bash "$SCRIPT_PATH" "$USER" "$HOME_DIR"; then
        echo ""
        success "Настройка Wine завершена успешно"
    else
        echo ""
        warning "Были ошибки при настройке Wine"
        log "Продолжаем установку..."
    fi
    
    # Очищаем временный скрипт
    rm -f "$SCRIPT_PATH"
    
    sleep 1
}

# Проверка и завершение
finalize_setup() {
    print_section "ПРОВЕРКА УСТАНОВКИ"
    
    typewriter "Проверяем результаты настройки..." 0.03
    echo ""
    
    # Проверяем создание wine prefix
    if [ -d "$WINE_PREFIX" ]; then
        chown -R "$USER:$USER" "$WINE_PREFIX"
        log "Wine prefix проверен:"
        echo -e "  ${GREEN}✓${NC} Директория: $WINE_PREFIX"
        
        if [ -f "$WINE_PREFIX/system.reg" ]; then
            echo -e "  ${GREEN}✓${NC} Файл конфигурации: system.reg"
        else
            echo -e "  ${YELLOW}!${NC} Файл конфигурации не найден"
        fi
        
        if [ -d "$WINE_PREFIX/drive_c" ]; then
            echo -e "  ${GREEN}✓${NC} Виртуальный диск C: создан"
        fi
        
        success "Wine prefix готов к работе"
    else
        warning "Wine prefix не был создан"
        log "Возможные причины:"
        echo "  1. Нет прав на создание директории"
        echo "  2. Wine не установлен правильно"
        echo "  3. Недостаточно свободного места"
    fi
    
    echo ""
}

# Создание скрипта для ручной настройки
create_manual_setup_script() {
    log "Создание скрипта для ручной настройки..."
    
    MANUAL_SCRIPT="$HOME_DIR/setup_wine_manually.sh"
    
    cat > "$MANUAL_SCRIPT" << EOF
#!/bin/bash
# Скрипт ручной настройки Wine
# Используйте если автоматическая настройка не сработала

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        РУЧНАЯ НАСТРОЙКА WINE                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Пользователь: $USER"
echo ""

echo "Шаг 1: Удаление старого Wine prefix"
echo "-----------------------------------"
read -p "Удалить старый Wine prefix? (y/N): " -n 1 -r
echo ""
if [[ \$REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/.wine_medorg
    echo "✓ Старый prefix удален"
fi

echo ""
echo "Шаг 2: Создание нового Wine prefix"
echo "----------------------------------"
export WINEARCH=win32
export WINEPREFIX=~/.wine_medorg
export WINEDEBUG=-all

echo "Создаем новый Wine prefix..."
wineboot --init
echo "✓ Prefix создан"

echo ""
echo "Шаг 3: Установка компонентов"
echo "----------------------------"
if command -v winetricks >/dev/null 2>&1; then
    echo "Устанавливаем компоненты через Winetricks..."
    winetricks -q corefonts vcrun6 mdac28
    echo "✓ Компоненты установлены"
else
    echo "Winetricks не найден"
    echo "Установите: sudo dnf install winetricks"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          НАСТРОЙКА ЗАВЕРШЕНА                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Теперь вы можете установить медицинское ПО."
echo ""
EOF
    
    chmod +x "$MANUAL_SCRIPT"
    chown "$USER:$USER" "$MANUAL_SCRIPT"
    
    success "Скрипт ручной настройки создан"
    echo -e "  ${BLUE}→${NC} $MANUAL_SCRIPT"
}

# Основная функция
main() {
    print_section "НАСТРОЙКА WINE ДЛЯ МЕДИЦИНСКОГО ПО"
    
    echo -e "${CYAN}Версия Wine:${NC} $(wine --version 2>/dev/null || echo 'не установлен')"
    echo ""
    
    # Шаг 1: Проверка окружения
    check_environment
    
    # Шаг 2: Подготовка
    prepare_wine_prefix
    
    # Шаг 3: Создание скрипта
    create_wine_setup_script
    
    # Шаг 4: Запуск настройки
    setup_wine
    
    # Шаг 5: Проверка
    finalize_setup
    
    # Шаг 6: Скрипт для ручной настройки
    create_manual_setup_script
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      НАСТРОЙКА WINE УСПЕШНО ЗАВЕРШЕНА!         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Сводка:${NC}"
    echo -e "${BLUE}───────${NC}"
    echo -e "  ${GREEN}•${NC} Wine prefix: ${YELLOW}$WINE_PREFIX${NC}"
    echo -e "  ${GREEN}•${NC} Архитектура: ${YELLOW}win32${NC}"
    echo -e "  ${GREEN}•${NC} Пользователь: ${YELLOW}$USER${NC}"
    echo ""
    echo -e "${CYAN}Для ручной настройки выполните:${NC}"
    echo -e "${BLUE}───────────────────────────────${NC}"
    echo -e "  ${YELLOW}sudo -u $USER $HOME_DIR/setup_wine_manually.sh${NC}"
    echo ""
    echo -e "${BLUE}Далее: копирование медицинского ПО...${NC}"
    echo ""
    
    # Автовыход через 3 секунды
    echo -n "Продолжение через "
    for i in {3..1}; do
        echo -n "$i "
        sleep 1
    done
    echo ""
}

# Запуск
main "$@"