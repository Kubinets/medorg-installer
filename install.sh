#!/bin/bash
# MedOrg Installer - исправленная версия для ветки test
# Использование: curl -sSL "https://raw.githubusercontent.com/Kubinets/medorg-installer/test/install.sh?cache=$(date +%s)" | sudo bash

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Функции вывода
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}!${NC} $1"; }

# Проверка root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "Запустите с правами root: sudo bash $0"
    fi
}

# Получение текущего пользователя
get_current_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        getent passwd | grep -E ':/home/' | grep -v 'nologin\|false' | cut -d: -f1 | head -1
    fi
}

# Установка зависимостей Fedora
install_dependencies() {
    log "Обновляем систему..."
    dnf update -y --quiet
    
    success "Обновление завершено"
    
    log "Устанавливаем основные зависимости..."
    dnf install -y --quiet wget cabextract p7zip p7zip-plugins unzip
    dnf install -y --quiet freetype fontconfig libX11 libXext libXcursor libXi libXrandr libXinerama libXcomposite mesa-libGLU
    dnf install -y --quiet cifs-utils nfs-utils
    
    success "Основные зависимости установлены"
    
    log "Устанавливаем Wine..."
    dnf install -y --quiet wine wine.i686
    
    success "Wine установлен"
    
    # Проверяем Wine
    log "Версия Wine: $(wine --version 2>/dev/null || echo 'не установлен')"
}

# Установка winetricks (ИСПРАВЛЕННАЯ ВЕРСИЯ)
install_winetricks() {
    log "Скачиваем winetricks..."
    
    if ! command -v winetricks >/dev/null 2>&1; then
        # Скачиваем
        wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /tmp/winetricks
        
        if [ -f /tmp/winetricks ]; then
            chmod +x /tmp/winetricks
            mv /tmp/winetricks /usr/local/bin/
            
            # Проверяем установку
            if command -v winetricks >/dev/null 2>&1; then
                success "Winetricks установлен"
                log "Версия: $(winetricks --version 2>/dev/null | head -1 || echo 'неизвестно')"
            else
                warning "Winetricks не установился правильно"
                return 1
            fi
        else
            error "Не удалось скачать winetricks"
        fi
    else
        success "Winetricks уже установлен"
        log "Версия: $(winetricks --version 2>/dev/null | head -1 || echo 'неизвестно')"
    fi
}

# Настройка Wine для пользователя
setup_wine_for_user() {
    local user="$1"
    local home_dir="$2"
    
    log "Настраиваем Wine для пользователя $user..."
    
    # Создаем директорию если нет
    mkdir -p "$home_dir/.wine_medorg"
    chown -R "$user:$user" "$home_dir/.wine_medorg"
    
    # Экспортируем переменные
    export WINEPREFIX="$home_dir/.wine_medorg"
    export WINEARCH=win32
    
    log "Создаем Wine prefix..."
    
    # Запускаем winecfg в фоне
    sudo -u "$user" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 wineboot --init 2>&1 | grep -v "fixme\|warn\|err" || true
    sleep 3
    
    success "Wine prefix создан"
    
    # Устанавливаем компоненты через winetricks
    log "Устанавливаем компоненты Wine..."
    
    # Проверяем наличие winetricks
    if ! command -v winetricks >/dev/null 2>&1; then
        warning "Winetricks не найден, пропускаем установку компонентов"
        return
    fi
    
    # Компоненты для установки
    local components=("corefonts" "tahoma" "vcrun6" "vcrun2008" "mdac28" "jet40")
    
    for component in "${components[@]}"; do
        log "  Установка $component..."
        # Используем timeout и игнорируем ошибки
        timeout 60 sudo -u "$user" env WINEPREFIX="$WINEPREFIX" WINEARCH=win32 winetricks -q "$component" 2>&1 | grep -v "fixme\|warn\|err" || true
        sleep 2
    done
    
    success "Компоненты Wine установлены"
}

# Копирование программ
copy_programs() {
    local user="$1"
    local home_dir="$2"
    
    log "Подключаемся к сетевой папке..."
    
    # Создаем точку монтирования
    local mount_point="/mnt/medorg_share_$$"
    mkdir -p "$mount_point"
    
    # Параметры подключения (как в ручной установке)
    local server="//10.0.1.11/auto"
    local username="Администратор"
    local password="Ybyjxrf30lh*"
    
    log "Монтируем: $server"
    
    # Монтируем с правильными параметрами
    if mount -t cifs "$server" "$mount_point" -o "username=$username,password=$password,uid=$(id -u "$user"),gid=$(id -g "$user"),iocharset=utf8"; then
        success "Сетевая папка подключена"
        
        # Создаем целевую директорию
        local target_dir="$home_dir/.wine_medorg/drive_c/MedCTech/MedOrg"
        mkdir -p "$target_dir"
        chown -R "$user:$user" "$(dirname "$target_dir")"
        
        # Копируем ВСЕ содержимое
        log "Копируем программы..."
        cp -r "$mount_point"/* "$target_dir"/ 2>/dev/null || true
        chown -R "$user:$user" "$target_dir"/*
        
        success "Программы скопированы"
        
        # Показываем что скопировалось
        log "Скопированные модули:"
        ls -la "$target_dir" | head -10
        
        # Отключаем
        umount "$mount_point" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
    else
        warning "Не удалось подключиться к сетевой папке"
        log "Возможно, файлы уже скопированы ранее"
    fi
}

# Финальный фикс
create_final_fix() {
    local user="$1"
    local home_dir="$2"
    
    log "Создаем финальный фикс-скрипт..."
    
    cat > "$home_dir/final_fix_all.sh" << 'EOF'
#!/bin/bash
export WINEPREFIX="$HOME/.wine_medorg"

echo "=== ФИНАЛЬНЫЙ ФИКС ДЛЯ ВСЕХ МОДУЛЕЙ ==="

# 1. Создаем ссылки для регистра
echo "1. Создание ссылок для разных регистров..."
cd "$WINEPREFIX/drive_c/MedCTech/MedOrg/Lib"
ln -sf midas.dll MIDAS.DLL 2>/dev/null
ln -sf midas.dll Midas.dll 2>/dev/null
ln -sf midas.dll midas.DLL 2>/dev/null

# 2. Копируем в system32
echo "2. Копирование в system32..."
cp -f midas.dll "$WINEPREFIX/drive_c/windows/system32/" 2>/dev/null
cd "$WINEPREFIX/drive_c/windows/system32"
ln -sf midas.dll MIDAS.DLL 2>/dev/null
ln -sf midas.dll Midas.dll 2>/dev/null

# 3. Исправляем реестр
echo "3. Исправление реестра..."
cat > /tmp/final_fix.reg << 'REGEOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"
REGEOF

wine regedit /tmp/final_fix.reg 2>/dev/null
rm -f /tmp/final_fix.reg

echo ""
echo "=== Готово! ==="
echo "Запускайте программы через ярлыки на рабочем столе"
EOF
    
    chmod +x "$home_dir/final_fix_all.sh"
    chown "$user:$user" "$home_dir/final_fix_all.sh"
    
    success "Финальный фикс-скрипт создан: ~/final_fix_all.sh"
}

# Основная функция
main() {
    clear
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           УСТАНОВКА MEDORG (ТЕСТОВАЯ ВЕТКА)                ║"
    echo "║         Исправленная версия - без winetricks               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Проверка прав
    check_root
    
    # Определяем пользователя
    local target_user=$(get_current_user)
    if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
        error "Не удалось определить пользователя для установки"
    fi
    
    local home_dir=$(getent passwd "$target_user" | cut -d: -f6)
    
    echo ""
    echo -e "${CYAN}Целевой пользователь:${NC} ${GREEN}$target_user${NC}"
    echo -e "${CYAN}Домашняя директория:${NC} ${YELLOW}$home_dir${NC}"
    echo ""
    
    # Автоподтверждение для pipe
    if [ -t 0 ]; then
        read -p "Продолжить установку? (Y/n): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
    
    # 1. Установка зависимостей
    echo ""
    echo -e "${PURPLE}ШАГ 1: Установка зависимостей${NC}"
    echo "──────────────────────────────────"
    install_dependencies
    
    # 2. Установка winetricks
    echo ""
    echo -e "${PURPLE}ШАГ 2: Установка Winetricks${NC}"
    echo "────────────────────────────"
    install_winetricks
    
    # 3. Настройка Wine
    echo ""
    echo -e "${PURPLE}ШАГ 3: Настройка Wine${NC}"
    echo "──────────────────────"
    setup_wine_for_user "$target_user" "$home_dir"
    
    # 4. Копирование программ
    echo ""
    echo -e "${PURPLE}ШАГ 4: Копирование программ${NC}"
    echo "──────────────────────────"
    copy_programs "$target_user" "$home_dir"
    
    # 5. Финальный фикс
    echo ""
    echo -e "${PURPLE}ШАГ 5: Финальный фикс${NC}"
    echo "────────────────────"
    create_final_fix "$target_user" "$home_dir"
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                УСТАНОВКА ЗАВЕРШЕНА!                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}ИТОГИ УСТАНОВКИ:${NC}"
    echo "────────────────"
    echo -e "Пользователь:        ${GREEN}$target_user${NC}"
    echo -e "Wine prefix:         ${YELLOW}$home_dir/.wine_medorg${NC}"
    echo -e "Программы:           ${YELLOW}$home_dir/.wine_medorg/drive_c/MedCTech/MedOrg/${NC}"
    echo ""
    
    echo -e "${CYAN}ДЛЯ ЗАПУСКА ПРОГРАММ:${NC}"
    echo "───────────────────"
    echo "1. Выйдите из root: ${YELLOW}exit${NC}"
    echo "2. Войдите как: ${GREEN}$target_user${NC}"
    echo "3. Запустите финальный фикс: ${YELLOW}./final_fix_all.sh${NC}"
    echo "4. Перейдите в папку с программой и запустите:"
    echo -e "   ${YELLOW}cd ~/.wine_medorg/drive_c/MedCTech/MedOrg/StatStac${NC}"
    echo -e "   ${YELLOW}wine StatStacMCT.exe${NC}"
    echo ""
    
    echo -e "${GREEN}Готово! Медицинская система установлена.${NC}"
    echo ""
}

# Обработка Ctrl+C
trap 'echo -e "\n${RED}Установка прервана${NC}"; exit 1' INT

# Запуск
main "$@"