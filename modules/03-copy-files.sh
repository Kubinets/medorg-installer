#!/bin/bash
# Копирование программы с настройкой сетевой папки - фиксированная версия

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
    
    # ФИКСИРОВАННЫЕ УЧЕТНЫЕ ДАННЫЕ
    local server="//10.0.1.11/auto"
    local username="Администратор"
    local password="Ybyjxrf30lh*"
    
    log "Адрес: $server"
    log "Пользователь: $username"
    
    # Создаем точку монтирования
    mkdir -p "$mount_point"
    
    # Формируем опции монтирования
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
            log "Пробуем без пароля..."
            
            # Пробуем без пароля
            local no_pass_options="username=$username,uid=$(id -u "$USER")"
            if mount -t cifs "$server" "$mount_point" -o "$no_pass_options" 2>&1; then
                success "Сетевая папка подключена без пароля"
                return 0
            else
                error "Все попытки подключения не удались"
                return 1
            fi
        fi
    fi
}

# Копирование файлов (ТОЛЬКО ВЫБРАННЫЕ МОДУЛИ)
copy_files() {
    local mount_point="/tmp/medorg_mount_$$"
    
    # Пытаемся подключиться
    if mount_network_share "$mount_point"; then
        log "Начинаем копирование файлов..."
        
        # Проверяем, что в сетевой папке есть файлы
        if [ ! -d "$mount_point" ] || [ -z "$(ls -A "$mount_point" 2>/dev/null)" ]; then
            error "Сетевая папка пуста или недоступна"
            umount "$mount_point" 2>/dev/null || true
            rmdir "$mount_point" 2>/dev/null || true
            return 1
        fi
        
        # Обязательные модули (всегда копируем)
        local required_modules=("Lib" "LibDRV" "LibLinux")
        
        # Выбранные пользователем модули
        local selected_modules=()
        if [ -n "$SELECTED_MODULES" ]; then
            # Если SELECTED_MODULES передана как строка
            if [[ "$SELECTED_MODULES" == "("* ]]; then
                # Это массив в строке, нужно распарсить
                selected_modules_str=$(echo "$SELECTED_MODULES" | sed 's/^(\(.*\))$/\1/')
                IFS=' ' read -ra selected_modules <<< "$selected_modules_str"
            else
                # Это обычный массив
                selected_modules=("${SELECTED_MODULES[@]}")
            fi
        fi
        
        log "Модули для копирования:"
        echo -e "${GREEN}Обязательные:${NC}"
        for module in "${required_modules[@]}"; do
            echo -e "  ${GREEN}•${NC} $module"
        done
        
        if [ ${#selected_modules[@]} -gt 0 ]; then
            echo ""
            echo -e "${CYAN}Выбранные пользователем:${NC}"
            for module in "${selected_modules[@]}"; do
                echo -e "  ${CYAN}•${NC} $module"
            done
        fi
        
        echo ""
        
        # Копируем обязательные модули
        log "Копирование обязательных модулей..."
        for module in "${required_modules[@]}"; do
            echo -n "  $module... "
            if [ -d "$mount_point/$module" ]; then
                cp -r "$mount_point/$module" "$TARGET_DIR/" 2>/dev/null || true
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC} (не найден в сетевой папке)"
            fi
        done
        
        # Копируем выбранные модули
        if [ ${#selected_modules[@]} -gt 0 ]; then
            log "Копирование выбранных модулей..."
            for module in "${selected_modules[@]}"; do
                echo -n "  $module... "
                if [ -d "$mount_point/$module" ]; then
                    cp -r "$mount_point/$module" "$TARGET_DIR/" 2>/dev/null || true
                    echo -e "${GREEN}✓${NC}"
                else
                    echo -e "${RED}✗${NC} (не найден в сетевой папке)"
                fi
            done
        else
            log "Пользователь не выбрал дополнительные модули"
        fi
        
        # Устанавливаем права
        chown -R "$USER:$USER" "$TARGET_DIR"/*
        
        success "Файлы скопированы"
        
        # Показываем что скопировалось
        log "Скопированные модули:"
        ls -la "$TARGET_DIR" | grep -E '^d' | awk '{print "  " $9}' | grep -E '^[A-Z]'
        
        # Отключаем сетевую папку
        umount "$mount_point" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
        
        return 0
    else
        warning "Не удалось подключиться к сетевой папке"
        log "Возможно, файлы уже скопированы ранее или нет доступа"
        
        # Проверяем, есть ли уже обязательные модули
        local all_required_exist=true
        for module in "Lib" "LibDRV" "LibLinux"; do
            if [ ! -d "$TARGET_DIR/$module" ]; then
                all_required_exist=false
                break
            fi
        done
        
        if [ "$all_required_exist" = true ]; then
            success "Обязательные модули уже существуют"
            return 0
        else
            error "Не удалось получить файлы программы"
            log "Попробуйте подключиться к сетевой папке вручную:"
            echo "mkdir -p /mnt/medorg"
            echo "mount -t cifs //10.0.1.11/auto /mnt/medorg -o username=Администратор,password=Ybyjxrf30lh*"
            echo ""
            echo "Затем скопируйте модули:"
            echo "cp -r /mnt/medorg/Lib /mnt/medorg/LibDRV /mnt/medorg/LibLinux $TARGET_DIR/"
            if [ ${#selected_modules[@]} -gt 0 ]; then
                echo "cp -r /mnt/medorg/{$(IFS=,; echo "${selected_modules[*]}")} $TARGET_DIR/"
            fi
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
    
    # Копирование файлов (только выбранных модулей)
    copy_files
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      КОПИРОВАНИЕ УСПЕШНО ЗАВЕРШЕНО!           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Показываем что установлено
    log "Установленные модули в $TARGET_DIR/:"
    if [ -d "$TARGET_DIR" ]; then
        ls -la "$TARGET_DIR" | grep -E '^d' | awk '{print "  " $9}' | sort | column -c 80
    fi
    echo ""
}

# Обработка прерывания
trap 'echo -e "\n${RED}Копирование прервано${NC}"; exit 1' INT

# Запуск
main "$@"