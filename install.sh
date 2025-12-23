#!/bin/bash
# MedOrg Installer - Main Script
# Установка медицинской программы MedOrg

set -e

# Конфигурация
VERSION="3.0"
REPO_URL="https://github.com/ваш-логин/medorg-installer"
MODULES_URL="https://raw.githubusercontent.com/ваш-логин/medorg-installer/main/modules"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции
log() { echo -e "${BLUE}[MedOrg Installer]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}!${NC} $1"; }

# Заголовок
print_header() {
    clear
    echo "╔════════════════════════════════════════════════════╗"
    echo "║           МЕДИЦИНСКАЯ ПРОГРАММА MEDORG            ║"
    echo "║                 Установщик v${VERSION}                   ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""
}

# Проверка root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "Запустите с правами root: sudo $0"
    fi
}

# Скачивание модуля
download_module() {
    local module=$1
    local url="${MODULES_URL}/${module}"
    local dest="/tmp/${module}"
    
    log "Загрузка: ${module}"
    
    if command -v curl >/dev/null; then
        curl -sSL "$url" -o "$dest" || error "Не удалось скачать ${module}"
    elif command -v wget >/dev/null; then
        wget -q "$url" -O "$dest" || error "Не удалось скачать ${module}"
    else
        error "Установите curl или wget"
    fi
    
    chmod +x "$dest"
    echo "$dest"
}

# Основной процесс
main() {
    print_header
    
    # Проверка
    check_root
    
    # Информация
    log "Репозиторий: ${REPO_URL}"
    log "Начало установки..."
    
    # Скачиваем модули
    log "Скачивание модулей..."
    
    DEPS_MODULE=$(download_module "01-dependencies.sh")
    WINE_MODULE=$(download_module "02-wine-setup.sh") 
    COPY_MODULE=$(download_module "03-copy-files.sh")
    FIX_MODULE=$(download_module "04-fix-midas.sh")
    LAUNCH_MODULE=$(download_module "05-create-launchers.sh")
    
    # Запускаем модули
    log "Запуск модулей..."
    
    # 1. Зависимости
    source "$DEPS_MODULE"
    
    # 2. Вопросы пользователю
    echo ""
    read -p "Введите имя пользователя для установки [meduser]: " USERNAME
    USERNAME=${USERNAME:-meduser}
    
    echo ""
    echo "Выберите модули для установки:"
    echo "1. Статистика (StatStac, StatPol, StatYear)"
    echo "2. Регистратура (RegPol, RegPeople)"
    echo "3. Врачебные (WrachPol, DopDisp)"
    echo "4. Все модули"
    echo ""
    
    read -p "Ваш выбор (1-4): " CHOICE
    
    # 3. Настройка Wine
    source "$WINE_MODULE" "$USERNAME"
    
    # 4. Копирование файлов
    source "$COPY_MODULE" "$USERNAME" "$CHOICE"
    
    # 5. Исправление midas.dll
    source "$FIX_MODULE" "$USERNAME"
    
    # 6. Создание ярлыков
    source "$LAUNCH_MODULE" "$USERNAME" "$CHOICE"
    
    # Завершение
    echo ""
    success "Установка завершена!"
    echo ""
    echo "Для запуска программы:"
    echo "1. Войдите как пользователь: $USERNAME"
    echo "2. На рабочем столе: 'Медицинские программы'"
    echo "3. Или из терминала: ~/medorg_launcher.sh"
    echo ""
    echo "Документация: ${REPO_URL}"
}

# Запуск
main "$@"