#!/bin/bash
# Копирование программы с настройкой сетевой папки

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Функция печатающей машинки
typewriter() {
    local text="$1"
    local delay="${2:-0.03}"
    
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo ""
}

# Красивая рамка
print_section() {
    local title="$1"
    local width=60
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

# Получение данных сетевой папки
get_network_share() {
    print_section "НАСТРОЙКА СЕТЕВОЙ ПАПКИ"
    
    typewriter "Для работы медицинских программ требуется доступ к сетевой папке." 0.03
    typewriter "Папка будет подключена для копирования файлов и работы автообновления." 0.03
    echo ""
    
    echo -e "${YELLOW}Параметры по умолчанию:${NC}"
    echo "  Адрес:   //10.0.1.11/auto"
    echo "  Логин:   Администратор"
    echo "  Пароль:  ********"
    echo ""
    
    # Проверяем, интерактивный ли режим
    if [[ "$INPUT_METHOD" == "args" ]]; then
        exec < /dev/tty
    fi
    
    typewriter "Использовать значения по умолчанию?" 0.03
    echo -ne "${GREEN} (Y/n): ${NC}"
    read -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        # Ввод пользовательских данных
        echo ""
        echo -e "${CYAN}Введите данные сетевой папки:${NC}"
        echo ""
        
        # Адрес сервера
        typewriter "Введите адрес сетевой папки" 0.03
        while true; do
            echo -ne "${BLUE}Адрес сервера${NC} ${YELLOW}[//10.0.1.11/auto]:${NC} "
            read server_addr
            server_addr="${server_addr:-//10.0.1.11/auto}"
            
            if [[ "$server_addr" =~ ^// ]]; then
                break
            else
                warning "Адрес должен начинаться с // (например: //сервер/папка)"
            fi
        done
        
        # Логин
        typewriter "Введите имя пользователя" 0.03
        echo -ne "${BLUE}Имя пользователя${NC} ${YELLOW}[Администратор]:${NC} "
        read username
        username="${username:-Администратор}"
        
        # Пароль
        typewriter "Введите пароль" 0.03
        echo -ne "${BLUE}Пароль${NC} ${YELLOW}[оставьте пустым для пароля по умолчанию]:${NC} "
        read -sp "" password
        echo ""
        
        if [ -z "$password" ]; then
            password="Ybyjxrf30lh*"
            echo -e "${YELLOW}Используется пароль по умолчанию${NC}"
        fi
    else
        # Используем значения по умолчанию
        typewriter "Используются значения по умолчанию..." 0.03
        server_addr="//10.0.1.11/auto"
        username="Администратор"
        password="Ybyjxrf30lh*"
    fi
    
    # Сохраняем в переменные
    NETWORK_SHARE="$server_addr"
    SHARE_USERNAME="$username"
    SHARE_PASSWORD="$password"
    
    echo ""
    success "Настройки сетевой папки сохранены"
    echo -e "  ${GREEN}Адрес:${NC} $NETWORK_SHARE"
    echo -e "  ${GREEN}Логин:${NC} $SHARE_USERNAME"
    echo -e "  ${GREEN}Назначение:${NC} Копирование файлов и работа автообновления"
}

# Проверка доступности сервера
check_server_access() {
    local server="$1"
    local user="$2"
    local pass="$3"
    
    print_section "ПРОВЕРКА ДОСТУПНОСТИ СЕРВЕРА"
    
    typewriter "Проверяем доступность сетевой папки..." 0.03
    echo ""
    
    # Проверяем ping сервера (если это IP)
    if [[ "$server" =~ //([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/ ]]; then
        local server_ip="${BASH_REMATCH[1]}"
        echo -ne "  ${BLUE}Ping сервера $server_ip...${NC} "
        if ping -c 2 -W 1 "$server_ip" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC} (не отвечает)"
        fi
    fi
    
    # Проверяем доступность через smbclient
    echo -ne "  ${BLUE}Проверка SMB подключения...${NC} "
    if command -v smbclient >/dev/null 2>&1; then
        if timeout 5 smbclient "$server" -U "$user%$pass" -c "exit" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${YELLOW}!${NC}"
            warning "Не удалось подключиться через SMB"
            return 1
        fi
    else
        echo -e "${YELLOW}!${NC} (smbclient не установлен)"
        return 2
    fi
}

# Подключение к сетевой папке для копирования
mount_for_copy() {
    local mount_point="$1"
    
    print_section "ПОДКЛЮЧЕНИЕ ДЛЯ КОПИРОВАНИЯ"
    
    typewriter "Подключаем сетевую папку для копирования файлов..." 0.03
    echo ""
    echo -e "${CYAN}Параметры подключения:${NC}"
    echo -e "  ${BLUE}Адрес:${NC} $NETWORK_SHARE"
    echo -e "  ${BLUE}Логин:${NC} $SHARE_USERNAME"
    echo -e "  ${BLUE}Точка монтирования:${NC} $mount_point"
    echo ""
    
    # Создаем точку монтирования
    mkdir -p "$mount_point"
    
    typewriter "Пытаемся подключиться..." 0.03
    
    # Опции монтирования
    local mount_options="username=$SHARE_USERNAME,password=$SHARE_PASSWORD,uid=$(id -u "$TARGET_USER"),gid=$(id -g "$TARGET_USER"),iocharset=utf8,file_mode=0777,dir_mode=0777,noperm"
    
    # Пробуем разные версии SMB
    local smb_versions=("3.0" "2.1" "2.0" "1.0")
    
    for version in "${smb_versions[@]}"; do
        echo -ne "  ${BLUE}Пробуем SMB $version...${NC} "
        if mount -t cifs "$NETWORK_SHARE" "$mount_point" -o "${mount_options},vers=$version" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            success "Сетевая папка подключена (SMB $version)"
            
            # Проверяем доступность файлов
            if [ -d "$mount_point" ] && ls "$mount_point/" 1>/dev/null 2>&1; then
                echo -e "  ${GREEN}Доступ к файлам:${NC} ✓"
                return 0
            else
                warning "Папка подключена, но файлы недоступны"
                return 1
            fi
        else
            echo -e "${YELLOW}!${NC}"
        fi
    done
    
    error "Не удалось подключиться ни с одной версией SMB"
    return 1
}

# Настройка постоянного подключения для автообновления
setup_persistent_mount() {
    print_section "НАСТРОЙКА ПОДКЛЮЧЕНИЯ ДЛЯ АВТООБНОВЛЕНИЯ"
    
    typewriter "Настраиваем постоянное подключение сетевой папки..." 0.03
    echo ""
    
    # Создаем точку монтирования для постоянного подключения
    local persistent_mount="/mnt/medorg_network"
    local fstab_entry="$NETWORK_SHARE  $persistent_mount  cifs  username=$SHARE_USERNAME,password=$SHARE_PASSWORD,uid=$(id -u "$TARGET_USER"),gid=$(id -g "$TARGET_USER"),iocharset=utf8,file_mode=0777,dir_mode=0777,noperm,_netdev  0  0"
    
    echo -e "${CYAN}Создаем точку монтирования:${NC}"
    echo -e "  ${BLUE}Путь:${NC} $persistent_mount"
    echo -e "  ${BLUE}Назначение:${NC} Автообновление медицинских программ"
    
    mkdir -p "$persistent_mount"
    chown "$TARGET_USER:$TARGET_USER" "$persistent_mount"
    
    # Тестируем подключение
    typewriter "Тестируем подключение..." 0.03
    if mount -t cifs "$NETWORK_SHARE" "$persistent_mount" -o "username=$SHARE_USERNAME,password=$SHARE_PASSWORD,uid=$(id -u "$TARGET_USER")" 2>/dev/null; then
        success "Подключение работает"
        
        # Добавляем в fstab для автоматического монтирования при загрузке
        echo ""
        typewriter "Добавляем в автозагрузку..." 0.03
        if ! grep -q "$persistent_mount" /etc/fstab 2>/dev/null; then
            echo "$fstab_entry" | tee -a /etc/fstab >/dev/null
            success "Добавлено в /etc/fstab"
            echo -e "  ${GREEN}→${NC} Сетевая папка будет автоматически подключаться при загрузке системы"
        else
            warning "Запись уже существует в /etc/fstab"
        fi
        
        # Создаем символическую ссылку для удобства
        echo ""
        typewriter "Создаем ссылку для удобного доступа..." 0.03
        local user_link="$TARGET_HOME/Сетевая_папка_MedOrg"
        ln -sf "$persistent_mount" "$user_link" 2>/dev/null
        chown "$TARGET_USER:$TARGET_USER" "$user_link" 2>/dev/null
        
        success "Создана ссылка: $user_link → $persistent_mount"
        
        # Отключаем тестовое монтирование
        umount "$persistent_mount" 2>/dev/null || true
        
        # Монтируем через fstab
        mount "$persistent_mount" 2>/dev/null || true
        
    else
        warning "Не удалось настроить автоматическое подключение"
        echo -e "  ${YELLOW}Автообновление будет работать только при ручном подключении${NC}"
        
        # Создаем скрипт для ручного подключения
        create_mount_script "$persistent_mount"
    fi
    
    # Создаем инструкцию
    create_instructions "$persistent_mount"
}

# Создание скрипта для ручного подключения
create_mount_script() {
    local mount_point="$1"
    local script_path="$TARGET_HOME/mount_network_folder.sh"
    
    typewriter "Создаем скрипт для ручного подключения..." 0.03
    
    cat > "$script_path" << EOF
#!/bin/bash
# Скрипт для подключения сетевой папки MedOrg

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║      ПОДКЛЮЧЕНИЕ СЕТЕВОЙ ПАПКИ MEDORG          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

MOUNT_POINT="$mount_point"
NETWORK_SHARE="$NETWORK_SHARE"
USERNAME="$SHARE_USERNAME"

echo "Сетевая папка: \$NETWORK_SHARE"
echo "Точка монтирования: \$MOUNT_POINT"
echo ""

# Проверяем, подключена ли уже папка
if mount | grep -q "\$MOUNT_POINT"; then
    echo "✓ Сетевая папка уже подключена"
    echo ""
    echo "Содержимое папки:"
    echo "────────────────"
    ls -la "\$MOUNT_POINT/" | head -20
else
    echo "▌ Подключаем сетевую папку..."
    
    # Создаем директорию если не существует
    mkdir -p "\$MOUNT_POINT"
    
    # Пробуем подключить
    if mount -t cifs "\$NETWORK_SHARE" "\$MOUNT_POINT" -o "username=\$USERNAME,password=$SHARE_PASSWORD,uid=$(id -u "$TARGET_USER")" 2>/dev/null; then
        echo "✓ Сетевая папка успешно подключена"
        
        echo ""
        echo "Содержимое папки:"
        echo "────────────────"
        ls -la "\$MOUNT_POINT/" | head -20
    else
        echo "❌ Не удалось подключить сетевую папку"
        echo ""
        echo "Возможные причины:"
        echo "• Сервер недоступен"
        echo "• Неверный логин/пароль"
        echo "• Проблемы с сетью"
    fi
fi

echo ""
echo "Для автообновления программ папка должна быть подключена."
echo ""
EOF
    
    chmod +x "$script_path"
    chown "$TARGET_USER:$TARGET_USER" "$script_path"
    
    success "Скрипт для ручного подключения создан"
    echo -e "  ${GREEN}→${NC} $script_path"
}

# Создание инструкции
create_instructions() {
    local mount_point="$1"
    
    print_section "ИНФОРМАЦИЯ ДЛЯ ПОЛЬЗОВАТЕЛЯ"
    
    typewriter "Важная информация о подключении сетевой папки:" 0.03
    echo ""
    
    echo -e "${CYAN}Для работы автообновления:${NC}"
    echo -e "${BLUE}────────────────────────${NC}"
    echo -e "  ${GREEN}•${NC} Сетевая папка должна быть постоянно подключена"
    echo -e "  ${GREEN}•${NC} Путь: ${YELLOW}$mount_point${NC}"
    echo -e "  ${GREEN}•${NC} Адрес: ${YELLOW}$NETWORK_SHARE${NC}"
    echo ""
    
    echo -e "${CYAN}Автоматическое подключение:${NC}"
    echo -e "${BLUE}──────────────────────────${NC}"
    if grep -q "$mount_point" /etc/fstab 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Настроено (подключается при загрузке системы)"
    else
        echo -e "  ${YELLOW}!${NC} Не настроено"
        echo -e "  ${BLUE}→${NC} Запускайте скрипт: ${YELLOW}$TARGET_HOME/mount_network_folder.sh${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}Проверка подключения:${NC}"
    echo -e "${BLUE}────────────────────${NC}"
    echo "  Для проверки выполните:"
    echo "    ls $mount_point"
    echo "  или"
    echo "    mount | grep medorg"
    echo ""
}

# Копирование файлов
copy_files() {
    print_section "КОПИРОВАНИЕ ФАЙЛОВ ПРОГРАММЫ"
    
    local mount_point="/mnt/medorg_temp_$$"
    
    # Получаем данные сетевой папки
    get_network_share
    
    # Проверяем доступность сервера
    if ! check_server_access "$NETWORK_SHARE" "$SHARE_USERNAME" "$SHARE_PASSWORD"; then
        warning "Возможны проблемы с подключением к серверу"
        echo -e "  ${YELLOW}Продолжаем попытку подключения...${NC}"
    fi
    
    # Пытаемся подключиться для копирования
    if mount_for_copy "$mount_point"; then
        echo ""
        typewriter "Начинаем копирование медицинских программ..." 0.03
        
        # Обязательные модули
        echo ""
        echo -e "${CYAN}Копируем обязательные модули:${NC}"
        echo "─────────────────────────────"
        
        local required_copied=0
        for folder in "${REQUIRED[@]}"; do
            echo -ne "  ${BLUE}$folder${NC}... "
            if [ -d "$mount_point/$folder" ]; then
                if cp -r "$mount_point/$folder" "$TARGET_DIR/" 2>/dev/null; then
                    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/$folder"
                    echo -e "${GREEN}✓${NC}"
                    required_copied=$((required_copied + 1))
                    
                    # Показываем количество файлов
                    file_count=$(find "$TARGET_DIR/$folder" -type f 2>/dev/null | wc -l)
                    echo -e "    ${YELLOW}→${NC} Файлов: $file_count"
                else
                    echo -e "${RED}✗${NC}"
                fi
            else
                echo -e "${YELLOW}!${NC}"
            fi
        done
        
        if [ $required_copied -eq ${#REQUIRED[@]} ]; then
            success "Все обязательные модули скопированы"
        else
            warning "Скопировано $required_copied из ${#REQUIRED[@]} обязательных модулей"
        fi
        
        # Дополнительные модули
        if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            echo ""
            echo -e "${CYAN}Копируем дополнительные модули:${NC}"
            echo "────────────────────────────────"
            
            local selected_copied=0
            for folder in "${SELECTED_MODULES[@]}"; do
                echo -ne "  ${BLUE}$folder${NC}... "
                if [ -d "$mount_point/$folder" ]; then
                    if cp -r "$mount_point/$folder" "$TARGET_DIR/" 2>/dev/null; then
                        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/$folder"
                        echo -e "${GREEN}✓${NC}"
                        selected_copied=$((selected_copied + 1))
                    else
                        echo -e "${RED}✗${NC}"
                    fi
                else
                    echo -e "${YELLOW}!${NC}"
                fi
            done
            
            if [ $selected_copied -gt 0 ]; then
                success "Скопировано дополнительных модулей: $selected_copied"
            else
                warning "Не удалось скопировать дополнительные модули"
            fi
        fi
        
        # Общие файлы
        echo ""
        echo -e "${CYAN}Копируем общие файлы:${NC}"
        echo "───────────────────────"
        
        local files_copied=0
        local common_patterns=("*.exe" "*.dll" "*.bat" "*.cmd" "*.txt" "*.ini" "*.reg")
        
        for pattern in "${common_patterns[@]}"; do
            for file in "$mount_point"/$pattern; do
                if [ -f "$file" ] && [ ! -e "$TARGET_DIR/$(basename "$file")" ]; then
                    echo -ne "  ${BLUE}$(basename "$file")${NC}... "
                    if cp "$file" "$TARGET_DIR/" 2>/dev/null; then
                        chown "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/$(basename "$file")"
                        echo -e "${GREEN}✓${NC}"
                        files_copied=$((files_copied + 1))
                    fi
                fi
            done
        done
        
        if [ $files_copied -gt 0 ]; then
            success "Скопировано общих файлов: $files_copied"
        fi
        
        # Отключаем временную точку монтирования
        umount "$mount_point" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
        
        # Проверяем результат
        echo ""
        if [ $required_copied -eq 0 ]; then
            error "Не удалось скопировать ни одного модуля!"
            return 1
        else
            # Подсчитываем итоги
            total_files=$(find "$TARGET_DIR" -type f 2>/dev/null | wc -l)
            
            echo ""
            success "Копирование завершено успешно!"
            echo -e "${CYAN}Итоги копирования:${NC}"
            echo -e "${BLUE}──────────────────${NC}"
            echo -e "  ${GREEN}•${NC} Обязательные модули: $required_copied/${#REQUIRED[@]}"
            if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
                echo -e "  ${GREEN}•${NC} Дополнительные модули: $selected_copied/${#SELECTED_MODULES[@]}"
            fi
            echo -e "  ${GREEN}•${NC} Общие файлы: $files_copied"
            echo -e "  ${GREEN}•${NC} Всего файлов: $total_files"
            echo -e "  ${GREEN}•${NC} Расположение: $TARGET_DIR"
            
            return 0
        fi
    else
        error "Не удалось подключиться к сетевой папке для копирования"
        return 1
    fi
}

# Основная функция
main() {
    print_section "КОПИРОВАНИЕ MEDORG И НАСТРОЙКА ПОДКЛЮЧЕНИЯ"
    
    # Проверяем необходимые переменные
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        error "Переменные TARGET_USER и TARGET_HOME не установлены"
        exit 1
    fi
    
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
    
    echo -e "${CYAN}Параметры установки:${NC}"
    echo -e "${BLUE}───────────────────${NC}"
    echo -e "  ${GREEN}Пользователь:${NC} $TARGET_USER"
    echo -e "  ${GREEN}Директория программ:${NC} $TARGET_DIR"
    echo ""
    
    # Проверяем cifs-utils
    if ! command -v mount.cifs >/dev/null 2>&1; then
        typewriter "Устанавливаем cifs-utils для работы с сетевыми папками..." 0.03
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y cifs-utils 2>/dev/null || {
                error "Не удалось установить cifs-utils"
                exit 1
            }
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get install -y cifs-utils 2>/dev/null || {
                error "Не удалось установить cifs-utils"
                exit 1
            }
        fi
        success "cifs-utils установлен"
    fi
    
    # Копируем файлы
    if copy_files; then
        # Настраиваем постоянное подключение для автообновления
        setup_persistent_mount
        
        # Итог
        echo ""
        print_section "УСТАНОВКА ЗАВЕРШЕНА"
        
        typewriter "Медицинские программы успешно установлены!" 0.03
        echo ""
        
        echo -e "${CYAN}Для автообновления убедитесь, что:${NC}"
        echo -e "${BLUE}─────────────────────────────────${NC}"
        echo -e "  1. Сетевая папка подключена"
        echo -e "  2. Сеть работает стабильно"
        echo -e "  3. Есть доступ к серверу $NETWORK_SHARE"
        echo ""
        
        echo -e "${YELLOW}Для запуска программ войдите под пользователем $TARGET_USER${NC}"
        echo -e "${YELLOW}и откройте ярлыки на рабочем столе.${NC}"
        
    else
        error "Копирование не удалось"
        exit 1
    fi
}

# Запуск
main "$@"