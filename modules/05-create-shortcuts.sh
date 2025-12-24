#!/bin/bash
# Создание ярлыков - исправленная версия

set -e

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
warning() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# Проверка окружения
check_environment() {
    log "Проверка окружения..."
    
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        error "Переменные TARGET_USER и TARGET_HOME не установлены"
        exit 1
    fi
    
    USER="$TARGET_USER"
    HOME_DIR="$TARGET_HOME"
    
    if ! id "$USER" &>/dev/null; then
        error "Пользователь $USER не существует"
        exit 1
    fi
    
    success "Параметры проверены"
    log "Пользователь: $USER"
    log "Домашняя директория: $HOME_DIR"
}

# Определение пути к рабочему столу (ИСПРАВЛЕННАЯ ВЕРСИЯ)
get_desktop_path() {
    log "Определение пути к рабочему столу..."
    
    # Пробуем разные варианты
    local desktop_paths=(
        "$HOME_DIR/Рабочий стол"
        "$HOME_DIR/Desktop" 
        "$HOME_DIR/рабочий стол"
        "$HOME_DIR/desktop"
    )
    
    for path in "${desktop_paths[@]}"; do
        if [ -d "$path" ]; then
            DESKTOP_DIR="$path"
            success "Найден рабочий стол: $DESKTOP_DIR"
            return 0
        fi
    done
    
    # Если не нашли, создаем стандартный (русский)
    DESKTOP_DIR="$HOME_DIR/Рабочий стол"
    mkdir -p "$DESKTOP_DIR"
    chown "$USER:$USER" "$DESKTOP_DIR"
    chmod 755 "$DESKTOP_DIR"
    success "Создан рабочий стол: $DESKTOP_DIR"
}

# Создание папки для ярлыков (ВСЕГДА создается)
create_program_folder() {
    log "Создание папки для медицинских программ..."
    
    PROGRAM_DIR="$DESKTOP_DIR/Медицинские программы"
    
    # Удаляем старую папку если есть
    if [ -d "$PROGRAM_DIR" ]; then
        rm -rf "$PROGRAM_DIR"
    fi
    
    # Создаем новую папку
    mkdir -p "$PROGRAM_DIR"
    chown -R "$USER:$USER" "$PROGRAM_DIR"
    chmod 755 "$PROGRAM_DIR"
    
    # Создаем README файл
    cat > "$PROGRAM_DIR/README.txt" << EOF
Папка для медицинских программ MedOrg

После копирования файлов MedOrg в директорию:
  ~/.wine_medorg/drive_c/MedCTech/MedOrg/

здесь появятся ярлыки для запуска программ.

Для ручного копирования выполните:
1. Подключите сетевую папку:
   mkdir -p /mnt/medorg
   mount -t cifs //10.0.1.11/auto /mnt/medorg -o username=Администратор,password=Ybyjxrf30lh*

2. Скопируйте файлы:
   cp -r /mnt/medorg/* ~/.wine_medorg/drive_c/MedCTech/MedOrg/

3. Исправьте права:
   chown -R $USER:$USER ~/.wine_medorg
   chmod -R 755 ~/.wine_medorg

4. Перезапустите создание ярлыков:
   ./Обновить_ярлыки.sh
EOF
    
    chown "$USER:$USER" "$PROGRAM_DIR/README.txt"
    success "Папка создана: $PROGRAM_DIR"
}

# Проверка и создание ярлыков (если файлы существуют)
create_shortcuts_if_exists() {
    log "Проверка наличия программ..."
    
    INSTALL_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    
    if [ ! -d "$INSTALL_DIR" ]; then
        warning "Директория с программами не найдена: $INSTALL_DIR"
        echo -e "  ${YELLOW}→${NC} Программы еще не скопированы"
        echo -e "  ${YELLOW}→${NC} См. инструкцию в README.txt"
        return
    fi
    
    # Ищем все exe файлы
    local exe_count=$(find "$INSTALL_DIR" -name "*.exe" -type f 2>/dev/null | wc -l)
    
    if [ "$exe_count" -eq 0 ]; then
        warning "EXE файлы не найдены в $INSTALL_DIR"
        echo -e "  ${YELLOW}→${NC} Возможно, неправильная структура папок"
        return
    fi
    
    log "Найдено EXE файлов: $exe_count"
    log "Создание ярлыков..."
    
    local created=0
    find "$INSTALL_DIR" -name "*.exe" -type f | while read -r exe_file; do
        local module_dir=$(dirname "$exe_file")
        local module_name=$(basename "$module_dir")
        local exe_name=$(basename "$exe_file" .exe)
        
        # Пропускаем если это не папка модуля
        if [[ "$module_name" == "." ]] || [[ ! "$module_name" =~ ^[A-Z] ]]; then
            continue
        fi
        
        # Создаем скрипт запуска
        local script_path="$PROGRAM_DIR/$module_name.sh"
        
        cat > "$script_path" << EOF
#!/bin/bash
export WINEPREFIX="$HOME_DIR/.wine_medorg"
export WINEARCH=win32
export WINEDLLPATH="C:\\\\MedCTech\\\\MedOrg\\\\Lib"
export WINEDEBUG="-all"

cd "$module_dir"
wine "$(basename "$exe_file")"
EOF
        
        chmod +x "$script_path"
        chown "$USER:$USER" "$script_path"
        
        # Создаем .desktop файл
        local desktop_file="$PROGRAM_DIR/$module_name.desktop"
        
        cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$module_name
Comment=Медицинская программа
Exec=$script_path
Icon=wine
Terminal=false
Categories=Medical;
EOF
        
        chmod +x "$desktop_file"
        chown "$USER:$USER" "$desktop_file"
        
        created=$((created + 1))
        echo -e "  ${GREEN}✓${NC} $module_name"
    done
    
    if [ $created -gt 0 ]; then
        success "Создано ярлыков: $created"
    else
        warning "Не удалось создать ярлыки"
    fi
}

# Создание вспомогательных скриптов
create_helper_scripts() {
    log "Создание вспомогательных скриптов..."
    
    local script_dir="$HOME_DIR"
    
    # 1. Скрипт исправления прав
    cat > "$script_dir/Исправить_права.sh" << EOF
#!/bin/bash
echo "Исправление прав доступа..."
chown -R $USER:$USER ~/.wine_medorg
chmod -R 755 ~/.wine_medorg
echo "Готово!"
EOF
    
    chmod +x "$script_dir/Исправить_права.sh"
    chown "$USER:$USER" "$script_dir/Исправить_права.sh"
    
    # 2. Скрипт обновления ярлыков
    cat > "$script_dir/Обновить_ярлыки.sh" << EOF
#!/bin/bash
echo "Обновление ярлыков медицинских программ..."
echo ""

# Удаляем старую папку
if [ -d "\$HOME/Рабочий стол/Медицинские программы" ]; then
    rm -rf "\$HOME/Рабочий стол/Медицинские программы"
fi

# Пересоздаем папку
mkdir -p "\$HOME/Рабочий стол/Медицинские программы"

# Ищем EXE файлы
INSTALL_DIR="\$HOME/.wine_medorg/drive_c/MedCTech/MedOrg"
PROGRAM_DIR="\$HOME/Рабочий стол/Медицинские программы"

if [ -d "\$INSTALL_DIR" ]; then
    find "\$INSTALL_DIR" -name "*.exe" -type f | while read -r exe_file; do
        module_dir=\$(dirname "\$exe_file")
        module_name=\$(basename "\$module_dir")
        exe_name=\$(basename "\$exe_file" .exe)
        
        if [[ "\$module_name" =~ ^[A-Z] ]]; then
            # Создаем скрипт запуска
            cat > "\$PROGRAM_DIR/\$module_name.sh" << SCRIPTEOF
#!/bin/bash
export WINEPREFIX="\$HOME/.wine_medorg"
export WINEARCH=win32
export WINEDLLPATH="C:\\\\\\\\MedCTech\\\\\\\\MedOrg\\\\\\\\Lib"

cd "\$module_dir"
wine "\$(basename "\$exe_file")"
SCRIPTEOF
            
            chmod +x "\$PROGRAM_DIR/\$module_name.sh"
            
            # Создаем .desktop файл
            cat > "\$PROGRAM_DIR/\$module_name.desktop" << DESKTOPEOF
[Desktop Entry]
Version=1.0
Type=Application
Name=\$module_name
Comment=Медицинская программа
Exec=\$PROGRAM_DIR/\$module_name.sh
Icon=wine
Terminal=false
Categories=Medical;
DESKTOPEOF
            
            chmod +x "\$PROGRAM_DIR/\$module_name.desktop"
            echo "  ✓ Создан ярлык: \$module_name"
        fi
    done
    
    echo ""
    echo "Готово! Ярлыки обновлены в папке:"
    echo "  \$PROGRAM_DIR"
else
    echo "Ошибка: директория \$INSTALL_DIR не найдена"
    echo "Сначала скопируйте файлы MedOrg"
fi
EOF
    
    chmod +x "$script_dir/Обновить_ярлыки.sh"
    chown "$USER:$USER" "$script_dir/Обновить_ярлыки.sh"
    
    # 3. Скрипт подключения сетевой папки
    cat > "$script_dir/Подключить_сетевую_папку.sh" << 'EOF'
#!/bin/bash
echo "Подключение к сетевой папке MedOrg..."
echo ""

# Создаем точку монтирования
MOUNT_POINT="/mnt/medorg_share"
sudo mkdir -p "$MOUNT_POINT"

# Параметры подключения
SERVER="//10.0.1.11/auto"
USERNAME="Администратор"
PASSWORD="Ybyjxrf30lh*"

echo "Подключаемся к: $SERVER"
echo "Пользователь: $USERNAME"
echo ""

# Пробуем подключиться
if sudo mount -t cifs "$SERVER" "$MOUNT_POINT" -o "username=$USERNAME,password=$PASSWORD,uid=$(id -u),gid=$(id -g),iocharset=utf8"; then
    echo "✓ Сетевая папка успешно подключена"
    echo ""
    echo "Содержимое папки:"
    ls -la "$MOUNT_POINT"
    echo ""
    echo "Для копирования файлов выполните:"
    echo "cp -r $MOUNT_POINT/* ~/.wine_medorg/drive_c/MedCTech/MedOrg/"
    echo ""
    echo "Для отключения:"
    echo "sudo umount $MOUNT_POINT"
else
    echo "✗ Не удалось подключиться к сетевой папке"
    echo ""
    echo "Возможные причины:"
    echo "1. Сервер недоступен"
    echo "2. Неверные учетные данные"
    echo "3. Нет пакета cifs-utils"
    echo ""
    echo "Проверьте: sudo dnf install cifs-utils"
fi
EOF
    
    chmod +x "$script_dir/Подключить_сетевую_папку.sh"
    chown "$USER:$USER" "$script_dir/Подключить_сетевую_папку.sh"
    
    success "Вспомогательные скрипты созданы"
}

# Основная функция
main() {
    echo ""
    echo -e "${CYAN}СОЗДАНИЕ ПАПКИ И СКРИПТОВ${NC}"
    echo ""
    
    # Проверка окружения
    check_environment
    
    # Определение рабочего стола
    get_desktop_path
    
    # ВСЕГДА создаем папку (даже если файлов нет)
    create_program_folder
    
    # Пробуем создать ярлыки (если файлы есть)
    create_shortcuts_if_exists
    
    # Создание вспомогательных скриптов
    create_helper_scripts
    
    # Итог
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      ПАПКА И СКРИПТЫ СОЗДАНЫ!                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Создано:${NC}"
    echo -e "${BLUE}────────${NC}"
    echo -e "  ${GREEN}•${NC} Папка: ${YELLOW}$DESKTOP_DIR/Медицинские программы/${NC}"
    echo -e "  ${GREEN}•${NC} Скрипты в домашней директории:"
    echo -e "      ${YELLOW}•${NC} Исправить_права.sh"
    echo -e "      ${YELLOW}•${NC} Обновить_ярлыки.sh"
    echo -e "      ${YELLOW}•${NC} Подключить_сетевую_папку.sh"
    echo ""
    
    echo -e "${CYAN}Следующие шаги:${NC}"
    echo -e "${BLUE}────────────────${NC}"
    echo "1. Подключите сетевую папку:"
    echo -e "   ${YELLOW}./Подключить_сетевую_папку.sh${NC}"
    echo "2. Скопируйте файлы:"
    echo -e "   ${YELLOW}cp -r /mnt/medorg_share/* ~/.wine_medorg/drive_c/MedCTech/MedOrg/${NC}"
    echo "3. Обновите ярлыки:"
    echo -e "   ${YELLOW}./Обновить_ярлыки.sh${NC}"
    echo ""
}

# Обработка прерывания
trap 'echo -e "\n${RED}Создание прервано${NC}"; exit 1' INT

# Запуск
main "$@"