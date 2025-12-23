#!/bin/bash
# MedOrg Installer v3.0 - FIXED VERSION
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
    typewriter "   ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     " 0.001
    typewriter "   ██║██║ ╚████║███████╗   ██║   ██║  ██║███████╗███████╗" 0.001
    typewriter "   ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝" 0.001
    echo ""
    
    echo -e "${PURPLE}"
    typewriter "  ═══════════════════════════════════════════════════════════" 0.001
    echo ""
    
    echo -e "${GREEN}"
    typewriter "                     SYSTEM INSTALLER v3.0" 0.03
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
    USER="meduser"
    SELECTED_MODULES=()
    AUTO_MODE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user)
                USER="$2"
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
                SELECTED_MODULES=()
                shift
                ;;
            -h|--help)
                echo "Использование:"
                echo "  curl -sSL https://.../install.sh | sudo bash -- [ОПЦИИ]"
                echo ""
                echo "Опции:"
                echo "  --user ИМЯ        Имя пользователя (по умолчанию: meduser)"
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

# Выбор пользователя (обновленная версия)
select_user() {
    if [[ "$AUTO_MODE" == true ]] || [[ "$INPUT_METHOD" == "args" ]]; then
        # Используем аргументы или авто-режим
        log "Пользователь установлен: $USER"
    else
        # Интерактивный режим
        echo ""
        echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║           ВЫБОР ПОЛЬЗОВАТЕЛЯ                    ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Используем /dev/tty для чтения с терминала
        exec < /dev/tty
        
        read -p "Введите имя пользователя для установки [meduser]: " input_user
        USER="${input_user:-meduser}"
    fi
    
    # Проверка/создание пользователя
    if ! id "$USER" &>/dev/null; then
        if [[ "$AUTO_MODE" == true ]]; then
            # Автоматически создаем пользователя
            useradd -m -s /bin/bash "$USER"
            echo "$USER:$USER" | chpasswd  # Пароль = имя пользователя
            success "Пользователь '$USER' создан автоматически"
        elif [[ "$INPUT_METHOD" == "args" ]]; then
            warning "Пользователь '$USER' не существует."
            read -p "Создать пользователя '$USER'? (y/N): " -n 1 -r < /dev/tty
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                useradd -m -s /bin/bash "$USER"
                passwd "$USER"
                success "Пользователь '$USER' создан"
            else
                error "Пользователь не существует"
            fi
        else
            read -p "Создать пользователя '$USER'? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                useradd -m -s /bin/bash "$USER"
                passwd "$USER"
                success "Пользователь '$USER' создан"
            else
                error "Пользователь не существует"
            fi
        fi
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
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           ВЫБОР МОДУЛЕЙ                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Обязательные модули: ${REQUIRED[*]}"
    echo ""
    
    echo "Дополнительные модули (по 4 в строке):"
    for i in "${!ALL_MODULES[@]}"; do
        printf "  %2d. %-20s" $((i+1)) "${ALL_MODULES[i]}"
        if [ $(((i+1) % 4)) -eq 0 ] || [ $((i+1)) -eq ${#ALL_MODULES[@]} ]; then
            echo ""
        fi
    done
    
    echo ""
    echo "  a. Все модули"
    echo "  n. Только обязательные"
    echo ""
    
    # Читаем с терминала
    if [[ "$INPUT_METHOD" == "args" ]]; then
        exec < /dev/tty
    fi
    
    while true; do
        read -p "Выберите модули (номера через пробел, 'a' или 'n'): " choices
        
        SELECTED_MODULES=()
        
        case "$choices" in
            a|A)
                SELECTED_MODULES=("${ALL_MODULES[@]}")
                success "Выбраны ВСЕ модули"
                return
                ;;
            n|N)
                SELECTED_MODULES=()
                success "Только обязательные модули"
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
        echo "  • $module"
    done
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
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Установлено для: $USER"
    echo ""
    
    echo "Обязательные модули:"
    for module in "${REQUIRED[@]}"; do
        echo "  ✓ $module"
    done
    echo ""
    
    if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
        echo "Дополнительные модули:"
        for module in "${SELECTED_MODULES[@]}"; do
            echo "  ✓ $module"
        done
        echo ""
    fi
    
    echo "Ярлыки созданы в:"
    echo "  $HOME_DIR/Рабочий стол/Медицинские программы/"
    echo ""
    echo "Для запуска программы:"
    echo "  1. Войдите как пользователь: $USER"
    echo "  2. На рабочем столе откройте 'Медицинские программы'"
    echo "  3. Запустите нужный модуль двойным кликом"
    echo ""
    echo "При проблемах с midas.dll выполните:"
    echo "  ~/fix_midas_case.sh"
    echo ""
}

# Запуск (передаем все аргументы после --)
main "$@"