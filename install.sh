#!/bin/bash
# MedOrg Installer v3.3 - FIXED для пайпа
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

# ========== ФИКС ДЛЯ ПАЙПА ==========
# Проверяем, запущен ли скрипт через пайп
if [[ -t 0 ]]; then
    # Интерактивный режим - используем обычный ввод
    INPUT_METHOD="tty"
else
    # Неинтерактивный режим (пайп) - используем аргументы
    INPUT_METHOD="args"
    echo -e "${YELLOW}ВНИМАНИЕ: Скрипт запущен через пайп.${NC}"
    echo -e "${YELLOW}Используйте аргументы командной строки:${NC}"
    echo "  --user ИМЯ_ПОЛЬЗОВАТЕЛЯ"
    echo "  --modules МОДУЛЬ1,МОДУЛЬ2,... или 'all' или 'none'"
    echo "  --auto    Автоматическая установка с параметрами по умолчанию"
    echo ""
fi
# =====================================

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
    typewriter "                     SYSTEM INSTALLER v3.3" 0.03
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
    USER_SPECIFIED=false  # Флаг, указывающий, что пользователь указан через аргумент
    
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
                echo "  --user ИМЯ        Имя пользователя (по умолчанию: будет предложено выбрать)"
                echo "  --modules СПИСОК  Модули через запятую, 'all' или 'none'"
                echo "  --auto            Автоматическая установка с параметрами по умолчанию"
                echo "  -h, --help        Показать эту справку"
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

# Выбор пользователя (ИСПРАВЛЕННАЯ ВЕРСИЯ)
select_user() {
    # Если пользователь не указан через аргументы, всегда запрашиваем выбор
    if [[ "$USER_SPECIFIED" != true ]]; then
        print_section "ВЫБОР ПОЛЬЗОВАТЕЛЯ"
        
        # Показываем существующих пользователей
        echo "Существующие пользователи в системе:"
        echo "-----------------------------------"
        # Показываем только пользователей с домашней директорией
        getent passwd | grep -E ':/home/' | cut -d: -f1 | sort | column -c 80
        echo ""
        
        # В режиме пайпа перенаправляем ввод на терминал
        if [[ ! -t 0 ]]; then
            exec < /dev/tty
        fi
        
        while true; do
            echo -ne "${YELLOW}Введите имя пользователя для установки${NC}"
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
    
    # Проверка/создание пользователя
    if ! id "$USER" &>/dev/null; then
        echo ""
        echo -e "${YELLOW}Пользователь '$USER' не существует.${NC}"
        
        if [[ "$AUTO_MODE" == true ]]; then
            # Автоматически создаем пользователя
            useradd -m -s /bin/bash "$USER"
            echo "$USER:$USER" | chpasswd  # Пароль = имя пользователя
            success "Пользователь '$USER' создан автоматически"
        else
            # В режиме пайпа перенаправляем ввод на терминал
            if [[ ! -t 0 ]]; then
                exec < /dev/tty
            fi
            
            read -p "Создать нового пользователя '$USER'? (Y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                error "Установка отменена. Пользователь не существует."
            else
                useradd -m -s /bin/bash "$USER"
                echo "Установка пароля для пользователя '$USER':"
                passwd "$USER"
                success "Пользователь '$USER' создан"
            fi
        fi
    else
        success "Используем существующего пользователя: $USER"
    fi
    
    HOME_DIR=$(getent passwd "$USER" | cut -d: -f6)
    success "Установка для пользователя: $USER"
    success "Домашняя директория: $HOME_DIR"
}

# Выбор модулей (обновленная версия)
select_modules() {
    if [[ "$AUTO_MODE" == true ]]; then
        SELECTED_MODULES=()
        log "Автоматический режим: установка только обязательных модулей"
        return
    fi
    
    if [[ "$INPUT_METHOD" == "args" ]] && [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then
        # Модули уже выбраны через аргументы
        log "Модули выбраны через аргументы командной строки"
        return
    fi
    
    # Интерактивный выбор
    print_section "ВЫБОР МОДУЛЕЙ"
    
    echo "Обязательные модули:"
    echo -e "${GREEN}$(printf '  • %s\n' "${REQUIRED[@]}")${NC}"
    echo ""
    
    echo "Дополнительные модули:"
    for i in "${!ALL_MODULES[@]}"; do
        printf "${CYAN}%2d.${NC} %-20s" $((i+1)) "${ALL_MODULES[i]}"
        if [ $(((i+1) % 3)) -eq 0 ] || [ $((i+1)) -eq ${#ALL_MODULES[@]} ]; then
            echo ""
        fi
    done
    
    echo ""
    echo -e "${YELLOW}  a. Все модули${NC}"
    echo -e "${YELLOW}  n. Только обязательные${NC}"
    echo ""
    
    # В режиме пайпа перенаправляем ввод на терминал
    if [[ ! -t 0 ]]; then
        exec < /dev/tty
    fi
    
    while true; do
        echo -ne "${GREEN}Выберите модули${NC}"
        echo -ne "${BLUE} (номера через пробел, 'a' или 'n')${NC}"
        echo -ne "${YELLOW}: ${NC}"
        read choices
        
        SELECTED_MODULES=()
        
        case "$choices" in
            a|A)
                SELECTED_MODULES=("${ALL_MODULES[@]}")
                echo ""
                typewriter "Выбраны ВСЕ модули..." 0.03
                return
                ;;
            n|N)
                SELECTED_MODULES=()
                echo ""
                typewriter "Только обязательные модули..." 0.03
                return
                ;;
            *)
                IFS=' ' read -ra nums <<< "$choices"
                valid=true
                
                for num in "${nums[@]}"; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#ALL_MODULES[@]} ]; then
                        SELECTED_MODULES+=("${ALL_MODULES[$((num-1))]}")
                    else
                        warning "Неверный номер: $num"
                        valid=false
                    fi
                done
                
                if [ "$valid" = true ] && [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
                    SELECTED_MODULES=($(echo "${SELECTED_MODULES[@]}" | tr ' ' '\n' | sort -u))
                    break
                else
                    warning "Не выбрано ни одного модуля!"
                fi
                ;;
        esac
    done
    
    echo ""
    success "Выбраны модули:"
    for module in "${SELECTED_MODULES[@]}"; do
        echo -e "  ${GREEN}•${NC} $module"
    done
}

# Запуск модулей (ПОЛНОСТЬЮ ИСПРАВЛЕННАЯ ВЕРСИЯ ДЛЯ ВСЕХ СКРИПТОВ)
run_modules() {
    print_section "НАЧАЛО УСТАНОВКИ"
    log "Начинаем установку..."
    
    # Создаем функцию для запуска модулей с переменными
    run_module_with_env() {
        local module_url="$1"
        local module_name="$2"
        
        log "Запуск модуля: $module_name..."
        
        # Скачиваем скрипт
        local module_content=$(curl -s "$module_url")
        
        # Создаем временный скрипт с правильными переменными
        local temp_script="/tmp/module_$$.sh"
        
        cat > "$temp_script" << EOF
#!/bin/bash
# Загружаем переменные окружения
export TARGET_USER="$USER"
export TARGET_HOME="$HOME_DIR"
export SELECTED_MODULES="$SELECTED_MODULES"
export SELECTED_MODULES_LIST="${SELECTED_MODULES[*]}"
export INPUT_METHOD="$INPUT_METHOD"
export AUTO_MODE="$AUTO_MODE"
export REQUIRED="Lib LibDRV LibLinux"
export ALL_MODULES="Admin BolList DayStac Dispanser DopDisp Econ EconRA EconRost Fluoro Kiosk KTFOMSAgentDisp KTFOMSAgentGosp KTFOMSAgentPolis KTFOMSAgentReg KubNaprAgent MainSestStac MedOsm MISAgent OtdelStac Pokoy RegPeople RegPol San SanDoc SpravkaOMS StatPol StatStac StatYear Tablo Talon Vedom VistaAgent WrachPol"

$module_content
EOF
        
        chmod +x "$temp_script"
        
        # Запускаем скрипт
        if ! bash "$temp_script"; then
            warning "Модуль $module_name завершился с ошибками, продолжаем..."
        fi
        
        # Удаляем временный скрипт
        rm -f "$temp_script"
    }
    
    # Модуль 1: Зависимости
    run_module_with_env \
        "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/01-dependencies.sh?cache=$(date +%s)" \
        "зависимости"
    
    # Модуль 2: Настройка Wine
    run_module_with_env \
        "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/02-wine-setup.sh?cache=$(date +%s)" \
        "Wine"
    
    # Модуль 3: Копирование файлов
    run_module_with_env \
        "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/03-copy-files.sh?cache=$(date +%s)" \
        "копирование"
    
    # Модуль 4: Исправление midas.dll
    run_module_with_env \
        "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/04-fix-midas.sh?cache=$(date +%s)" \
        "midas.dll"
    
    # Модуль 5: Создание ярлыков
    run_module_with_env \
        "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/05-create-shortcuts.sh?cache=$(date +%s)" \
        "ярлыки"
    
    # Создаем финальный фикс-скрипт
    create_final_script
}

# Создание финального скрипта
create_final_script() {
    local script_path="$HOME_DIR/final_fix_all.sh"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
export WINEPREFIX="$HOME/.wine_medorg"

echo "=== ФИНАЛЬНЫЙ ФИКС ДЛЯ ВСЕХ МОДУЛЕЙ ==="

# 1. Создаем ссылки для регистра
echo "1. Создание ссылок для разных регистров..."
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

# 3. Исправляем реестр
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
    
    success "Финальный фикс-скрипт создан: ~/final_fix_all.sh"
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
    
    if [ -n "$SELECTED_MODULES" ] && [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
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
    
    # Автоматический выход
    exit 0
}

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Установка прервана пользователем${NC}"; exit 1' INT

# Запуск (передаем все аргументы после --)
main "$@"