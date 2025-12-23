#!/bin/bash
# MedOrg Installer v2.0
# Выборочная установка модулей MedOrg

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
REPO_URL="https://raw.githubusercontent.com/ваш-логин/medorg-installer/main"
INSTALL_DIR="/tmp/medorg-installer-$$"

# Функции вывода
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Списки папок
REQUIRED_FOLDERS=("Lib" "LibDRV" "LibLinux")  # Обязательные
OPTIONAL_FOLDERS=("BolList" "DayStac" "Dispanser" "DopDisp" "OtdelStac" 
                  "Pokoy" "RegPeople" "RegPol" "StatPol" "StatStac" 
                  "StatYear" "WrachPol")  # Опциональные (по выбору)

# Проверка интернета
check_internet() {
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null && ! ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        log_error "Нет подключения к интернету!"
        exit 1
    fi
}

# Скачивание файла
download_file() {
    local url="$1"
    local dest="$2"
    
    log_info "Скачивание: $(basename "$dest")"
    
    if command -v curl &>/dev/null; then
        curl -sSL --connect-timeout 30 "$url" -o "$dest"
    elif command -v wget &>/dev/null; then
        wget -q --timeout=30 "$url" -O "$dest"
    else
        log_error "Установите curl или wget!"
        exit 1
    fi
    
    if [ ! -s "$dest" ]; then
        log_error "Не удалось скачать: $url"
        return 1
    fi
    return 0
}

# Создание временной директории
setup_temp_dir() {
    rm -rf "$INSTALL_DIR" 2>/dev/null
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
}

# Проверка прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Запустите с правами root: sudo $0"
        exit 1
    fi
}

# Выбор пользователя
select_user() {
    echo ""
    echo "╔════════════════════════════════════════════════════╗"
    echo "║         Установка медицинской программы           ║"
    echo "║                  MedOrg v2.0                       ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""
    
    # Автоопределение пользователя
    if [ -n "$SUDO_USER" ]; then
        DEFAULT_USER="$SUDO_USER"
    else
        DEFAULT_USER=$(logname 2>/dev/null || echo "")
    fi
    
    if [ -z "$DEFAULT_USER" ] || [ "$DEFAULT_USER" = "root" ]; then
        DEFAULT_USER="meduser"
    fi
    
    read -p "Введите имя пользователя для установки [$DEFAULT_USER]: " TARGET_USER
    TARGET_USER=${TARGET_USER:-$DEFAULT_USER}
    
    # Проверка существования пользователя
    if ! id "$TARGET_USER" &>/dev/null; then
        log_warning "Пользователь '$TARGET_USER' не существует!"
        read -p "Создать пользователя '$TARGET_USER'? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            useradd -m -s /bin/bash "$TARGET_USER"
            echo "Установите пароль для нового пользователя:"
            passwd "$TARGET_USER"
            log_success "Пользователь '$TARGET_USER' создан"
        else
            log_error "Установка отменена"
            exit 1
        fi
    fi
    
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    log_success "Установка для пользователя: $TARGET_USER"
    log_success "Домашняя директория: $TARGET_HOME"
}

# Выбор модулей
select_modules() {
    echo ""
    echo "╔════════════════════════════════════════════════════╗"
    echo "║           ВЫБОР МОДУЛЕЙ ДЛЯ УСТАНОВКИ             ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""
    echo "Обязательно устанавливаются:"
    echo "  ${REQUIRED_FOLDERS[*]}"
    echo ""
    echo "Выберите дополнительные модули:"
    echo ""
    
    # Отображаем опциональные модули с номерами
    declare -A module_names
    module_names=(
        ["1"]="BolList" ["2"]="DayStac" ["3"]="Dispanser" ["4"]="DopDisp"
        ["5"]="OtdelStac" ["6"]="Pokoy" ["7"]="RegPeople" ["8"]="RegPol"
        ["9"]="StatPol" ["10"]="StatStac" ["11"]="StatYear" ["12"]="WrachPol"
    )
    
    # Показываем меню
    for i in {1..12}; do
        folder="${module_names[$i]}"
        echo "  $i. $folder"
    done
    
    echo ""
    echo "  13. Все модули"
    echo "  14. Только обязательные"
    echo ""
    
    while true; do
        read -p "Введите номера через пробел или диапазон (1-14): " choices
        
        if [ -z "$choices" ]; then
            log_warning "Не сделано ни одного выбора!"
            continue
        fi
        
        SELECTED_MODULES=()
        
        # Обрабатываем выбор
        for choice in $choices; do
            # Проверяем диапазон
            if [[ "$choice" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                start=${BASH_REMATCH[1]}
                end=${BASH_REMATCH[2]}
                for ((i=start; i<=end; i++)); do
                    choice=$i
                    # Пропускаем обработку диапазона дальше
                done
            fi
            
            case $choice in
                13)  # Все модули
                    SELECTED_MODULES=("${OPTIONAL_FOLDERS[@]}")
                    echo ""
                    log_success "Выбраны ВСЕ модули"
                    return
                    ;;
                14)  # Только обязательные
                    SELECTED_MODULES=()
                    echo ""
                    log_success "Выбраны только обязательные модули"
                    return
                    ;;
                [1-9]|1[0-2])  # Номера 1-12
                    folder="${module_names[$choice]}"
                    SELECTED_MODULES+=("$folder")
                    ;;
                *)
                    log_warning "Неверный выбор: $choice"
                    continue 2
                    ;;
            esac
        done
        
        # Удаляем дубликаты
        SELECTED_MODULES=($(echo "${SELECTED_MODULES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        
        if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            break
        else
            log_warning "Не выбрано ни одного модуля!"
        fi
    done
    
    echo ""
    log_success "Выбраны модули:"
    for module in "${SELECTED_MODULES[@]}"; do
        echo "  • $module"
    done
}

# Установка зависимостей
install_dependencies() {
    log_info "Установка системных зависимостей..."
    
    # Обновление системы
    if ! dnf update -y; then
        log_warning "Не удалось обновить систему, продолжаем..."
    fi
    
    # Основные утилиты
    dnf install -y wget curl cabextract p7zip unzip tar
    
    # Графические библиотеки
    dnf install -y freetype fontconfig libX11 libXext libXcursor libXi \
                   libXrandr libXinerama libXcomposite mesa-libGLU
    
    # Сетевые утилиты
    dnf install -y cifs-utils nfs-utils
    
    # Wine
    if ! dnf install -y wine wine.i686; then
        log_error "Не удалось установить Wine!"
        exit 1
    fi
    
    # Для иконок
    dnf install -y icoutils ImageMagick
    
    # Winetricks
    if [ ! -f /usr/local/bin/winetricks ]; then
        if wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; then
            chmod +x winetricks
            mv winetricks /usr/local/bin/
            log_success "Winetricks установлен"
        else
            log_warning "Не удалось установить winetricks"
        fi
    fi
    
    log_success "Зависимости установлены"
}

# Настройка Wine
setup_wine() {
    local user="$1"
    local home="$2"
    
    log_info "Настройка Wine для пользователя $user..."
    
    # Создаем Wine префикс
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 wineboot --init 2>/dev/null
    
    # Настраиваем winecfg
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 winecfg /v 2>/dev/null &
    
    # Устанавливаем компоненты через winetricks
    log_info "Установка компонентов Wine..."
    
    if [ -f /usr/local/bin/winetricks ]; then
        sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
            winetricks -q corefonts 2>/dev/null || true
        sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
            winetricks -q tahoma 2>/dev/null || true
        sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
            winetricks -q vcrun6 2>/dev/null || true
        sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
            winetricks -q mdac28 2>/dev/null || true
        sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" WINEARCH=win32 \
            winetricks -q jet40 2>/dev/null || true
    fi
    
    log_success "Wine настроен"
}

# Копирование файлов
copy_files() {
    local user="$1"
    local home="$2"
    
    log_info "Подключение к сетевой шаре..."
    
    # Создаем точку монтирования
    MOUNT_POINT="/tmp/medorg_mount_$$"
    mkdir -p "$MOUNT_POINT"
    
    # Монтируем сетевую шару
    if mount -t cifs //10.0.1.11/auto "$MOUNT_POINT" -o username=Администратор,password=Ybyjxrf30lh* 2>/dev/null; then
        log_success "Сетевая шара подключена"
        
        # Создаем целевую директорию
        TARGET_DIR="$home/.wine_medorg/drive_c/MedCTech/MedOrg"
        mkdir -p "$TARGET_DIR"
        
        # Всегда копируем обязательные папки
        log_info "Копирование обязательных папок..."
        for folder in "${REQUIRED_FOLDERS[@]}"; do
            if [ -d "$MOUNT_POINT/$folder" ]; then
                cp -r "$MOUNT_POINT/$folder" "$TARGET_DIR/"
                log_info "  ✓ $folder"
            else
                log_warning "  ✗ $folder не найдена на шаре"
            fi
        done
        
        # Копируем выбранные опциональные папки
        if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            log_info "Копирование выбранных модулей..."
            for folder in "${SELECTED_MODULES[@]}"; do
                if [ -d "$MOUNT_POINT/$folder" ]; then
                    cp -r "$MOUNT_POINT/$folder" "$TARGET_DIR/"
                    log_info "  ✓ $folder"
                else
                    log_warning "  ✗ $folder не найдена на шаре"
                fi
            done
        fi
        
        # Копируем необходимые файлы из корня
        log_info "Копирование общих файлов..."
        if [ -f "$MOUNT_POINT/midasregMedOrg.cmd" ]; then
            cp "$MOUNT_POINT/midasregMedOrg.cmd" "$TARGET_DIR/"
        fi
        if [ -f "$MOUNT_POINT/uninst.exe" ]; then
            cp "$MOUNT_POINT/uninst