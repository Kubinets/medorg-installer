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