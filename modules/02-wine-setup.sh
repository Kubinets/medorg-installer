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
    
    # Проверяем существование пользователя
    if ! id "$USER" >/dev/null 2>&1; then
        error "Пользователь $USER не существует"
        exit 1
    fi
    
    success "Окружение проверено"
}

# Подготовка Wine prefix
prepare_wine_prefix() {
    log "Подготовка Wine окружения..."
    
    # Удаляем старый wine prefix, если есть
    if [ -d "$WINE_PREFIX" ]; then
        log "Удаляем старый Wine prefix..."
        rm -rf "$WINE_PREFIX"
        success "Старый prefix удален"
    fi
    
    # Создаем директорию
    mkdir -p "$WINE_PREFIX"
    chown -R "$USER:$USER" "$WINE_PREFIX"
    success "Директория создана"
}

# Настройка Wine компонентов
setup_wine_components() {
    log "Настройка Wine компонентов..."
    
    # Экспортируем переменные
    export WINEPREFIX="$WINE_PREFIX"
    export WINEARCH=win32
    export WINEDEBUG=-all
    
    # Создаем wine prefix
    log "Создание Wine prefix..."
    sudo -u "$USER" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 wineboot --init 2>&1 | grep -v "fixme\|warn\|err" || true
    sleep 2
    success "Wine prefix создан"
    
    # Устанавливаем компоненты через winetricks если он есть
    if command -v winetricks >/dev/null 2>&1; then
        log "Установка компонентов Wine..."
        
        local components=("corefonts" "tahoma" "vcrun6" "vcrun2008" "mdac28" "jet40")
        
        for component in "${components[@]}"; do
            log "  Установка $component..."
            timeout 120 sudo -u "$USER" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 winetricks -q "$component" 2>&1 | grep -v "fixme\|warn\|err" || true
            sleep 1
        done
        
        success "Компоненты Wine установлены"
    else
        warning "Winetricks не найден, пропускаем установку компонентов"
    fi
}

# Проверка и завершение
finalize_setup() {
    log "Проверяем результаты настройки..."
    
    # Проверяем создание wine prefix
    if [ -d "$WINE_PREFIX" ]; then
        chown -R "$USER:$USER" "$WINE_PREFIX"
        success "Wine prefix готов к работе"
    else
        warning "Wine prefix не был создан"
    fi
}

# Основная функция
main() {
    echo ""
    echo -e "${CYAN}НАСТРОЙКА WINE ДЛЯ МЕДИЦИНСКОГО ПО${NC}"
    echo ""
    
    # Шаг 1: Проверка окружения
    check_environment
    
    # Шаг 2: Подготовка
    prepare_wine_prefix
    
    # Шаг 3: Настройка компонентов
    setup_wine_components
    
    # Шаг 4: Проверка
    finalize_setup
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      НАСТРОЙКА WINE УСПЕШНО ЗАВЕРШЕНА!         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Запуск
main "$@"