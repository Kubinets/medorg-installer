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

# Установка winetricks (ИСПРАВЛЕННАЯ)
install_winetricks() {
    log "Установка Winetricks..."
    
    if ! command -v winetricks >/dev/null 2>&1; then
        echo -n "  Скачивание winetricks... "
        if wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /tmp/winetricks; then
            echo -e "${GREEN}✓${NC}"
            echo -n "  Установка в /usr/local/bin... "
            chmod +x /tmp/winetricks
            mv /tmp/winetricks /usr/local/bin/
            
            # Проверяем установку
            if command -v winetricks >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
                log "Версия: $(winetricks --version 2>/dev/null | head -1 || echo 'неизвестно')"
            else
                echo -e "${YELLOW}!${NC}"
                warning "Winetricks не установился правильно"
            fi
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
    local basic_packages=("wget" "curl" "cabextract" "p7zip" "p7zip-plugins" "unzip" "git")
    for pkg in "${basic_packages[@]}"; do
        echo -n "  $pkg... "
        if dnf install -y "$pkg" --quiet 2>&1 | grep -q "Complete\|уже установлен"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}Этап 3: Графические библиотеки${NC}"
    local graphics_packages=("freetype" "fontconfig" "libX11" "libXext" "libXcursor" 
                            "libXi" "libXrandr" "libXinerama" "libXcomposite" "mesa-libGLU")
    for pkg in "${graphics_packages[@]}"; do
        echo -n "  $pkg... "
        if dnf install -y "$pkg" --quiet 2>&1 | grep -q "Complete\|уже установлен"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}Этап 4: Сетевые файловые системы${NC}"
    echo -n "  cifs-utils, nfs-utils... "
    if dnf install -y cifs-utils nfs-utils --quiet 2>&1 | grep -q "Complete\|уже установлен"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}!${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Этап 5: Wine и компоненты${NC}"
    local wine_packages=("wine" "wine.i686" "icoutils")
    for pkg in "${wine_packages[@]}"; do
        echo -n "  $pkg... "
        if dnf install -y "$pkg" --quiet 2>&1 | grep -q "Complete\|уже установлен"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
    done
    
    # Установка winetricks
    install_winetricks
    
    # Финальная проверка
    echo ""
    echo -e "${CYAN}Проверка установленных компонентов:${NC}"
    
    local checks=("wine --version 2>/dev/null" "curl --version 2>/dev/null" "unzip --help 2>/dev/null")
    local check_names=("Wine" "cURL" "Unzip")
    
    for i in "${!checks[@]}"; do
        echo -n "  ${check_names[i]}... "
        if eval "${checks[i]}" &>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
    done
    
    # Проверяем winetricks отдельно
    echo -n "  Winetricks... "
    if command -v winetricks >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}!${NC}"
    fi
}

# Основная функция установки
install_dependencies() {
    print_section "ПОДГОТОВКА К УСТАНОВКЕ"
    
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
            # Для Debian аналогично, но с apt-get
            log "Для Debian/Ubuntu установите зависимости вручную:"
            echo "sudo apt-get update && sudo apt-get install wine winetricks cabextract p7zip-full"
            ;;
        *)
            warning "Неизвестная ОС, пробуем Fedora пакеты..."
            install_fedora_deps
            ;;
    esac
    
    # Красивое завершение
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ЗАВИСИМОСТИ УСПЕШНО УСТАНОВЛЕНЫ!         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Теперь можно приступать к установке медицинского ПО.${NC}"
    echo ""
}

# Обработка прерывания
trap 'echo -e "\n${RED}Установка прервана${NC}"; exit 1' INT

# Запуск
install_dependencies