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

# Установка winetricks (ИСПРАВЛЕННАЯ)
install_winetricks() {
    log "Установка Winetricks..."
    
    if command -v winetricks >/dev/null 2>&1; then
        success "Winetricks уже установлен"
        return
    fi
    
    echo -n "  Скачивание winetricks... "
    if wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/local/bin/winetricks; then
        echo -e "${GREEN}✓${NC}"
        chmod +x /usr/local/bin/winetricks
        
        # Проверяем что winetricks доступен
        if command -v winetricks >/dev/null 2>&1; then
            echo -n "  Проверка версии... "
            winetricks --version 2>/dev/null | head -1 | tr -d '\n'
            echo -e " ${GREEN}✓${NC}"
            success "Winetricks установлен"
        else
            echo -n "  Добавление в PATH... "
            ln -sf /usr/local/bin/winetricks /usr/bin/winetricks 2>/dev/null || true
            echo -e "${GREEN}✓${NC}"
        fi
    else
        echo -e "${RED}✗${NC}"
        warning "Не удалось скачать winetricks"
    fi
}

# Установка иконок и инструментов
install_icon_tools() {
    log "Установка инструментов для иконок..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y icoutils ImageMagick --quiet
        echo -e "  ${GREEN}✓${NC} icoutils и ImageMagick установлены"
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get install -y icoutils imagemagick
        echo -e "  ${GREEN}✓${NC} icoutils и ImageMagick установлены"
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
    dnf install -y wine wine.i686 --quiet
    
    # Установка winetricks
    install_winetricks
    
    # Установка инструментов для иконок
    install_icon_tools
    
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
    
    echo ""
    echo -e "${PURPLE}Начинаем установку зависимостей...${NC}"
    echo ""
    
    # Для Fedora/RHEL
    install_fedora_deps
    
    # Финальная проверка
    echo ""
    echo -e "${CYAN}Проверка установленных компонентов:${NC}"
    
    local checks=(
        "wine --version 2>/dev/null"
        "curl --version 2>/dev/null"
        "winetricks --version 2>/dev/null"
        "wrestool --help 2>/dev/null"
        "convert --version 2>/dev/null"
    )
    
    local check_names=("Wine" "cURL" "Winetricks" "Wrestool" "ImageMagick")
    
    for i in "${!checks[@]}"; do
        echo -n "  ${check_names[i]}... "
        if eval "${checks[i]}" &>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC}"
        fi
    done
    
    echo ""
    success "Зависимости успешно установлены"
}

# Запуск
install_dependencies