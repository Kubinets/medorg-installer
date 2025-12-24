#!/bin/bash
# MedOrg Installer v4.0 - ПОЛНОСТЬЮ РАБОЧАЯ ВЕРСИЯ
# by kubinets - https://github.com/kubinets

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Глобальные переменные
REQUIRED=("Lib" "LibDRV" "LibLinux")
ALL_MODULES=("Admin" "BolList" "DayStac" "Dispanser" "DopDisp" 
             "Econ" "EconRA" "EconRost" "Fluoro" "Kiosk" 
             "KTFOMSAgentDisp" "KTFOMSAgentGosp" "KTFOMSAgentPolis" 
             "KTFOMSAgentReg" "KubNaprAgent" "MainSestStac" 
             "MedOsm" "MISAgent" "OtdelStac" "Pokoy" "RegPeople" 
             "RegPol" "San" "SanDoc" "SpravkaOMS" "StatPol" 
             "StatStac" "StatYear" "Tablo" "Talon" "Vedom" 
             "VistaAgent" "WrachPol")
SELECTED_MODULES=()
AUTO_MODE=false
USER=""
HOME_DIR=""
USER_SPECIFIED=false

# Функция печатающей машинки
typewriter() {
    local text="$1"
    local delay="${2:-0.01}"
    
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo ""
}

# Анимированный заголовок
show_header() {
    clear
    
    echo -e "${PURPLE}"
    typewriter "  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░" 0.001
    echo ""
    
    echo -e "${CYAN}"
    typewriter "  ██╗░░██╗██╗░░░██╗██████╗░██╗███╗░░██╗███████╗████████╗███████╗" 0.001
    typewriter "  ██║░██╔╝██║░░░██║██╔══██╗██║████╗░██║██╔════╝╚══██╔══╝██╔════╝" 0.001
    typewriter "  █████╔╝░██║░░░██║██████╔╝██║██╔██╗██║█████╗░░░░░██║░░░██████╗░" 0.001
    typewriter "  ██╔═██╗░██║░░░██║██╔══██╗██║██║╚████║██╔══╝░░░░░██║░░░╚════██╗" 0.001
    typewriter "  ██║░██║░╚██████╔╝██║░░██║██║██║░╚████║███████╗░░░██║░░░██████╔╝" 0.001
    typewriter "  ╚═╝░╚═╝░░╚═════╝░╚═╝░░╚═╝╚═╝╚═╝░░╚═══╝╚══════╝░░░╚═╝░░░╚═════╝░" 0.001
    echo ""
    
    echo -e "${YELLOW}"
    typewriter "  ═══════════════════════════════════════════════════════════" 0.001
    echo ""
    
    echo -e "${RED}"
    typewriter "   ███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗" 0.001
    typewriter "   ██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║" 0.001
    typewriter "   ███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║" 0.001
    typewriter "   ╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║" 0.001
    typewriter "   ███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║" 0.001
    typewriter "   ╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝" 0.001
    typewriter "   ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     " 0.001
    typewriter "   ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     " 0.001
    typewriter "   ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     " 0.001
    typewriter "   ██║██║╚██╗██║╚════██║   ██║   ██╔══██╗██║     ██║     " 0.001
    typewriter "   ██║██║ ╚████║███████╗   ██║   ██║  ██║███████╗███████╗" 0.001
    typewriter "   ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝" 0.001
    echo ""
    
    echo -e "${PURPLE}"
    typewriter "  ═══════════════════════════════════════════════════════════" 0.001
    echo ""
    
    echo -e "${GREEN}"
    typewriter "                     SYSTEM INSTALLER v4.0" 0.03
    echo ""
    typewriter "                    https://github.com/kubinets" 0.03
    echo ""
    
    sleep 1
}

# Функции вывода
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}!${NC} $1"; }

# Красивая рамка для заголовков
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

# Проверка root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "Запустите с правами root: sudo $0"
    fi
}

# Парсинг аргументов командной строки
parse_args() {
    USER=""  # Пустое значение по умолчанию
    SELECTED_MODULES=()
    AUTO_MODE=false
    USER_SPECIFIED=false
    
    # Проверяем, запущен ли через пайп
    if [[ ! -t 0 ]]; then
        echo -e "${YELLOW}ВНИМАНИЕ: Скрипт запущен через пайп. Используйте аргументы:${NC}"
        echo "  --user ИМЯ_ПОЛЬЗОВАТЕЛЯ"
        echo "  --modules МОДУЛЬ1,МОДУЛЬ2,... или 'all' или 'none'"
        echo "  --auto    Автоматическая установка"
        echo ""
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user)
                USER="$2"
                USER_SPECIFIED=true
                shift 2
                ;;
            --modules)
                if [[ "$2" == "all" ]]; then
                    SELECTED_MODULES=("${ALL_MODULES[@]}")
                elif [[ "$2" == "none" ]]; then
                    SELECTED_MODULES=()
                else
                    IFS=',' read -ra SELECTED_MODULES <<< "$2"
                fi
                shift 2
                ;;
            --auto)
                AUTO_MODE=true
                USER="meduser"
                USER_SPECIFIED=true
                SELECTED_MODULES=()
                shift
                ;;
            -h|--help)
                echo "Использование:"
                echo "  curl -sSL https://.../install.sh | sudo bash -- [ОПЦИИ]"
                echo ""
                echo "Опции:"
                echo "  --user ИМЯ        Имя пользователя"
                echo "  --modules СПИСОК  Модули через запятую, 'all' или 'none'"
                echo "  --auto            Автоматическая установка"
                echo "  -h, --help        Справка"
                echo ""
                echo "Примеры:"
                echo "  curl ... | sudo bash"
                echo "  curl ... | sudo bash -- --user vasya --modules Admin,BolList"
                echo "  curl ... | sudo bash -- --auto"
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                warning "Неизвестный аргумент: $1"
                shift
                ;;
        esac
    done
}

# Выбор пользователя
select_user() {
    if [[ "$USER_SPECIFIED" != true ]]; then
        print_section "ВЫБОР ПОЛЬЗОВАТЕЛЯ"
        
        echo "Существующие пользователи:"
        echo "-------------------------"
        getent passwd | grep -E ':/home/' | cut -d: -f1 | sort | column -c 80
        echo ""
        
        # Если запущен через пайп, используем дефолтного пользователя
        if [[ ! -t 0 ]]; then
            USER="meduser"
            log "Используем пользователя по умолчанию: $USER"
        else
            while true; do
                echo -ne "${YELLOW}Введите имя пользователя${NC}"
                echo -ne "${BLUE} (или 'new' для создания нового)${NC}"
                echo -ne "${GREEN} [meduser]: ${NC}"
                read input_user
                
                USER="${input_user:-meduser}"
                
                if [[ "$USER" == "new" ]]; then
                    read -p "Введите имя нового пользователя: " new_user
                    if [[ -n "$new_user" ]]; then
                        USER="$new_user"
                        break
                    else
                        warning "Имя пользователя не может быть пустым!"
                    fi
                elif [[ -n "$USER" ]]; then
                    break
                fi
            done
        fi
    fi
    
    # Проверка/создание пользователя
    if ! id "$USER" &>/dev/null; then
        echo ""
        echo -e "${YELLOW}Пользователь '$USER' не существует.${NC}"
        
        if [[ "$AUTO_MODE" == true ]] || [[ ! -t 0 ]]; then
            # Автоматически создаем
            useradd -m -s /bin/bash "$USER"
            echo "$USER:$USER" | chpasswd
            success "Пользователь '$USER' создан автоматически"
        else
            read -p "Создать пользователя '$USER'? (Y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                error "Установка отменена"
            else
                useradd -m -s /bin/bash "$USER"
                echo "Установка пароля для '$USER':"
                passwd "$USER"
                success "Пользователь создан"
            fi
        fi
    else
        success "Используем пользователя: $USER"
    fi
    
    HOME_DIR=$(getent passwd "$USER" | cut -d: -f6)
    success "Домашняя директория: $HOME_DIR"
}

# Выбор модулей (ФИНАЛЬНАЯ ИСПРАВЛЕННАЯ ВЕРСИЯ)
select_modules() {
    if [[ "$AUTO_MODE" == true ]]; then
        SELECTED_MODULES=()
        return
    fi
    
    if [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then
        return
    fi
    
    print_section "ВЫБОР МОДУЛЕЙ"
    
    # Показываем список
    echo "Выберите дополнительные модули (или нажмите Enter для пропуска):"
    echo ""
    
    # Пробуем получить ввод любым способом
    local input=""
    
    # Способ 1: Через /dev/tty
    if [[ -c /dev/tty ]]; then
        read -t 30 -p "Введите номера модулей (через пробел): " input </dev/tty 2>/dev/null || true
    # Способ 2: Через оригинальный stdin
    elif [[ -t 0 ]]; then
        read -t 30 -p "Введите номера модулей (через пробел): " input 2>/dev/null || true
    fi
    
    # Обработка ввода
    if [[ -z "$input" ]]; then
        SELECTED_MODULES=()
        echo "Дополнительные модули не выбраны"
    elif [[ "$input" == "a" ]] || [[ "$input" == "A" ]]; then
        SELECTED_MODULES=("${ALL_MODULES[@]}")
        echo "Выбраны все модули"
    else
        IFS=' ' read -ra nums <<< "$input"
        for num in "${nums[@]}"; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#ALL_MODULES[@]} ]; then
                SELECTED_MODULES+=("${ALL_MODULES[$((num-1))]}")
            fi
        done
        
        if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            SELECTED_MODULES=($(printf "%s\n" "${SELECTED_MODULES[@]}" | sort -u))
            echo "Выбраны: ${SELECTED_MODULES[*]}"
        else
            SELECTED_MODULES=()
            echo "Неверный ввод. Дополнительные модули не выбраны"
        fi
    fi
}

# Запуск модулей (ИСПРАВЛЕННАЯ ВЕРСИЯ)
run_modules() {
    print_section "НАЧАЛО УСТАНОВКИ"
    log "Начинаем установку..."
    
    # Преобразуем массив модулей в строку
    local SELECTED_MODULES_STR="${SELECTED_MODULES[*]}"
    
    # 1. Зависимости
    echo -e "${YELLOW}=== МОДУЛЬ 1: УСТАНОВКА ЗАВИСИМОСТЕЙ ===${NC}"
    if bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/01-dependencies.sh"); then
        success "Зависимости установлены"
    else
        warning "Модуль зависимостей завершился с ошибками"
    fi
    
    # 2. Настройка Wine
    echo -e "${YELLOW}=== МОДУЛЬ 2: НАСТРОЙКА WINE ===${NC}"
    if TARGET_USER="$USER" TARGET_HOME="$HOME_DIR" bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/02-wine-setup.sh"); then
        success "Wine настроен"
    else
        warning "Модуль Wine завершился с ошибками"
    fi
    
    # 3. Копирование файлов
    echo -e "${YELLOW}=== МОДУЛЬ 3: КОПИРОВАНИЕ ФАЙЛОВ ===${NC}"
    if TARGET_USER="$USER" TARGET_HOME="$HOME_DIR" SELECTED_MODULES="$SELECTED_MODULES_STR" bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/03-copy-files.sh"); then
        success "Файлы скопированы"
    else
        warning "Модуль копирования завершился с ошибками"
    fi
    
    # 4. Исправление midas.dll
    echo -e "${YELLOW}=== МОДУЛЬ 4: ИСПРАВЛЕНИЕ MIDAS.DLL ===${NC}"
    if TARGET_USER="$USER" TARGET_HOME="$HOME_DIR" bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/04-fix-midas.sh"); then
        success "midas.dll исправлена"
    else
        warning "Модуль midas.dll завершился с ошибками"
    fi
    
    # 5. Создание ярлыков
    echo -e "${YELLOW}=== МОДУЛЬ 5: СОЗДАНИЕ ЯРЛЫКОВ ===${NC}"
    if TARGET_USER="$USER" TARGET_HOME="$HOME_DIR" bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/05-create-shortcuts.sh"); then
        success "Ярлыки созданы"
    else
        warning "Модуль ярлыков завершился с ошибками"
    fi
    
    # Создаем финальный фикс-скрипт
    create_final_script
}

# Создание финального скрипта
create_final_script() {
    local script_path="$HOME_DIR/final_fix_all.sh"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
export WINEPREFIX="$HOME/.wine_medorg"

echo "=== ФИНАЛЬНЫЙ ФИКС ==="

# 1. Создаем ссылки
echo "1. Создание ссылок..."
cd "$WINEPREFIX/drive_c/MedCTech/MedOrg/Lib"
ln -sf midas.dll MIDAS.DLL 2>/dev/null
ln -sf midas.dll Midas.dll 2>/dev/null
ln -sf midas.dll midas.DLL 2>/dev/null

# 2. Копируем в system32
echo "2. Копирование в system32..."
cp -f midas.dll "$WINEPREFIX/drive_c/windows/system32/" 2>/dev/null
cd "$WINEPREFIX/drive_c/windows/system32"
ln -sf midas.dll MIDAS.DLL 2>/dev/null
ln -sf midas.dll Midas.dll 2>/dev/null

# 3. Реестр
echo "3. Исправление реестра..."
cat > /tmp/final_fix.reg << 'REGEOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"
REGEOF

wine regedit /tmp/final_fix.reg 2>/dev/null
rm -f /tmp/final_fix.reg

echo ""
echo "=== Готово! ==="
echo "Запускайте программы через ярлыки на рабочем столе"
EOF
    
    chmod +x "$script_path"
    chown "$USER:$USER" "$script_path"
    
    success "Финальный фикс-скрипт создан: $script_path"
}

# Функция для отображения завершения
show_completion() {
    print_section "УСТАНОВКА ЗАВЕРШЕНА"
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    УСПЕШНО ЗАВЕРШЕНО!                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Итоги установки:${NC}"
    echo -e "${BLUE}────────────────${NC}"
    echo -e "Пользователь:        ${GREEN}$USER${NC}"
    echo -e "Домашняя директория: ${YELLOW}$HOME_DIR${NC}"
    echo -e "Wine prefix:         ${YELLOW}$HOME_DIR/.wine_medorg${NC}"
    echo ""
    
    if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
        echo -e "${CYAN}Выбранные модули:${NC}"
        echo -e "${BLUE}────────────────${NC}"
        for module in "${SELECTED_MODULES[@]}"; do
            echo -e "  ${GREEN}•${NC} $module"
        done
        echo ""
    fi
    
    echo -e "${CYAN}Для запуска программ:${NC}"
    echo -e "${BLUE}────────────────────${NC}"
    echo "1. Войдите как пользователь: $USER"
    echo "2. Запустите финальный фикс:"
    echo -e "   ${YELLOW}./final_fix_all.sh${NC}"
    echo "3. Или перейдите в папку программы:"
    echo -e "   ${YELLOW}cd ~/.wine_medorg/drive_c/MedCTech/MedOrg/Название_модуля${NC}"
    echo -e "   ${YELLOW}wine ИмяПрограммы.exe${NC}"
    echo ""
    
    # Счетчик до автовыхода
    echo -n "Завершение через "
    for i in {5..1}; do
        echo -n "${RED}$i${NC} "
        sleep 1
    done
    echo ""
}

# Основной процесс установки
main() {
    show_header
    
    # Парсим аргументы
    parse_args "$@"
    
    # Проверка прав
    check_root
    
    # Выбор пользователя
    select_user
    
    # Выбор модулей
    select_modules
    
    # Запуск модулей
    run_modules
    
    # Завершение
    show_completion
    
    exit 0
}

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Установка прервана пользователем${NC}"; exit 1' INT

# Запуск
main "$@"