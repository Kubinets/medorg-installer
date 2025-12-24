#!/bin/bash
# Копирование программы с настройкой сетевой папки - исправленная версия

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# Проверка окружения
check_environment() {
    log "Проверка окружения..."
    
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        error "Переменные TARGET_USER и TARGET_HOME не установлены"
        exit 1
    fi
    
    if ! id "$TARGET_USER" &>/dev/null; then
        error "Пользователь $TARGET_USER не существует"
        exit 1
    fi
    
    USER="$TARGET_USER"
    HOME_DIR="$TARGET_HOME"
    TARGET_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    
    log "Пользователь: $USER"
    log "Целевая директория: $TARGET_DIR"
    
    # Создаем директорию
    mkdir -p "$TARGET_DIR"
    chown -R "$USER:$USER" "$(dirname "$TARGET_DIR")"
    
    success "Окружение проверено"
}

# Подключение к сетевой папке
mount_network_share() {
    local mount_point="$1"
    
    log "Подключение к сетевой папке..."
    
    # Параметры подключения (как в ручной установке)
    local server="//10.0.1.11/auto"
    local username="Администратор"
    local password="Ybyjxrf30lh*"
    
    log "Адрес: $server"
    log "Пользователь: $username"
    
    # Создаем точку монтирования
    mkdir -p "$mount_point"
    
    # Пробуем подключиться
    local mount_options="username=$username,password=$password,uid=$(id -u "$USER"),gid=$(id -g "$USER"),iocharset=utf8,file_mode=0777,dir_mode=0777"
    
    if mount -t cifs "$server" "$mount_point" -o "$mount_options" 2>&1; then
        success "Сетевая папка успешно подключена"
        return 0
    else
        warning "Не удалось подключиться с основными опциями"
        
        # Альтернативные опции
        local alt_options="username=$username,password=$password,uid=$(id -u "$USER")"
        
        if mount -t cifs "$server" "$mount_point" -o "$alt_options" 2>&1; then
            success "Сетевая папка подключена с альтернативными опциями"
            return 0
        else
            error "Не удалось подключиться к сетевой папке"
            return 1
        fi
    fi
}

# Копирование файлов
copy_files() {
    local mount_point="/tmp/medorg_mount_$$"
    
    # Пытаемся подключиться
    if mount_network_share "$mount_point"; then
        log "Начинаем копирование файлов..."
        
        # Копируем ВСЕ содержимое (как в ручной установке)
        log "Копируем все файлы из сетевой папки..."
        cp -r "$mount_point"/* "$TARGET_DIR"/ 2>/dev/null || true
        
        # Устанавливаем права
        chown -R "$USER:$USER" "$TARGET_DIR"/*
        
        success "Файлы скопированы"
        
        # Показываем что скопировалось
        log "Содержимое целевой директории:"
        ls -la "$TARGET_DIR" | head -15
        
        # Отключаем сетевую папку
        umount "$mount_point" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
        
        return 0
    else
        warning "Не удалось подключиться к сетевой папке"
        log "Возможно, файлы уже скопированы ранее или нет доступа"
        
        # Проверяем, есть ли уже файлы
        if [ -d "$TARGET_DIR/Lib" ]; then
            success "Файлы уже существуют в целевой директории"
            return 0
        else
            error "Нет доступа к файлам. Проверьте сетевую папку вручную."
            return 1
        fi
    fi
}

# Основная функция
main() {
    echo ""
    echo -e "${CYAN}КОПИРОВАНИЕ ПРОГРАММ ИЗ СЕТЕВОЙ ПАПКИ${NC}"
    echo ""
    
    # Проверка окружения
    check_environment
    
    # Копирование файлов
    copy_files
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      КОПИРОВАНИЕ УСПЕШНО ЗАВЕРШЕНО!           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Расположение программ:${NC}"
    echo -e "${BLUE}──────────────────────${NC}"
    echo -e "  ${YELLOW}$TARGET_DIR/${NC}"
    echo ""
    echo -e "${CYAN}Для проверки выполните:${NC}"
    echo -e "${BLUE}──────────────────────${NC}"
    echo -e "  ${YELLOW}ls -la $TARGET_DIR/${NC}"
    echo ""
}

# Обработка прерывания
trap 'echo -e "\n${RED}Копирование прервано${NC}"; exit 1' INT

# Запуск
main "$@"