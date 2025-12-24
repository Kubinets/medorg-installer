#!/bin/bash
# Копирование программы с настройкой сетевой папки - ИСПРАВЛЕННАЯ версия

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
            return 1
        fi
    fi
}

# Парсинг выбранных модулей (простая версия)
get_selected_modules() {
    local modules=()
    
    # Если есть переменная SELECTED_MODULES_LIST
    if [ -n "$SELECTED_MODULES_LIST" ]; then
        IFS=' ' read -ra modules <<< "$SELECTED_MODULES_LIST"
    # Если есть переменная SELECTED_MODULES (как строка)
    elif [ -n "$SELECTED_MODULES" ]; then
        # Удаляем лишние символы
        local clean_str=$(echo "$SELECTED_MODULES" | tr -d '()[]"' | sed 's/^ *//;s/ *$//')
        IFS=' ' read -ra modules <<< "$clean_str"
    fi
    
    echo "${modules[@]}"
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
        
        # Получаем выбранные модули
        local selected_modules=($(get_selected_modules))
        
        log "Модули для копирования:"
        echo ""
        echo -e "${GREEN}Обязательные (всегда):${NC}"
        for module in "${required_modules[@]}"; do
            echo -e "  ${GREEN}•${NC} $module"
        done
        
        echo ""
        if [ ${#selected_modules[@]} -gt 0 ]; then
            echo -e "${CYAN}Выбранные пользователем:${NC}"
            for module in "${selected_modules[@]}"; do
                echo -e "  ${CYAN}•${NC} $module"
            done
            echo ""
        else
            echo -e "${YELLOW}Дополнительные модули не выбраны${NC}"
            echo ""
        fi
        
        # Копируем обязательные модули
        log "Копирование обязательных модулей..."
        local copied_required=0
        for module in "${required_modules[@]}"; do
            echo -n "  $module... "
            if [ -d "$mount_point/$module" ]; then
                cp -r "$mount_point/$module" "$TARGET_DIR/" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓${NC}"
                    copied_required=$((copied_required + 1))
                else
                    echo -e "${RED}✗${NC} (ошибка копирования)"
                fi
            else
                echo -e "${RED}✗${NC} (не найден в сетевой папке)"
            fi
        done
        
        # Копируем выбранные модули
        if [ ${#selected_modules[@]} -gt 0 ]; then
            log "Копирование выбранных модулей..."
            local copied_selected=0
            for module in "${selected_modules[@]}"; do
                # Проверяем, что модуль не обязательный (на всякий случай)
                if [[ " ${required_modules[@]} " =~ " ${module} " ]]; then
                    continue
                fi
                
                echo -n "  $module... "
                if [ -d "$mount_point/$module" ]; then
                    cp -r "$mount_point/$module" "$TARGET_DIR/" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✓${NC}"
                        copied_selected=$((copied_selected + 1))
                    else
                        echo -e "${RED}✗${NC} (ошибка копирования)"
                    fi
                else
                    echo -e "${RED}✗${NC} (не найден в сетевой папке)"
                fi
            done
        fi
        
        # Устанавливаем права
        chown -R "$USER:$USER" "$TARGET_DIR" 2>/dev/null
        
        # Итог копирования
        echo ""
        if [ $copied_required -eq ${#required_modules[@]} ]; then
            success "Обязательные модули скопированы: $copied_required/${#required_modules[@]}"
        else
            warning "Скопированы не все обязательные модули: $copied_required/${#required_modules[@]}"
        fi
        
        if [ ${#selected_modules[@]} -gt 0 ]; then
            if [ $copied_selected -eq ${#selected_modules[@]} ]; then
                success "Выбранные модули скопированы: $copied_selected/${#selected_modules[@]}"
            else
                warning "Скопированы не все выбранные модули: $copied_selected/${#selected_modules[@]}"
            fi
        fi
        
        # Показываем что скопировалось
        log "Скопированные модули в $TARGET_DIR:"
        if [ -d "$TARGET_DIR" ]; then
            ls -la "$TARGET_DIR" | grep -E '^d' | awk '{print "  " $9}' | grep -E '^[A-Z]' | sort
        fi
        
        # Отключаем сетевую папку
        umount "$mount_point" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
        
        return 0
    else
        warning "Не удалось подключиться к сетевой папке"
        
        # Проверяем, есть ли уже файлы
        if [ -d "$TARGET_DIR/Lib" ] && [ -d "$TARGET_DIR/LibDRV" ] && [ -d "$TARGET_DIR/LibLinux" ]; then
            success "Обязательные модули уже существуют в целевой директории"
            return 0
        else
            error "Нет доступа к файлам программы"
            log "Для ручного копирования выполните:"
            echo ""
            echo "1. Подключите сетевую папку:"
            echo "   sudo mkdir -p /mnt/medorg"
            echo "   sudo mount -t cifs //10.0.1.11/auto /mnt/medorg -o username=Администратор,password=Ybyjxrf30lh*"
            echo ""
            echo "2. Скопируйте модули:"
            echo "   sudo cp -r /mnt/medorg/Lib /mnt/medorg/LibDRV /mnt/medorg/LibLinux $TARGET_DIR/"
            echo ""
            
            # Получаем выбранные модули для показа в инструкции
            local selected_modules=($(get_selected_modules))
            if [ ${#selected_modules[@]} -gt 0 ]; then
                echo "   # И выбранные модули:"
                for module in "${selected_modules[@]}"; do
                    echo "   sudo cp -r /mnt/medorg/$module $TARGET_DIR/"
                done
                echo ""
            fi
            
            echo "3. Исправьте права:"
            echo "   sudo chown -R $USER:$USER $TARGET_DIR"
            echo "   sudo chmod -R 755 $TARGET_DIR"
            return 1
        fi
    fi
}

# Отладка - показываем переменные
debug_info() {
    echo ""
    echo -e "${CYAN}=== ОТЛАДОЧНАЯ ИНФОРМАЦИЯ ===${NC}"
    echo -e "TARGET_USER: ${GREEN}$TARGET_USER${NC}"
    echo -e "TARGET_HOME: ${GREEN}$TARGET_HOME${NC}"
    echo -e "SELECTED_MODULES: ${YELLOW}$SELECTED_MODULES${NC}"
    echo -e "SELECTED_MODULES_LIST: ${YELLOW}$SELECTED_MODULES_LIST${NC}"
    echo -e "INPUT_METHOD: ${BLUE}$INPUT_METHOD${NC}"
    echo -e "AUTO_MODE: ${BLUE}$AUTO_MODE${NC}"
    echo ""
}

# Основная функция
main() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}          КОПИРОВАНИЕ ПРОГРАММ ИЗ СЕТЕВОЙ ПАПКИ         ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Показываем отладочную информацию
    debug_info
    
    # Проверка окружения
    check_environment
    
    # Копирование файлов (только выбранных модулей)
    copy_files
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            КОПИРОВАНИЕ ЗАВЕРШЕНО!                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -d "$TARGET_DIR" ]; then
        local total_modules=$(find "$TARGET_DIR" -maxdepth 1 -type d -name '[A-Z]*' | wc -l)
        success "Всего скопировано модулей: $total_modules"
    fi
}

# Обработка прерывания
trap 'echo -e "\n${RED}Копирование прервано${NC}"; 
      [ -d "/tmp/medorg_mount_$$" ] && umount -f "/tmp/medorg_mount_$$" 2>/dev/null || true;
      [ -d "/tmp/medorg_mount_$$" ] && rmdir "/tmp/medorg_mount_$$" 2>/dev/null || true;
      exit 1' INT

# Запуск
main "$@" 