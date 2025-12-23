#!/bin/bash
# MedOrg Installer v3.1 - FIXED VERSION
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
    typewriter "                     SYSTEM INSTALLER v3.2" 0.03
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

# Списки папок
REQUIRED=("Lib" "LibDRV" "LibLinux")
ALL_MODULES=("Admin" "BolList" "DayStac" "Dispanser" "DopDisp" 
             "Econ" "EconRA" "EconRost" "Fluoro" "Kiosk" 
             "KTFOMSAgentDisp" "KTFOMSAgentGosp" "KTFOMSAgentPolis" 
             "KTFOMSAgentReg" "KubNaprAgent" "MainSestStac" 
             "MedOsm" "MISAgent" "OtdelStac" "Pokoy" "RegPeople" 
             "RegPol" "San" "SanDoc" "SpravkaOMS" "StatPol" 
             "StatStac" "StatYear" "Tablo" "Talon" "Vedom" 
             "VistaAgent" "WrachPol")

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
        # Показываем только пользователей с домашней директорией (обычные пользователи)
        getent passwd | grep -E ':/home/' | cut -d: -f1 | sort | column -c 80
        echo ""
        
        if [[ "$INPUT_METHOD" == "args" ]]; then
            # В режиме пайпа читаем с терминала
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
            # Спрашиваем, создавать ли нового пользователя
            if [[ "$INPUT_METHOD" == "args" ]]; then
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
    
    # Читаем с терминала
    if [[ "$INPUT_METHOD" == "args" ]]; then
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
    echo ""
    
    echo -e "${CYAN}Установленные модули:${NC}"
    echo -e "${BLUE}─────────────────────${NC}"
    echo -e "${GREEN}Обязательные:${NC}"
    for module in "${REQUIRED[@]}"; do
        echo -e "  ✓ $module"
    done
    
    if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Дополнительные:${NC}"
        for module in "${SELECTED_MODULES[@]}"; do
            echo -e "  ✓ $module"
        done
    fi
    
    echo ""
    echo -e "${CYAN}Расположение:${NC}"
    echo -e "${BLUE}─────────────${NC}"
    echo -e "Программы:      ${YELLOW}$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg/${NC}"
    echo -e "Ярлыки:         ${YELLOW}$HOME_DIR/Рабочий стол/Медицинские программы/${NC}"
    
    echo ""
    echo -e "${CYAN}Инструкция по запуску:${NC}"
    echo -e "${BLUE}──────────────────────${NC}"
    echo "1. Войдите в систему как пользователь: ${GREEN}$USER${NC}"
    echo "2. На рабочем столе откройте папку '${YELLOW}Медицинские программы${NC}'"
    echo "3. Запустите нужный модуль двойным кликом"
    echo ""
    echo -e "${CYAN}Примечания:${NC}"
    echo -e "${BLUE}──────────${NC}"
    echo "• При проблемах с midas.dll выполните: ${YELLOW}~/fix_midas_case.sh${NC}"
    echo "• Для настройки Wine: ${YELLOW}~/setup_wine_later.sh${NC}"
    echo ""
    
    echo -e "${GREEN}──────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Спасибо за использование нашего установщика!${NC}"
    echo -e "${GREEN}──────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Выходим автоматически через 5 секунд
    echo -n "Скрипт завершится автоматически через "
    for i in {5..1}; do
        echo -n "$i "
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
    
    # Установка модулей
    print_section "НАЧАЛО УСТАНОВКИ"
    log "Начинаем установку..."
    
    # Модуль 1: Зависимости
    log "Установка зависимостей..."
    source <(curl -s https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/01-dependencies.sh)
    
    # Модуль 2: Настройка Wine
    log "Настройка Wine..."
    export TARGET_USER="$USER"
    export TARGET_HOME="$HOME_DIR"
    source <(curl -s https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/02-wine-setup.sh)
    
    # Модуль 3: Копирование файлов
    log "Копирование программы..."
    export SELECTED_MODULES
    source <(curl -s https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/03-copy-files.sh)
    
    # Модуль 4: Исправление midas.dll
    log "Исправление midas.dll..."
    source <(curl -s https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/04-fix-midas.sh)
    
    # Модуль 5: Создание ярлыков
    log "Создание ярлыков..."
    source <(curl -s https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/05-create-shortcuts.sh)
    
    # Завершение
    show_completion
    
    # Автоматический выход
    exit 0
}

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Установка прервана пользователем${NC}"; exit 1' INT

# Запуск (передаем все аргументы после --)
main "$@"