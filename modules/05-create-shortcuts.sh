#!/bin/bash
# Создание ярлыков с иконками - исправленная версия

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

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
}

get_desktop_path() {
    log "Определение рабочего стола..."
    
    DESKTOP_DIR="$HOME_DIR/Рабочий стол"
    if [ ! -d "$DESKTOP_DIR" ]; then
        DESKTOP_DIR="$HOME_DIR/Desktop"
        if [ ! -d "$DESKTOP_DIR" ]; then
            DESKTOP_DIR="$HOME_DIR/Рабочий стол"
            mkdir -p "$DESKTOP_DIR"
            chown "$USER:$USER" "$DESKTOP_DIR"
        fi
    fi
    
    success "Рабочий стол: $DESKTOP_DIR"
}

# Извлечение иконок из EXE файлов
extract_icons() {
    local install_dir="$1"
    local icon_dir="$2"
    
    log "Извлечение иконок из EXE файлов..."
    
    mkdir -p "$icon_dir/64"
    mkdir -p "$icon_dir/32"
    mkdir -p "$icon_dir/16"
    
    if [ ! -d "$install_dir" ]; then
        warning "Директория программ не найдена: $install_dir"
        return
    fi
    
    # Ищем все EXE файлы в установленных модулях
    local exe_files=$(find "$install_dir" -name "*.exe" -type f 2>/dev/null)
    
    if [ -z "$exe_files" ]; then
        warning "EXE файлы не найдены"
        return
    fi
    
    echo "$exe_files" | while read -r exe_file; do
        local module_dir=$(dirname "$exe_file")
        local module_name=$(basename "$module_dir")
        local exe_name=$(basename "$exe_file" .exe)
        
        # Пропускаем если не папка модуля или это служебные модули
        if [[ "$module_name" == "." ]] || [[ ! "$module_name" =~ ^[A-Z] ]] || \
           [[ "$module_name" == "Lib" ]] || [[ "$module_name" == "LibDRV" ]] || [[ "$module_name" == "LibLinux" ]]; then
            continue
        fi
        
        echo -n "  $module_name... "
        
        # Извлекаем иконку
        cd "$module_dir" 2>/dev/null || continue
        if wrestool -x -o "/tmp/${module_name}_icon.ico" "$exe_name.exe" 2>/dev/null; then
            # Конвертируем в PNG
            if convert "/tmp/${module_name}_icon.ico[0]" "$icon_dir/64/${module_name}.png" 2>/dev/null; then
                convert "$icon_dir/64/${module_name}.png" -resize 32x32 "$icon_dir/32/${module_name}.png" 2>/dev/null
                convert "$icon_dir/64/${module_name}.png" -resize 16x16 "$icon_dir/16/${module_name}.png" 2>/dev/null
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}!${NC} (ошибка конвертации)"
            fi
            rm -f "/tmp/${module_name}_icon.ico" 2>/dev/null
        else
            echo -e "${YELLOW}!${NC} (иконка не извлечена)"
        fi
    done
    
    chown -R "$USER:$USER" "$icon_dir"
}

# Создание ярлыков для установленных модулей
create_shortcuts() {
    log "Создание ярлыков..."
    
    INSTALL_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    ICON_DIR="$HOME_DIR/.local/share/icons/medorg"
    
    # Создаем папку для ярлыков
    PROGRAM_DIR="$DESKTOP_DIR/Медицинские программы"
    mkdir -p "$PROGRAM_DIR"
    chown -R "$USER:$USER" "$PROGRAM_DIR"
    
    success "Папка создана: $PROGRAM_DIR"
    
    # Проверяем, есть ли установленные модули
    if [ ! -d "$INSTALL_DIR" ]; then
        warning "Директория с программами не найдена: $INSTALL_DIR"
        
        # Создаем инструкцию
        cat > "$PROGRAM_DIR/ИНСТРУКЦИЯ.txt" << EOF
Ярлыки не созданы, потому что файлы MedOrg не найдены.

Для установки:
1. Подключите сетевую папку:
   sudo mount -t cifs //10.0.1.11/auto /mnt/medorg -o username=Администратор,password=Ybyjxrf30lh*

2. Скопируйте файлы:
   cp -r /mnt/medorg/Lib /mnt/medorg/LibDRV /mnt/medorg/LibLinux $INSTALL_DIR/

3. Если выбраны дополнительные модули, скопируйте их:
   cp -r /mnt/medorg/НАЗВАНИЕ_МОДУЛЯ $INSTALL_DIR/

4. Перезапустите создание ярлыков:
   ./Обновить_ярлыки.sh
EOF
        chown "$USER:$USER" "$PROGRAM_DIR/ИНСТРУКЦИЯ.txt"
        return
    fi
    
    # Извлекаем иконки
    extract_icons "$INSTALL_DIR" "$ICON_DIR"
    
    # Создаем ярлыки для каждого модуля (кроме служебных)
    local created=0
    local all_modules=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "[A-Z]*" | sort)
    
    if [ -z "$all_modules" ]; then
        warning "Модули не найдены в $INSTALL_DIR"
        return
    fi
    
    log "Поиск модулей для создания ярлыков..."
    
    echo "$all_modules" | while read -r module_dir; do
        local module_name=$(basename "$module_dir")
        
        # Пропускаем служебные модули
        if [[ "$module_name" == "Lib" ]] || [[ "$module_name" == "LibDRV" ]] || [[ "$module_name" == "LibLinux" ]]; then
            continue
        fi
        
        # Ищем EXE файл в модуле
        local exe_file=$(find "$module_dir" -maxdepth 1 -name "*.exe" -type f | head -1)
        
        if [ -z "$exe_file" ]; then
            warning "  $module_name: EXE файл не найден"
            continue
        fi
        
        # Путь к иконке
        local icon_path="wine"
        if [ -f "$ICON_DIR/32/${module_name}.png" ]; then
            icon_path="$ICON_DIR/32/${module_name}.png"
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
        
        # Создаем desktop файл
        local desktop_file="$PROGRAM_DIR/$module_name.desktop"
        
        cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$module_name
Comment=Медицинская программа
Exec=$script_path
Icon=$icon_path
Terminal=false
Categories=Medical;
EOF
        
        chmod +x "$desktop_file"
        chown "$USER:$USER" "$desktop_file"
        
        echo -e "  ${GREEN}✓${NC} $module_name"
        created=$((created + 1))
    done
    
    if [ $created -gt 0 ]; then
        success "Создано ярлыков: $created"
        
        # Создаем файл со списком модулей
        cat > "$PROGRAM_DIR/СПИСОК_МОДУЛЕЙ.txt" << EOF
Установленные модули:
$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "[A-Z]*" | xargs -I {} basename {} | grep -vE '^(Lib|LibDRV|LibLinux)$' | sort)

Общее количество: $created
EOF
        chown "$USER:$USER" "$PROGRAM_DIR/СПИСОК_МОДУЛЕЙ.txt"
    else
        warning "Ярлыки не созданы (модули не найдены)"
    fi
}

# Создание вспомогательных скриптов
create_helper_scripts() {
    log "Создание вспомогательных скриптов..."
    
    # Скрипт обновления ярлыков
    cat > "$HOME_DIR/Обновить_ярлыки.sh" << EOF
#!/bin/bash
echo "=== ОБНОВЛЕНИЕ ЯРЛЫКОВ МЕДИЦИНСКИХ ПРОГРАММ ==="
echo ""

# Удаляем старые ярлыки
echo "Удаление старых ярлыков..."
rm -rf "\$HOME/Рабочий стол/Медицинские программы" 2>/dev/null
rm -rf "\$HOME/Desktop/Медицинские программы" 2>/dev/null

echo "Создание новых ярлыков..."
# Запускаем модуль создания ярлыков
bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/05-create-shortcuts.sh?cache=\$(date +%s)")

echo ""
echo "Готово! Проверьте папку 'Медицинские программы' на рабочем столе."
EOF
    
    chmod +x "$HOME_DIR/Обновить_ярлыки.sh"
    chown "$USER:$USER" "$HOME_DIR/Обновить_ярлыки.sh"
    
    # Скрипт проверки установленных модулей
    cat > "$HOME_DIR/Проверить_модули.sh" << EOF
#!/bin/bash
echo "=== ПРОВЕРКА УСТАНОВЛЕННЫХ МОДУЛЕЙ ==="
echo ""

INSTALL_DIR="\$HOME/.wine_medorg/drive_c/MedCTech/MedOrg"

if [ -d "\$INSTALL_DIR" ]; then
    echo "Установленные модули в \$INSTALL_DIR/:"
    echo "-------------------------------------"
    find "\$INSTALL_DIR" -maxdepth 1 -type d -name "[A-Z]*" | xargs -I {} basename {} | sort | column -c 80
    
    echo ""
    echo "Обязательные модули:"
    for module in Lib LibDRV LibLinux; do
        if [ -d "\$INSTALL_DIR/\$module" ]; then
            echo "  ✓ \$module"
        else
            echo "  ✗ \$module (ОТСУТСТВУЕТ!)"
        fi
    done
    
    echo ""
    echo "Дополнительные модули:"
    find "\$INSTALL_DIR" -maxdepth 1 -type d -name "[A-Z]*" | xargs -I {} basename {} | grep -vE '^(Lib|LibDRV|LibLinux)$' | while read module; do
        echo "  ✓ \$module"
    done
else
    echo "Ошибка: директория \$INSTALL_DIR не найдена"
fi
EOF
    
    chmod +x "$HOME_DIR/Проверить_модули.sh"
    chown "$USER:$USER" "$HOME_DIR/Проверить_модули.sh"
    
    success "Вспомогательные скрипты созданы"
}

main() {
    echo ""
    echo -e "${CYAN}СОЗДАНИЕ ЯРЛЫКОВ ДЛЯ МЕДИЦИНСКИХ ПРОГРАММ${NC}"
    echo ""
    
    check_environment
    get_desktop_path
    create_shortcuts
    create_helper_scripts
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      ЯРЛЫКИ УСПЕШНО СОЗДАНЫ!                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Создано:${NC}"
    echo -e "${BLUE}────────${NC}"
    echo -e "  ${GREEN}•${NC} Папка: ${YELLOW}$DESKTOP_DIR/Медицинские программы/${NC}"
    echo -e "  ${GREEN}•${NC} Вспомогательные скрипты:"
    echo -e "      ${YELLOW}•${NC} Обновить_ярлыки.sh"
    echo -e "      ${YELLOW}•${NC} Проверить_модули.sh"
    echo ""
    
    echo -e "${CYAN}Для обновления ярлыков выполните:${NC}"
    echo -e "${BLUE}────────────────────────────────${NC}"
    echo -e "  ${YELLOW}./Обновить_ярлыки.sh${NC}"
    echo ""
}

trap 'echo -e "\n${RED}Прервано${NC}"; exit 1' INT
main "$@"