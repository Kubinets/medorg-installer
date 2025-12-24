#!/bin/bash
# Установка системных зависимостей - исправленная версия

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

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
}

# Установка winetricks
install_winetricks() {
    log "Установка Winetricks..."
    
    if ! command -v winetricks >/dev/null 2>&1; then
        echo -n "  Скачивание winetricks... "
        if wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /tmp/winetricks; then
            echo -e "${GREEN}✓${NC}"
            echo -n "  Установка в /usr/local/bin... "
            chmod +x /tmp/winetricks
            mv /tmp/winetricks /usr/local/bin/
            echo -e "${GREEN}✓${NC}"
            log "Winetricks установлен"
        else
            echo -e "${RED}✗${NC}"
            warning "Не удалось скачать winetricks"
        fi
    else
        success "Winetricks уже установлен"
    fi
}

# Установка зависимостей для Fedora/RHEL
install_fedora_deps() {
    print_section "УСТАНОВКА ЗАВИСИМОСТЕЙ FEDORA"
    
    echo -e "${CYAN}Этап 1: Обновление системы${NC}"
    dnf update -y --quiet
    
    echo ""
    echo -e "${CYAN}Этап 2: Базовые утилиты${NC}"
    dnf install -y wget curl cabextract p7zip p7zip-plugins unzip git --quiet
    
    echo ""
    echo -e "${CYAN}Этап 3: Графические библиотеки${NC}"
    dnf install -y freetype fontconfig libX11 libXext libXcursor libXi \
                  libXrandr libXinerama libXcomposite mesa-libGLU --quiet
    
    echo ""
    echo -e "${CYAN}Этап 4: Сетевые файловые системы${NC}"
    dnf install -y cifs-utils nfs-utils --quiet
    
    echo ""
    echo -e "${CYAN}Этап 5: Wine и компоненты${NC}"
    dnf install -y wine wine.i686 icoutils --quiet
    
    # Установка winetricks
    install_winetricks
    
    success "Зависимости установлены"
}

# Основная функция установки
install_dependencies() {
    print_section "УСТАНОВКА ЗАВИСИМОСТЕЙ"
    
    # Проверяем права
    if [ "$EUID" -ne 0 ]; then 
        error "Запустите с правами root: sudo $0"
        exit 1
    fi
    
    # Определяем ОС
    detect_system
    
    echo ""
    echo -e "${PURPLE}Начинаем установку зависимостей...${NC}"
    echo ""
    
    # Устанавливаем в зависимости от ОС
    case $OS in
        "fedora")
            install_fedora_deps
            ;;
        "debian")
            log "Для Debian/Ubuntu:"
            echo "sudo apt-get update && sudo apt-get install wine winetricks cabextract p7zip-full"
            ;;
        *)
            install_fedora_deps
            ;;
    esac
    
    success "Зависимости успешно установлены"
    echo ""
}

# Запуск
install_dependencies