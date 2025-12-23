#!/bin/bash
# Копирование программы с настройкой сетевой папки - FIXED

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

# Определяем массивы модулей из экспортированных переменных
REQUIRED=(${REQUIRED[@]})
if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
    SELECTED_MODULES=()
else
    SELECTED_MODULES=(${SELECTED_MODULES[@]})
fi

# Красивая рамка
print_section() {
    local title="$1"
    local width=50
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo ""
    echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $width))╗${NC}"
    echo -e "${CYAN}║$(printf ' %.0s' $(seq 1 $padding))${GREEN}$title${CYAN}$(printf ' %.0s' $(seq 1 $((width - padding - ${#title}))))║${NC}"
    echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $width))╝${NC}"
    echo ""
}

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

# Получение данных сетевой папки
get_network_share() {
    print_section "НАСТРОЙКА СЕТЕВОЙ ПАПКИ"
    
    echo "По умолчанию используется:"
    echo "  Адрес:   //10.0.1.11/auto"
    echo "  Логин:   Администратор"
    echo "  Пароль:  ********"
    echo ""
    
    # Проверяем, интерактивный ли режим
    if [[ "$INPUT_METHOD" == "args" ]]; then
        exec < /dev/tty
    fi
    
    read -p "Использовать значения по умолчанию? (Y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        # Ввод пользовательских данных
        echo ""
        echo -e "${YELLOW}Введите данные сетевой папки:${NC}"
        echo ""
        
        # Адрес сервера
        while true; do
            read -p "Адрес сервера [//10.0.1.11/auto]: " server_addr
            server_addr="${server_addr:-//10.0.1.11/auto}"
            
            if [[ "$server_addr" =~ ^// ]]; then
                break
            else
                warning "Адрес должен начинаться с //"
            fi
        done
        
        # Логин
        read -p "Имя пользователя [Администратор]: " username
        username="${username:-Администратор}"
        
        # Пароль
        read -sp "Пароль: " password
        echo ""
        
        if [ -z "$password" ]; then
            password="Ybyjxrf30lh*"
            echo "Используется пароль по умолчанию"
        fi
    else
        # Используем значения по умолчанию
        server_addr="//10.0.1.11/auto"
        username="Администратор"
        password="Ybyjxrf30lh*"
        echo "Используются значения по умолчанию"
    fi
    
    # Сохраняем в переменные
    NETWORK_SHARE="$server_addr"
    SHARE_USERNAME="$username"
    SHARE_PASSWORD="$password"
    
    echo ""
    success "Настройки сетевой папки сохранены"
    echo "  Адрес: $NETWORK_SHARE"
    echo "  Логин: $SHARE_USERNAME"
}

# Подключение к сетевой папке
mount_network_share() {
    local mount_point="$1"
    
    log "Попытка подключения к сетевой папке..."
    echo "  Адрес: $NETWORK_SHARE"
    echo "  Логин: $SHARE_USERNAME"
    
    # Создаем точку монтирования
    mkdir -p "$mount_point"
    
    # Пробуем разные опции монтирования
    local mount_options="username=$SHARE_USERNAME,password=$SHARE_PASSWORD,uid=$(id -u "$TARGET_USER"),gid=$(id -g "$TARGET_USER"),iocharset=utf8,file_mode=0777,dir_mode=0777"
    
    if mount -t cifs "$NETWORK_SHARE" "$mount_point" -o "$mount_options" 2>&1; then
        success "Сетевая папка успешно подключена"
        return 0
    else
        warning "Не удалось подключиться с основными опциями, пробуем альтернативные..."
        
        # Альтернативные опции
        local alt_options="username=$SHARE_USERNAME,password=$SHARE_PASSWORD,uid=$(id -u "$TARGET_USER")"
        
        if mount -t cifs "$NETWORK_SHARE" "$mount_point" -o "$alt_options" 2>&1; then
            success "Сетевая папка подключена с альтернативными опциями"
            return 0
        else
            error "Не удалось подключиться к сетевой папке"
            
            # Пробуем ручное подключение через smbclient
            log "Проверка доступности через smbclient..."
            if command -v smbclient >/dev/null 2>&1; then
                if echo "exit" | smbclient "$NETWORK_SHARE" -U "$SHARE_USERNAME"%"$SHARE_PASSWORD" 2>/dev/null; then
                    log "Сервер доступен, возможно проблема с правами монтирования"
                else
                    log "Сервер недоступен или неверные учетные данные"
                fi
            fi
            
            return 1
        fi
    fi
}

# Копирование файлов
copy_files() {
    print_section "КОПИРОВАНИЕ ФАЙЛОВ"
    
    local mount_point="/tmp/medorg_mount_$$"
    
    # Получаем данные сетевой папки
    get_network_share
    
    # Пытаемся подключиться
    if mount_network_share "$mount_point"; then
        log "Начинаем копирование файлов..."
        
        # Копируем обязательные папки
        log "Обязательные модули:"
        local required_copied=0
        for folder in "${REQUIRED[@]}"; do
            if [ -d "$mount_point/$folder" ]; then
                cp -r "$mount_point/$folder" "$TARGET_DIR/"
                chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/$folder"
                echo -e "  ${GREEN}✓${NC} $folder"
                required_copied=$((required_copied + 1))
            else
                echo -e "  ${YELLOW}!${NC} $folder не найдена на сервере"
            fi
        done
        
        if [ $required_copied -eq ${#REQUIRED[@]} ]; then
            success "Все обязательные модули скопированы"
        else
            warning "Скопировано $required_copied из ${#REQUIRED[@]} обязательных модулей"
        fi
        
        # Копируем выбранные модули
        if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            echo ""
            log "Дополнительные модули:"
            local selected_copied=0
            for folder in "${SELECTED_MODULES[@]}"; do
                if [ -d "$mount_point/$folder" ]; then
                    cp -r "$mount_point/$folder" "$TARGET_DIR/"
                    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/$folder"
                    echo -e "  ${GREEN}✓${NC} $folder"
                    selected_copied=$((selected_copied + 1))
                else
                    echo -e "  ${YELLOW}!${NC} $folder не найдена на сервере"
                fi
            done
            
            if [ $selected_copied -gt 0 ]; then
                success "Скопировано $selected_copied дополнительных модулей"
            else
                warning "Не удалось скопировать дополнительные модули"
            fi
        fi
        
        # Копируем общие файлы
        echo ""
        log "Общие файлы:"
        local common_files=("midasregMedOrg.cmd" "readme.txt")
        local files_copied=0
        
        for pattern in "${common_files[@]}"; do
            for file in "$mount_point"/$pattern; do
                if [ -f "$file" ]; then
                    cp "$file" "$TARGET_DIR/" 2>/dev/null && {
                        chown "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/$(basename "$file")"
                        echo -e "  ${GREEN}✓${NC} $(basename "$file")"
                        files_copied=$((files_copied + 1))
                    }
                fi
            done
        done
        
        # Отключаем сетевую папку
        umount "$mount_point" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
        
        # Проверяем результат копирования
        echo ""
        if [ $required_copied -eq 0 ]; then
            error "Не удалось скопировать ни одного модуля!"
            echo "Возможные причины:"
            echo "  1. Неверный путь к сетевой папке"
            echo "  2. Неверный логин/пароль"
            echo "  3. Нет доступа к серверу"
            echo "  4. Папки с программами не найдены на сервере"
            return 1
        else
            success "Копирование завершено"
            echo "Скопировано:"
            echo "  • Обязательные модули: $required_copied"
            if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
                echo "  • Дополнительные модули: $selected_copied"
            fi
            echo "  • Файлы: $files_copied"
            return 0
        fi
    else
        error "Не удалось подключиться к сетевой папке"
        
        # Предлагаем альтернативу - ручное копирование
        echo ""
        echo -e "${YELLOW}Альтернативный вариант:${NC}"
        echo "1. Подключите сетевую папку вручную:"
        echo "   sudo mount -t cifs $NETWORK_SHARE /mnt -o username=$SHARE_USERNAME,password=$SHARE_PASSWORD"
        echo ""
        echo "2. Скопируйте файлы вручную:"
        echo "   cp -r /mnt/* $TARGET_DIR/"
        echo "   chown -R $TARGET_USER:$TARGET_USER $TARGET_DIR"
        echo ""
        echo "3. Затем продолжите установку"
        
        return 1
    fi
}

# Проверка и подготовка
main() {
    # Проверяем необходимые переменные
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        error "Переменные TARGET_USER и TARGET_HOME не установлены"
        exit 1
    fi
    
    # Проверяем существование пользователя
    if ! id "$TARGET_USER" &>/dev/null; then
        error "Пользователь $TARGET_USER не существует"
        exit 1
    fi
    
    # Определяем INPUT_METHOD если не установлен
    if [ -z "${INPUT_METHOD+x}" ]; then
        if [[ -t 0 ]]; then
            INPUT_METHOD="tty"
        else
            INPUT_METHOD="args"
        fi
    fi
    
    # Подготавливаем целевую директорию
    TARGET_DIR="$TARGET_HOME/.wine_medorg/drive_c/MedCTech/MedOrg"
    mkdir -p "$TARGET_DIR"
    chown -R "$TARGET_USER:$TARGET_USER" "$(dirname "$TARGET_DIR")"
    
    log "Целевая директория: $TARGET_DIR"
    log "Пользователь: $TARGET_USER"
    
    # Проверяем, установлен ли cifs-utils
    if ! command -v mount.cifs >/dev/null 2>&1; then
        warning "cifs-utils не установлен, пытаемся установить..."
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y cifs-utils 2>/dev/null || {
                error "Не удалось установить cifs-utils"
                echo "Установите вручную: sudo dnf install cifs-utils"
                exit 1
            }
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y cifs-utils 2>/dev/null || {
                error "Не удалось установить cifs-utils"
                echo "Установите вручную: sudo apt-get install cifs-utils"
                exit 1
            }
        else
            error "Не найден менеджер пакетов для установки cifs-utils"
            exit 1
        fi
    fi
    
    # Запускаем копирование
    copy_files
}

# Запуск
main "$@"