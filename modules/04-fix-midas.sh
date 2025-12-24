#!/bin/bash
# Исправление midas.dll - исправленная версия

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
    log "Проверка параметров..."
    
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        error "Переменные TARGET_USER и TARGET_HOME не установлены"
        exit 1
    fi
    
    USER="$TARGET_USER"
    HOME_DIR="$TARGET_HOME"
    LIB_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg/Lib"
    
    # Проверяем существование пользователя
    if ! id "$USER" >/dev/null 2>&1; then
        error "Пользователь $USER не существует"
        exit 1
    fi
    
    success "Проверка завершена"
    log "Пользователь: $USER"
    log "Путь к библиотекам: $LIB_DIR"
}

# Поиск midas.dll
find_midas() {
    log "Поиск библиотеки midas.dll..."
    
    if [ ! -d "$LIB_DIR" ]; then
        warning "Директория Lib не найдена: $LIB_DIR"
        return 1
    fi
    
    if [ -f "$LIB_DIR/midas.dll" ]; then
        success "midas.dll найдена"
        echo -e "  ${GREEN}→${NC} $LIB_DIR/midas.dll"
        return 0
    else
        warning "midas.dll не найдена в $LIB_DIR"
        return 1
    fi
}

# Исправление прав
fix_permissions() {
    log "Исправление прав доступа..."
    
    if [ -d "$LIB_DIR" ]; then
        echo -n "  Установка владельца... "
        if chown -R "$USER:$USER" "$LIB_DIR" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
        
        echo -n "  Установка разрешений... "
        if chmod -R 755 "$LIB_DIR" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
    fi
}

# Создание ссылок
create_links() {
    log "Создание ссылок..."
    
    if [ ! -d "$LIB_DIR" ]; then
        error "Директория $LIB_DIR не существует"
        return 1
    fi
    
    # Сначала исправляем права
    fix_permissions
    
    cd "$LIB_DIR" || {
        error "Не удалось перейти в $LIB_DIR"
        return 1
    }
    
    local links_created=0
    local link_pairs=(
        "midas.dll MIDAS.DLL"
        "midas.dll Midas.dll"
        "midas.dll midas.DLL"
    )
    
    for pair in "${link_pairs[@]}"; do
        source_file=$(echo "$pair" | awk '{print $1}')
        link_name=$(echo "$pair" | awk '{print $2}')
        
        if [ -f "$source_file" ]; then
            echo -n "  $source_file → $link_name... "
            if sudo -u "$USER" ln -sf "$source_file" "$link_name" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                links_created=$((links_created + 1))
            else
                echo -e "${YELLOW}!${NC}"
            fi
        fi
    done
    
    # Копируем в system32 (как в ручной установке)
    local system32_dir="$HOME_DIR/.wine_medorg/drive_c/windows/system32"
    if [ -d "$system32_dir" ]; then
        echo -n "  Копирование в system32... "
        if sudo -u "$USER" cp "$LIB_DIR/midas.dll" "$system32_dir/" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            
            # Создаем ссылки в system32
            cd "$system32_dir"
            sudo -u "$USER" ln -sf midas.dll MIDAS.DLL 2>/dev/null || true
            sudo -u "$USER" ln -sf midas.dll Midas.dll 2>/dev/null || true
        else
            echo -e "${YELLOW}!${NC}"
        fi
    fi
    
    if [ $links_created -gt 0 ]; then
        success "Создано ссылок: $links_created"
    else
        warning "Не удалось создать ссылки"
    fi
}

# Настройка реестра
setup_registry() {
    log "Настройка реестра Wine..."
    
    local wine_prefix="$HOME_DIR/.wine_medorg"
    local reg_file="/tmp/midas_reg_$$.reg"
    
    cat > "$reg_file" << 'EOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine\Settings]
"INIT"="MINIMIZE RESOURCE USAGE"
EOF
    
    # Применяем реестр
    echo -n "  Применение настроек реестра... "
    if sudo -u "$USER" env WINEPREFIX="$wine_prefix" WINEARCH=win32 wine regedit "$reg_file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}!${NC}"
        warning "Не удалось применить реестр автоматически"
    fi
    
    rm -f "$reg_file" 2>/dev/null
}

# Основная функция
main() {
    echo ""
    echo -e "${CYAN}ИСПРАВЛЕНИЕ MIDAS.DLL${NC}"
    echo ""
    
    # Шаг 1: Проверка окружения
    check_environment
    
    # Шаг 2: Поиск midas.dll
    if ! find_midas; then
        warning "Библиотека midas.dll не найдена"
        log "Возможно, программы еще не скопированы"
        exit 0
    fi
    
    # Шаг 3: Создание ссылок
    create_links
    
    # Шаг 4: Настройка реестра
    setup_registry
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      MIDAS.DLL УСПЕШНО ИСПРАВЛЕНА!             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Исправление прервано${NC}"; exit 1' INT

# Запуск
main "$@"