[file name]: 03-copy-files.sh
[file content begin]
#!/bin/bash
# Копирование программы с настройкой сетевой папки - БЕЗОПАСНАЯ версия

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

# Проверка окружения БЕЗ СОЗДАНИЯ ДИРЕКТОРИЙ
check_environment() {
    log "Проверка окружения для копирования..."
    
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
    WINE_PREFIX="$HOME_DIR/.wine_medorg"
    TARGET_DIR="$WINE_PREFIX/drive_c/MedCTech/MedOrg"
    
    log "Пользователь: $USER"
    log "Wine prefix: $WINE_PREFIX"
    log "Целевая директория: $TARGET_DIR"
    
    # ПРОВЕРЯЕМ, но НЕ СОЗДАЕМ директорию (она уже должна быть создана)
    if [ ! -d "$WINE_PREFIX" ]; then
        error "Wine prefix не найден: $WINE_PREFIX"
        echo "Сначала запустите модуль настройки Wine (02-wine-setup.sh)"
        exit 1
    fi
    
    success "Окружение проверено"
}

# Безопасный ввод пароля (с маскировкой)
read_password_silent() {
    local prompt="$1"
    unset PASSWORD
    local char
    
    echo -n "$prompt"
    stty -echo
    IFS= read -r -s char
    stty echo
    echo
    
    echo "$char"
}

# Получение учетных данных
get_network_credentials() {
    echo ""
    echo -e "${CYAN}ПАРАМЕТРЫ ПОДКЛЮЧЕНИЯ К СЕТЕВОЙ ПАПКЕ${NC}"
    echo -e "${BLUE}──────────────────────────────────────${NC}"
    echo ""
    
    # Чтение из файла конфигурации (если есть)
    local config_file="/etc/medorg/network.conf"
    local server=""
    local username=""
    
    if [ -f "$config_file" ] && [ -r "$config_file" ]; then
        log "Чтение конфигурации из $config_file"
        source "$config_file"
    fi
    
    # Запрашиваем параметры с подсказками по умолчанию
    read -p "Адрес сетевой папки [//10.0.1.11/auto]: " input_server
    SERVER="${input_server:-//10.0.1.11/auto}"
    
    read -p "Имя пользователя [Администратор]: " input_username
    USERNAME="${input_username:-Администратор}"
    
    # Пароль вводим безопасно
    PASSWORD=$(read_password_silent "Пароль: ")
    
    if [ -z "$PASSWORD" ]; then
        warning "Пароль не введен. Попробуйте подключиться без пароля."
    fi
    
    export NETWORK_SERVER="$SERVER"
    export NETWORK_USERNAME="$USERNAME"
    export NETWORK_PASSWORD="$PASSWORD"
    
    success "Учетные данные получены"
}

# Подключение к сетевой папке
mount_network_share() {
    local mount_point="$1"
    
    log "Подключение к сетевой папке: $NETWORK_SERVER"
    
    # Создаем точку монтирования
    mkdir -p "$mount_point"
    
    # Формируем опции монтирования
    local mount_options="username=$NETWORK_USERNAME,uid=$(id -u "$USER"),gid=$(id -g "$USER"),iocharset=utf8,file_mode=0750,dir_mode=0750"
    
    # Добавляем пароль, если он указан
    if [ -n "$NETWORK_PASSWORD" ]; then
        mount_options="$mount_options,password=$NETWORK_PASSWORD"
    fi
    
    log "Опции монтирования: $mount_options"
    
    # Пытаемся подключиться
    if mount -t cifs "$NETWORK_SERVER" "$mount_point" -o "$mount_options" 2>&1; then
        success "Сетевая папка успешно подключена"
        return 0
    else
        warning "Не удалось подключиться"
        
        # Пробуем альтернативные опции
        local alt_options="username=$NETWORK_USERNAME,uid=$(id -u "$USER")"
        if [ -n "$NETWORK_PASSWORD" ]; then
            alt_options="$alt_options,password=$NETWORK_PASSWORD"
        fi
        
        if mount -t cifs "$NETWORK_SERVER" "$mount_point" -o "$alt_options" 2>&1; then
            success "Сетевая папка подключена с альтернативными опциями"
            return 0
        else
            error "Не удалось подключиться к сетевой папке"
            echo "Проверьте:"
            echo "1. Доступность сервера: $NETWORK_SERVER"
            echo "2. Правильность учетных данных"
            echo "3. Наличие пакета cifs-utils"
            return 1
        fi
    fi
}

# Копирование файлов
copy_files() {
    local mount_point="/tmp/medorg_mount_$$"
    
    # Получаем учетные данные
    get_network_credentials
    
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
        
        # Копируем файлы с сохранением структуры
        log "Копирование из $mount_point в $TARGET_DIR..."
        
        # Используем rsync для лучшего контроля
        if command -v rsync >/dev/null 2>&1; then
            sudo -u "$USER" rsync -av --progress "$mount_point/" "$TARGET_DIR/"
        else
            # Fallback на cp
            cp -r "$mount_point"/* "$TARGET_DIR"/ 2>/dev/null || true
        fi
        
        # Устанавливаем права
        chown -R "$USER:$USER" "$TARGET_DIR"
        
        success "Файлы скопированы"
        
        # Показываем статистику
        log "Скопировано файлов: $(find "$TARGET_DIR" -type f | wc -l)"
        log "Объем данных: $(du -sh "$TARGET_DIR" | cut -f1)"
        
        # Отключаем сетевую папку
        umount "$mount_point" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
        
        # Очищаем переменные с паролем
        unset NETWORK_PASSWORD
        unset PASSWORD
        
        return 0
    else
        warning "Пропускаем копирование из сетевой папки"
        
        # Проверяем, есть ли уже файлы
        if [ -d "$TARGET_DIR/Lib" ] && [ -n "$(ls -A "$TARGET_DIR/Lib" 2>/dev/null)" ]; then
            success "Файлы уже существуют в целевой директории"
            return 0
        else
            error "Не удалось получить файлы программы"
            echo ""
            echo -e "${YELLOW}Рекомендации:${NC}"
            echo "1. Подключите сетевую папку вручную:"
            echo "   mkdir /mnt/medorg"
            echo "   mount -t cifs //server/share /mnt/medorg -o username=user"
            echo "2. Скопируйте файлы вручную:"
            echo "   cp -r /mnt/medorg/* $TARGET_DIR/"
            echo "   chown -R $USER:$USER $TARGET_DIR"
            return 1
        fi
    fi
}

# Основная функция
main() {
    echo ""
    echo -e "${CYAN}КОПИРОВАНИЕ МЕДИЦИНСКОГО ПО ИЗ СЕТЕВОЙ ПАПКИ${NC}"
    echo ""
    
    # Шаг 1: Проверка окружения (Wine prefix уже должен быть создан)
    check_environment
    
    # Шаг 2: Копирование файлов
    copy_files
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      КОПИРОВАНИЕ ЗАВЕРШЕНО!                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -d "$TARGET_DIR/Lib" ]; then
        echo -e "${CYAN}Установленные модули:${NC}"
        echo -e "${BLUE}──────────────────────${NC}"
        ls "$TARGET_DIR" | grep -E "^[A-Z]" | sort | column -c 80
    fi
    
    echo ""
    echo -e "${CYAN}Следующий шаг:${NC} Исправление библиотек и создание ярлыков"
    echo ""
}

# Обработка прерывания
trap 'echo -e "\n${RED}Копирование прервано${NC}"; 
      [ -d "/tmp/medorg_mount_$$" ] && umount -f "/tmp/medorg_mount_$$" 2>/dev/null || true;
      [ -d "/tmp/medorg_mount_$$" ] && rmdir "/tmp/medorg_mount_$$" 2>/dev/null || true;
      unset NETWORK_PASSWORD PASSWORD;
      exit 1' INT

# Запуск
main "$@"
[file content end]