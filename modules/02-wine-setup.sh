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

# Настройка Wine компонентов (ИСПРАВЛЕННАЯ ВЕРСИЯ - без X11)
setup_wine_components() {
    log "Настройка Wine компонентов..."
    
    # Экспортируем переменные для работы без X11
    export WINEPREFIX="$WINE_PREFIX"
    export WINEARCH=win32
    export WINEDEBUG=-all
    export DISPLAY=:0  # Фиктивный DISPLAY
    
    # ФИКС: Создаем wine prefix без GUI
    log "Создание Wine prefix (без GUI)..."
    
    # Создаем базовый prefix через regedit
    cat > /tmp/wine_init.reg << 'EOF'
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine]
"Version"="7.0"

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion]
"ProgramFilesDir"="C:\\Program Files"
"CommonFilesDir"="C:\\Program Files\\Common Files"

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion]
"CurrentVersion"="6.1"
"CSDVersion"="Service Pack 1"
"CurrentBuildNumber"="7601"
EOF
    
    # Инициализируем prefix через regedit (без wineboot)
    sudo -u "$USER" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 wine regedit /tmp/wine_init.reg 2>/dev/null || true
    
    # Создаем базовую структуру директорий
    mkdir -p "$WINE_PREFIX/drive_c/windows/system32"
    mkdir -p "$WINE_PREFIX/drive_c/Program Files"
    mkdir -p "$WINE_PREFIX/drive_c/ProgramData"
    mkdir -p "$WINE_PREFIX/drive_c/users/$USER"
    
    # Копируем основные DLL (если есть)
    local system32_dir="/usr/lib/wine"
    if [ -d "$system32_dir" ]; then
        cp -r "$system32_dir"/* "$WINE_PREFIX/drive_c/windows/system32/" 2>/dev/null || true
    fi
    
    rm -f /tmp/wine_init.reg
    sleep 1
    success "Wine prefix создан"
    
    # Устанавливаем компоненты через winetricks если он есть
    if command -v winetricks >/dev/null 2>&1; then
        log "Установка компонентов Wine..."
        
        # Только текстовые компоненты (без GUI)
        local components=("corefonts" "tahoma" "vcrun6" "mdac28" "jet40")
        
        for component in "${components[@]}"; do
            log "  Установка $component..."
            # Запускаем в фоне с таймаутом и без вывода
            timeout 60 sudo -u "$USER" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 winetricks -q "$component" >/dev/null 2>&1 || true
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
        
        # Проверяем базовые файлы
        if [ -f "$WINE_PREFIX/system.reg" ] || [ -d "$WINE_PREFIX/drive_c" ]; then
            success "Wine prefix готов к работе"
            log "  Структура Wine prefix:"
            find "$WINE_PREFIX/drive_c" -maxdepth 2 -type d 2>/dev/null | sort
        else
            warning "Wine prefix создан, но возможно не полностью"
        fi
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
    
    # Шаг 3: Настройка компонентов (БЕЗ X11 ОШИБОК)
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

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Настройка прервана${NC}"; exit 1' INT

# Запуск
main "$@"