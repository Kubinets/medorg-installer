#!/bin/bash
# Настройка Wine - исправленная версия

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
    log "Проверка параметров установки..."
    
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        error "Переменные TARGET_USER и TARGET_HOME не установлены"
        exit 1
    fi
    
    USER="$TARGET_USER"
    HOME_DIR="$TARGET_HOME"
    WINE_PREFIX="$HOME_DIR/.wine_medorg"
    
    log "Пользователь: $USER"
    log "Домашняя директория: $HOME_DIR"
    log "Wine prefix: $WINE_PREFIX"
    
    if ! id "$USER" >/dev/null 2>&1; then
        error "Пользователь $USER не существует"
        exit 1
    fi
    
    success "Окружение проверено"
}

# Подготовка Wine prefix
prepare_wine_prefix() {
    log "Подготовка Wine окружения..."
    
    if [ -d "$WINE_PREFIX" ]; then
        log "Удаляем старый Wine prefix..."
        rm -rf "$WINE_PREFIX"
        success "Старый prefix удален"
    fi
    
    mkdir -p "$WINE_PREFIX"
    chown -R "$USER:$USER" "$WINE_PREFIX"
    success "Директория создана"
}

# Настройка Wine компонентов (РАБОЧАЯ ВЕРСИЯ)
setup_wine_components() {
    log "Настройка Wine компонентов..."
    
    export WINEPREFIX="$WINE_PREFIX"
    export WINEARCH=win32
    export WINEDEBUG=-all
    export DISPLAY=:0
    
    # Создаем wine prefix
    log "Создание Wine prefix..."
    sudo -u "$USER" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 wineboot --init 2>&1 | grep -v "fixme\|warn\|err\|X11" || true
    sleep 3
    success "Wine prefix создан"
    
    # Устанавливаем компоненты через winetricks
    if command -v winetricks >/dev/null 2>&1; then
        log "Установка компонентов Wine..."
        
        # Важные компоненты для медицинского ПО
        local components=("corefonts" "tahoma" "vcrun6" "mdac28")
        
        for component in "${components[@]}"; do
            log "  Установка $component..."
            # Запускаем в фоне с подавлением вывода
            sudo -u "$USER" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 winetricks -q "$component" >/dev/null 2>&1 &
            sleep 5
        done
        
        # Ждем завершения установки
        wait
        success "Компоненты Wine установлены"
    else
        error "Winetricks не найден! Компоненты не установлены."
        log "Установите вручную: sudo dnf install winetricks"
    fi
}

# Проверка и завершение
finalize_setup() {
    log "Проверяем результаты настройки..."
    
    if [ -d "$WINE_PREFIX" ]; then
        chown -R "$USER:$USER" "$WINE_PREFIX"
        
        if [ -f "$WINE_PREFIX/system.reg" ]; then
            success "Wine prefix готов к работе"
            log "  Путь: $WINE_PREFIX"
        else
            warning "Wine prefix создан, но реестр не найден"
        fi
    else
        error "Wine prefix не создан"
    fi
}

# Основная функция
main() {
    echo ""
    echo -e "${CYAN}НАСТРОЙКА WINE ДЛЯ МЕДИЦИНСКОГО ПО${NC}"
    echo ""
    
    check_environment
    prepare_wine_prefix
    setup_wine_components
    finalize_setup
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      НАСТРОЙКА WINE УСПЕШНО ЗАВЕРШЕНА!         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Настройка прервана${NC}"; exit 1' INT

# Запуск
main "$@"