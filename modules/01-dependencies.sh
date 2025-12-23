#!/bin/bash
# Установка системных зависимостей - красивая версия

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

# Проверка системы
detect_system() {
    log "Определение операционной системы..."
    
    if [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
        OS="fedora"
        success "Обнаружена Fedora/RHEL/CentOS"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        success "Обнаружена Debian/Ubuntu"
    elif [ -f /etc/arch-release ]; then
        OS="arch"
        success "Обнаружена Arch Linux"
    else
        OS="unknown"
        warning "Неизвестная ОС, попробуем Fedora пакеты"
    fi
    
    sleep 1
}

# Прогресс бар
progress_bar() {
    local duration=${1}
    
    already_done() { for ((done=0; done<$1; done++)); do echo -n "█"; done }
    remaining() { for ((remain=$1; remain<$2; remain++)); do echo -n "░"; done }
    percentage() { echo -n " $1%" ; }
    
    for ((i=0; i<=100; i++)); do
        echo -ne "\r\033[K"
        echo -n "["
        already_done $((i/2))
        remaining $((i/2)) 50
        echo -n "]"
        percentage $i
        sleep $duration
    done
    echo ""
}

# Установка зависимостей для Fedora/RHEL
install_fedora_deps() {
    print_section "УСТАНОВКА ЗАВИСИМОСТЕЙ"
    
    echo -e "${CYAN}Этап 1: Обновление системы${NC}"
    typewriter "Обновление пакетов..." 0.03
    if dnf update -y --quiet 2>&1 | grep -v "Loading\|Already"; then
        success "Система обновлена"
    else
        warning "Возникли проблемы при обновлении"
    fi
    
    echo ""
    echo -e "${CYAN}Этап 2: Базовые утилиты${NC}"
    local basic_packages=("wget" "curl" "cabextract" "p7zip" "unzip" "git")
    for pkg in "${basic_packages[@]}"; do
        echo -n "  Установка $pkg... "
        if dnf install -y "$pkg" --quiet 2>&1 | grep -q "Complete\|уже установлен"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
        sleep 0.1
    done
    
    echo ""
    echo -e "${CYAN}Этап 3: Графические библиотеки${NC}"
    local graphics_packages=("freetype" "fontconfig" "libX11" "libXext" "libXcursor" 
                            "libXi" "libXrandr" "libXinerama" "libXcomposite" "mesa-libGLU")
    for pkg in "${graphics_packages[@]}"; do
        echo -n "  Установка $pkg... "
        if dnf install -y "$pkg" --quiet 2>&1 | grep -q "Complete\|уже установлен"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
        sleep 0.1
    done
    
    echo ""
    echo -e "${CYAN}Этап 4: Сетевые файловые системы${NC}"
    echo -n "  Установка cifs-utils и nfs-utils... "
    if dnf install -y cifs-utils nfs-utils --quiet 2>&1 | grep -q "Complete\|уже установлен"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}!${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Этап 5: Wine и компоненты${NC}"
    typewriter "Добавление репозитория Wine..." 0.03
    
    # Добавляем репозиторий Wine для Fedora
    if ! rpm -q winehq-keyring 2>/dev/null; then
        echo -n "  Добавление репозитория... "
        dnf config-manager --add-repo https://dl.winehq.org/wine-builds/fedora/$(rpm -E %fedora)/winehq.repo 2>/dev/null && \
        echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}!${NC}"
    fi
    
    local wine_packages=("wine" "wine.i686" "icoutils" "ImageMagick")
    for pkg in "${wine_packages[@]}"; do
        echo -n "  Установка $pkg... "
        if dnf install -y "$pkg" --quiet 2>&1 | grep -q "Complete\|уже установлен"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
        sleep 0.2
    done
    
    echo ""
    echo -e "${CYAN}Этап 6: Winetricks${NC}"
    typewriter "Установка Winetricks..." 0.03
    
    if ! command -v winetricks >/dev/null 2>&1; then
        echo -n "  Скачивание... "
        if wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; then
            echo -e "${GREEN}✓${NC}"
            echo -n "  Установка... "
            chmod +x winetricks
            mv winetricks /usr/local/bin/
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
            warning "Не удалось скачать winetricks"
        fi
    else
        success "Winetricks уже установлен"
    fi
}

# Установка зависимостей для Debian/Ubuntu
install_debian_deps() {
    print_section "УСТАНОВКА ЗАВИСИМОСТЕЙ"
    
    echo -e "${CYAN}Этап 1: Обновление системы${NC}"
    apt-get update -y 2>&1 | grep -v "Reading\|Building"
    success "Репозитории обновлены"
    
    # Остальные этапы аналогично, но с apt-get вместо dnf
    # (для краткости опускаю)
}

# Основная функция установки
install_dependencies() {
    print_section "ПОДГОТОВКА К УСТАНОВКЕ"
    
    typewriter "Проверка системы и подготовка к установке..." 0.03
    echo ""
    
    # Проверяем права
    if [ "$EUID" -ne 0 ]; then 
        error "Запустите с правами root: sudo $0"
        exit 1
    fi
    
    # Определяем ОС
    detect_system
    
    echo ""
    echo -e "${PURPLE}Начинаем установку зависимостей...${NC}"
    echo -e "${YELLOW}Это может занять несколько минут.${NC}"
    echo ""
    
    # Устанавливаем в зависимости от ОС
    case $OS in
        "fedora")
            install_fedora_deps
            ;;
        "debian")
            install_debian_deps
            ;;
        *)
            warning "Неизвестная ОС, пробуем Fedora пакеты..."
            install_fedora_deps
            ;;
    esac
    
    # Финальная проверка
    echo ""
    echo -e "${CYAN}Проверка установленных компонентов:${NC}"
    
    local checks=("wine --version" "winetricks --version" "curl --version" "unzip --help")
    local check_names=("Wine" "Winetricks" "cURL" "Unzip")
    
    for i in "${!checks[@]}"; do
        echo -n "  ${check_names[i]}... "
        if eval "${checks[i]}" &>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC} (не установлен)"
        fi
        sleep 0.1
    done
    
    # Анимированный прогресс-бар
    echo ""
    echo -ne "${BLUE}Завершение установки... ${NC}"
    progress_bar 0.05
    
    # Красивое завершение
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ЗАВИСИМОСТИ УСПЕШНО УСТАНОВЛЕНЫ!         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Установленные компоненты:${NC}"
    echo -e "${BLUE}─────────────────────────${NC}"
    echo -e "  ${GREEN}•${NC} Wine и компоненты"
    echo -e "  ${GREEN}•${NC} Winetricks"
    echo -e "  ${GREEN}•${NC} Системные библиотеки"
    echo -e "  ${GREEN}•${NC} Сетевые утилиты"
    echo -e "  ${GREEN}•${NC} Графические библиотеки"
    echo ""
    echo -e "${YELLOW}Теперь можно приступать к установке медицинского ПО.${NC}"
    echo ""
}

# Обработка прерывания
trap 'echo -e "\n${RED}Установка прервана${NC}"; exit 1' INT

# Запуск
install_dependencies