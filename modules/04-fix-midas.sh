#!/bin/bash
# Исправление midas.dll - FIXED VERSION

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
    print_section "ПОИСК MIDAS.DLL"
    
    typewriter "Ищем библиотеку midas.dll..." 0.03
    echo ""
    
    if [ ! -d "$LIB_DIR" ]; then
        warning "Директория Lib не найдена: $LIB_DIR"
        log "Возможно, файлы еще не скопированы"
        return 1
    fi
    
    if [ -f "$LIB_DIR/midas.dll" ]; then
        success "midas.dll найдена"
        echo -e "  ${GREEN}→${NC} $LIB_DIR/midas.dll"
        
        # Информация о файле
        if command -v file >/dev/null 2>&1; then
            echo -ne "  ${BLUE}Тип файла:${NC} "
            file "$LIB_DIR/midas.dll" | cut -d: -f2- | sed 's/^ //'
        fi
        
        if command -v ls >/dev/null 2>&1; then
            echo -ne "  ${BLUE}Размер:${NC} "
            ls -lh "$LIB_DIR/midas.dll" | awk '{print $5}'
        fi
        
        return 0
    else
        warning "midas.dll не найдена в $LIB_DIR"
        
        # Поиск в других местах
        log "Ищем в других возможных местах..."
        find "$HOME_DIR/.wine_medorg" -name "midas.dll" -o -name "MIDAS.DLL" 2>/dev/null | head -5 | while read -r file; do
            echo -e "  ${YELLOW}→${NC} Найдена: $file"
        done
        
        return 1
    fi
}

# Исправление прав на директорию
fix_permissions() {
    log "Исправление прав доступа..."
    
    echo -n "  Устанавливаем владельца для $LIB_DIR... "
    if chown -R "$USER:$USER" "$LIB_DIR" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}!${NC}"
    fi
    
    echo -n "  Устанавливаем разрешения... "
    if chmod -R 755 "$LIB_DIR" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}!${NC}"
    fi
}

# Создание символьных ссылок
create_links() {
    print_section "СОЗДАНИЕ ССЫЛОК"
    
    typewriter "Создаем ссылки для регистрации DLL..." 0.03
    echo ""
    
    if [ ! -d "$LIB_DIR" ]; then
        error "Директория $LIB_DIR не существует"
        return 1
    fi
    
    # Сначала исправляем права
    fix_permissions
    
    echo ""
    
    local links_created=0
    local link_pairs=(
        "midas.dll MIDAS.DLL"
        "midas.dll Midas.dll"
        "midas.dll midas.DLL"
        "midas.dll MIDAS.dll"
        "midas.dll Midas.DLL"
    )
    
    echo "Создаем ссылки с разным регистром:"
    echo "────────────────────────────────────"
    
    for pair in "${link_pairs[@]}"; do
        source_file=$(echo "$pair" | awk '{print $1}')
        link_name=$(echo "$pair" | awk '{print $2}')
        
        if [ -f "$LIB_DIR/$source_file" ]; then
            echo -n "  $source_file → $link_name... "
            # Создаем ссылку от имени пользователя
            if sudo -u "$USER" ln -sf "$source_file" "$LIB_DIR/$link_name" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                links_created=$((links_created + 1))
            else
                # Если не получилось, пробуем исправить права и создать
                chown "$USER:$USER" "$LIB_DIR/$source_file" 2>/dev/null
                if sudo -u "$USER" ln -sf "$source_file" "$LIB_DIR/$link_name" 2>/dev/null; then
                    echo -e "${GREEN}✓${NC}"
                    links_created=$((links_created + 1))
                else
                    echo -e "${YELLOW}!${NC}"
                fi
            fi
        fi
    done
    
    echo ""
    
    if [ $links_created -gt 0 ]; then
        success "Создано ссылок: $links_created"
        
        # Исправляем владельца всех файлов
        chown -R "$USER:$USER" "$LIB_DIR"/* 2>/dev/null || true
        
        # Показываем созданные ссылки
        echo ""
        log "Проверка созданных ссылок:"
        sudo -u "$USER" ls -la "$LIB_DIR/"*[Mm][Ii][Dd][Aa][Ss]* 2>/dev/null | grep -E "midas|MIDAS|Midas" | while read -r line; do
            echo "  $line"
        done || true
    else
        warning "Не удалось создать ни одной ссылки"
    fi
    
    return $links_created
}

# Создание reg файла
create_reg_file() {
    print_section "НАСТРОЙКА РЕЕСТРА WINE"
    
    typewriter "Создаем файл реестра для Borland Database Engine..." 0.03
    echo ""
    
    local reg_file="/tmp/midas_fix_$$.reg"
    
    cat > "$reg_file" << 'REGEOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine\Settings]
"NET DIR"="C:\\MedCTech\\MedOrg\\Lib"
"LANGDRIVER"=""
"SYSPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Wine\DllOverrides]
"midas"="native,builtin"
"midas32"="native,builtin"
"borlndmm"="native,builtin"
REGEOF
    
    if [ -f "$reg_file" ]; then
        success "Файл реестра создан"
        echo -e "  ${GREEN}→${NC} $reg_file"
        
        # Устанавливаем права на файл реестра
        chown "$USER:$USER" "$reg_file" 2>/dev/null || true
        
        # Показываем содержимое
        echo ""
        log "Содержимое файла реестра:"
        cat "$reg_file" | while read -r line; do
            echo "  $line"
        done
        
        echo "$reg_file"
    else
        error "Не удалось создать файл реестра"
        return ""
    fi
}

# Применение реестра
apply_registry() {
    local reg_file="$1"
    
    echo ""
    typewriter "Применяем настройки реестра Wine..." 0.03
    
    if [ ! -f "$reg_file" ]; then
        warning "Файл реестра не найден"
        return 1
    fi
    
    # Убедимся, что файл принадлежит пользователю
    chown "$USER:$USER" "$reg_file" 2>/dev/null || true
    
    # Экспортируем переменные Wine
    export WINEPREFIX="$HOME_DIR/.wine_medorg"
    export WINEARCH=win32
    export WINEDEBUG=-all
    
    echo -ne "\n  ${BLUE}Загрузка в реестр Wine...${NC} "
    
    if sudo -u "$USER" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 WINEDEBUG=-all wine regedit "$reg_file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        
        # Проверяем добавленные ключи
        echo ""
        log "Проверка записей реестра:"
        
        # Проверяем через wine reg query
        if sudo -u "$USER" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 wine reg query "HKLM\\Software\\Borland\\Database Engine" 2>/dev/null | grep -i "dllpath\|syspath"; then
            echo -e "  ${GREEN}✓ Записи реестра применены${NC}"
        else
            echo -e "  ${YELLOW}! Записи не найдены в реестре${NC}"
        fi
        
        return 0
    else
        echo -e "${YELLOW}!${NC}"
        warning "Не удалось применить реестр автоматически"
        log "Попробуйте вручную от пользователя $USER:"
        echo -e "  ${CYAN}wine regedit '$reg_file'${NC}"
        return 1
    fi
}

# Создание скрипта ручного исправления
create_fix_script() {
    local script_path="$HOME_DIR/fix_midas_manually.sh"
    
    log "Создание скрипта ручного исправления..."
    
    cat > "$script_path" << EOF
#!/bin/bash
# Ручное исправление midas.dll

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        РУЧНОЕ ИСПРАВЛЕНИЕ MIDAS.DLL            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

USER="$USER"
HOME_DIR="$HOME_DIR"
LIB_DIR="\$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg/Lib"

echo "Пользователь: \$USER"
echo "Путь к библиотекам: \$LIB_DIR"
echo ""

# Исправляем права
echo "Шаг 1: Исправление прав доступа"
echo "───────────────────────────────"
echo -n "  Установка владельца... "
if chown -R "\$USER:\$USER" "\$LIB_DIR" 2>/dev/null; then
    echo "✓"
else
    echo "⚠"
fi

echo -n "  Установка разрешений... "
if chmod -R 755 "\$LIB_DIR" 2>/dev/null; then
    echo "✓"
else
    echo "⚠"
fi

# Проверяем существование midas.dll
if [ ! -f "\$LIB_DIR/midas.dll" ]; then
    echo ""
    echo "❌ Ошибка: midas.dll не найдена в \$LIB_DIR"
    echo ""
    echo "Возможные решения:"
    echo "1. Убедитесь, что программы установлены"
    echo "2. Проверьте путь: \$LIB_DIR"
    echo "3. Скопируйте midas.dll вручную"
    exit 1
fi

echo ""
echo "Шаг 2: Создание ссылок"
echo "──────────────────────"
cd "\$LIB_DIR"

links=("MIDAS.DLL" "Midas.dll" "midas.DLL" "MIDAS.dll" "Midas.DLL")
for link in "\${links[@]}"; do
    echo -n "  midas.dll → \$link... "
    if ln -sf midas.dll "\$link" 2>/dev/null; then
        echo "✓"
    else
        echo "⚠"
    fi
done

echo ""
echo "Шаг 3: Создание файла реестра"
echo "─────────────────────────────"
cat > /tmp/midas_fix.reg << 'REGEOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine\Settings]
"NET DIR"="C:\\MedCTech\\MedOrg\\Lib"
"LANGDRIVER"=""
"SYSPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Wine\DllOverrides]
"midas"="native,builtin"
"midas32"="native,builtin"
"borlndmm"="native,builtin"
REGEOF

echo "  Файл реестра создан: /tmp/midas_fix.reg"

echo ""
echo "Шаг 4: Применение реестра"
echo "─────────────────────────"
export WINEPREFIX="\$HOME_DIR/.wine_medorg"
export WINEARCH=win32
export WINEDEBUG=-all

echo -n "  Загрузка в реестр Wine... "
if wine regedit /tmp/midas_fix.reg 2>/dev/null; then
    echo "✓"
else
    echo "⚠"
    echo "  Попробуйте запустить вручную:"
    echo "  wine regedit /tmp/midas_fix.reg"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          ИСПРАВЛЕНИЕ ВЫПОЛНЕНО!                ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
EOF
    
    chmod +x "$script_path"
    chown "$USER:$USER" "$script_path"
    
    success "Скрипт ручного исправления создан"
    echo -e "  ${BLUE}→${NC} $script_path"
}

# Основная функция
main() {
    print_section "ИСПРАВЛЕНИЕ MIDAS.DLL"
    
    echo -e "${CYAN}Исправление регистрации библиотеки Borland midas.dll${NC}"
    echo ""
    
    # Шаг 1: Проверка окружения
    check_environment
    
    # Шаг 2: Поиск midas.dll
    if ! find_midas; then
        warning "Пропускаем исправление midas.dll"
        create_fix_script
        exit 0
    fi
    
    # Шаг 3: Создание ссылок
    if ! create_links; then
        warning "Проблемы с созданием ссылок"
    fi
    
    # Шаг 4: Создание и применение реестра
    local reg_file
    if reg_file=$(create_reg_file); then
        if apply_registry "$reg_file"; then
            success "Реестр успешно применен"
        else
            warning "Реестр не применен автоматически"
        fi
        
        # Удаляем временный файл
        rm -f "$reg_file" 2>/dev/null
    fi
    
    # Шаг 5: Создание скрипта для ручного исправления
    create_fix_script
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      MIDAS.DLL УСПЕШНО ИСПРАВЛЕНА!             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Выполненные действия:${NC}"
    echo -e "${BLUE}─────────────────────${NC}"
    echo -e "  ${GREEN}•${NC} Найдена библиотека midas.dll"
    echo -e "  ${GREEN}•${NC} Исправлены права доступа"
    echo -e "  ${GREEN}•${NC} Созданы символьные ссылки"
    echo -e "  ${GREEN}•${NC} Добавлены записи в реестр Wine"
    echo -e "  ${GREEN}•${NC} Создан скрипт ручного исправления"
    echo ""
    echo -e "${CYAN}Расположение:${NC}"
    echo -e "${BLUE}─────────────${NC}"
    echo -e "  ${YELLOW}$LIB_DIR/${NC}"
    echo ""
    echo -e "${BLUE}Для ручного исправления выполните:${NC}"
    echo -e "${BLUE}──────────────────────────────────${NC}"
    echo -e "  ${YELLOW}sudo -u $USER $HOME_DIR/fix_midas_manually.sh${NC}"
    echo ""
    echo -e "${YELLOW}Или войдите как пользователь $USER и выполните:${NC}"
    echo -e "  ${CYAN}$HOME_DIR/fix_midas_manually.sh${NC}"
    echo ""
    
    # Автовыход через 2 секунды
    echo -n "Продолжение через "
    for i in {2..1}; do
        echo -n "$i "
        sleep 1
    done
    echo ""
}

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Исправление прервано${NC}"; exit 1' INT

# Запуск
main "$@"