#!/bin/bash
# Создание ЯРЛЫКОВ (.desktop файлов) для медицинских программ с иконками

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
    
    # Основные пути к рабочему столу
    DESKTOP_DIR="$HOME_DIR/Рабочий стол"
    if [ ! -d "$DESKTOP_DIR" ]; then
        DESKTOP_DIR="$HOME_DIR/Desktop"
        if [ ! -d "$DESKTOP_DIR" ]; then
            DESKTOP_DIR="$HOME_DIR/Рабочий стол"
            mkdir -p "$DESKTOP_DIR"
            chown "$USER:$USER" "$DESKTOP_DIR"
        fi
    fi
    
    # Папка для .desktop файлов в системе
    SYSTEM_DESKTOP_DIR="$HOME_DIR/.local/share/applications"
    mkdir -p "$SYSTEM_DESKTOP_DIR"
    chown -R "$USER:$USER" "$SYSTEM_DESKTOP_DIR"
    
    # Папка для иконок
    ICONS_DIR="$HOME_DIR/.local/share/icons"
    mkdir -p "$ICONS_DIR"
    chown -R "$USER:$USER" "$ICONS_DIR"
    
    success "Рабочий стол: $DESKTOP_DIR"
    success "Системные ярлыки: $SYSTEM_DESKTOP_DIR"
    success "Папка иконок: $ICONS_DIR"
}

# Функция для извлечения иконки из EXE файла
extract_icon() {
    local exe_file="$1"
    local icon_name="$2"
    local output_dir="$3"
    
    # Проверяем наличие необходимых утилит
    if ! command -v wrestool &>/dev/null; then
        warning "wrestool не найден, иконки не будут извлечены"
        return 1
    fi
    
    if ! command -v icotool &>/dev/null; then
        warning "icotool не найден, иконки не будут извлечены"
        return 1
    fi
    
    # Создаем временную директорию
    local temp_dir=$(mktemp -d)
    
    # Извлекаем все ресурсы иконок
    if wrestool -x --type=14 "$exe_file" -o "$temp_dir/" 2>/dev/null; then
        # Находим первую извлеченную иконку
        local icon_file=$(find "$temp_dir" -name "*.ico" | head -1)
        
        if [ -n "$icon_file" ] && [ -f "$icon_file" ]; then
            # Конвертируем ICO в PNG
            local png_file="$output_dir/$icon_name.png"
            
            if icotool -x "$icon_file" -o "$png_file" 2>/dev/null; then
                # Берем самую большую иконку (обычно первая в списке)
                local largest_png=$(ls -S "$output_dir/$icon_name"*.png 2>/dev/null | head -1)
                
                if [ -n "$largest_png" ] && [ "$largest_png" != "$png_file" ]; then
                    # Переименовываем самую большую иконку
                    mv "$largest_png" "$png_file"
                    # Удаляем остальные временные PNG
                    rm -f "$output_dir/$icon_name"*.png 2>/dev/null || true
                fi
                
                success "Иконка извлечена: $png_file"
                rm -rf "$temp_dir"
                return 0
            fi
        fi
    fi
    
    # Альтернативный метод с convert (ImageMagick)
    if command -v convert &>/dev/null; then
        log "Пробуем извлечь иконку через convert..."
        
        # Создаем временный файл
        local temp_ico="$temp_dir/temp.ico"
        
        # Пытаемся извлечь иконку через wrestool
        if wrestool -x --type=14 "$exe_file" > "$temp_ico" 2>/dev/null; then
            # Конвертируем в PNG
            if convert "$temp_ico" "$output_dir/$icon_name.png" 2>/dev/null; then
                success "Иконка извлечена через convert"
                rm -rf "$temp_dir"
                return 0
            fi
        fi
    fi
    
    # Если ничего не получилось
    rm -rf "$temp_dir" 2>/dev/null || true
    warning "Не удалось извлечь иконку из $exe_file"
    return 1
}

# Создание правильных .desktop файлов с иконками
create_desktop_files() {
    log "Создание .desktop файлов с иконками..."
    
    INSTALL_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    
    # Создаем папку для ярлыков на рабочем столе
    PROGRAM_DIR="$DESKTOP_DIR/Медицинские программы"
    mkdir -p "$PROGRAM_DIR"
    chown -R "$USER:$USER" "$PROGRAM_DIR"
    
    # Создаем папку для иконок программ
    PROGRAM_ICONS_DIR="$ICONS_DIR/medorg"
    mkdir -p "$PROGRAM_ICONS_DIR"
    chown -R "$USER:$USER" "$PROGRAM_ICONS_DIR"
    
    success "Папка создана: $PROGRAM_DIR"
    success "Папка для иконок: $PROGRAM_ICONS_DIR"
    
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
    
    # Создаем ярлыки для каждого модуля
    local created=0
    local icons_created=0
    local all_modules=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "[A-Z]*" | sort)
    
    if [ -z "$all_modules" ]; then
        warning "Модули не найдены в $INSTALL_DIR"
        return
    fi
    
    log "Поиск модулей для создания ярлыков..."
    
    # Создаем дефолтную иконку для программ без своей иконки
    create_default_icon() {
        local size="$1"
        local output="$2"
        
        if command -v convert &>/dev/null; then
            # Создаем простую синюю иконку с буквой M
            convert -size "${size}x${size}" xc:"#0078D7" \
                    -fill white -pointsize $(($size/2)) \
                    -gravity center -annotate 0 "M" \
                    "$output" 2>/dev/null && return 0
        fi
        return 1
    }
    
    # Создаем иконки по умолчанию разных размеров
    DEFAULT_ICON="$PROGRAM_ICONS_DIR/default.png"
    if [ ! -f "$DEFAULT_ICON" ]; then
        create_default_icon "256" "$DEFAULT_ICON"
        if [ $? -eq 0 ]; then
            log "Создана иконка по умолчанию"
        fi
    fi
    
    while read -r module_dir; do
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
        
        # Имя EXE файла без расширения
        local exe_name=$(basename "$exe_file" .exe)
        
        # ========== ИЗВЛЕКАЕМ ИКОНКУ ==========
        local icon_path=""
        local safe_module_name=$(echo "$module_name" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-')
        local module_icon="$PROGRAM_ICONS_DIR/$safe_module_name.png"
        
        if extract_icon "$exe_file" "$safe_module_name" "$PROGRAM_ICONS_DIR"; then
            if [ -f "$module_icon" ]; then
                icon_path="$module_icon"
                echo -e "  ${GREEN}✓${NC} $module_name: иконка извлечена"
                icons_created=$((icons_created + 1))
            fi
        fi
        
        # Если не удалось извлечь иконку, используем дефолтную
        if [ -z "$icon_path" ]; then
            if [ -f "$DEFAULT_ICON" ]; then
                icon_path="$DEFAULT_ICON"
                echo -e "  ${YELLOW}⚠${NC} $module_name: используется иконка по умолчанию"
            else
                icon_path="wine"  # Используем системную иконку wine
                echo -e "  ${YELLOW}⚠${NC} $module_name: используется системная иконка wine"
            fi
        fi
        
        # ========== СОЗДАЕМ .DESKTOP ФАЙЛ ==========
        
        # 1. Создаем .desktop файл на рабочем столе
        local desktop_file="$DESKTOP_DIR/$module_name.desktop"
        
        cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$module_name
Comment=Медицинская программа $module_name
Exec=env WINEPREFIX="$HOME_DIR/.wine_medorg" WINEARCH=win32 wine "$INSTALL_DIR/$module_name/$exe_name.exe"
Path=$module_dir
Icon=$icon_path
Terminal=false
Categories=Medical;
StartupNotify=true
StartupWMClass=$exe_name.exe
EOF
        
        chmod +x "$desktop_file"
        chown "$USER:$USER" "$desktop_file"
        
        # 2. Создаем .desktop файл в системной папке
        local system_desktop_file="$HOME_DIR/.local/share/applications/medorg-$safe_module_name.desktop"
        
        cat > "$system_desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$module_name (MedOrg)
GenericName=Медицинская программа
Comment=Запуск $module_name через Wine
Exec=env WINEPREFIX="$HOME_DIR/.wine_medorg" WINEARCH=win32 WINEDEBUG=-all wine "$INSTALL_DIR/$module_name/$exe_name.exe"
Path=$module_dir
Icon=$icon_path
Terminal=false
Categories=Medical;
StartupNotify=true
StartupWMClass=$exe_name.exe
MimeType=
Keywords=medical;wine;medorg;
EOF
        
        chmod +x "$system_desktop_file"
        chown "$USER:$USER" "$system_desktop_file"
        
        # 3. Копируем .desktop файл в папку "Медицинские программы"
        cp "$desktop_file" "$PROGRAM_DIR/"
        
        echo -e "  ${GREEN}✓${NC} $module_name (.desktop файл создан)"
        created=$((created + 1))
        
    done <<< "$all_modules"
    
    if [ $created -gt 0 ]; then
        # Создаем мастер-ярлык для запуска всех программ с иконкой папки
        local folder_icon=""
        if [ -f "/usr/share/icons/gnome/256x256/places/folder.png" ]; then
            folder_icon="/usr/share/icons/gnome/256x256/places/folder.png"
        elif [ -f "/usr/share/icons/hicolor/256x256/places/folder.png" ]; then
            folder_icon="/usr/share/icons/hicolor/256x256/places/folder.png"
        else
            # Создаем простую иконку папки
            folder_icon="$PROGRAM_ICONS_DIR/folder.png"
            if [ ! -f "$folder_icon" ] && command -v convert &>/dev/null; then
                convert -size "256x256" xc:"#FFA500" \
                        -fill white -pointsize 80 \
                        -gravity center -annotate 0 "📁" \
                        "$folder_icon" 2>/dev/null || folder_icon="folder"
            fi
        fi
        
        cat > "$DESKTOP_DIR/Медицинские программы.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Медицинские программы
Comment=Папка с медицинскими программами
Exec=xdg-open "$PROGRAM_DIR"
Icon=$folder_icon
Terminal=false
Categories=Medical;
EOF
        
        chmod +x "$DESKTOP_DIR/Медицинские программы.desktop"
        chown "$USER:$USER" "$DESKTOP_DIR/Медицинские программы.desktop"
        
        # Обновляем кэш .desktop файлов и иконок
        log "Обновление кэша .desktop файлов и иконок..."
        sudo -u "$USER" update-desktop-database "$HOME_DIR/.local/share/applications" 2>/dev/null || true
        
        # Обновляем кэш иконок
        if command -v gtk-update-icon-cache &>/dev/null; then
            sudo -u "$USER" gtk-update-icon-cache -f -t "$ICONS_DIR" 2>/dev/null || true
        fi
        
        success "Создано ярлыков: $created"
        if [ $icons_created -gt 0 ]; then
            success "Извлечено иконок: $icons_created"
        fi
        
        # Создаем файл со списком
        cat > "$PROGRAM_DIR/СПИСОК_ПРОГРАММ.txt" << EOF
Установленные медицинские программы:
$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "[A-Z]*" | xargs -I {} basename {} | grep -vE '^(Lib|LibDRV|LibLinux)$' | sort)

Общее количество: $created
Иконок извлечено: $icons_created

Ярлыки созданы в двух местах:
1. На рабочем столе (отдельные .desktop файлы)
2. В меню приложений (через ~/.local/share/applications/)

Если ярлыки не отображаются в меню, обновите кэш:
  update-desktop-database ~/.local/share/applications
  
Если иконки не отображаются, обновите кэш иконок:
  gtk-update-icon-cache -f -t ~/.local/share/icons
EOF
        chown "$USER:$USER" "$PROGRAM_DIR/СПИСОК_ПРОГРАММ.txt"
    else
        warning "Ярлыки не созданы (модули не найдены)"
    fi
}

# Создание вспомогательных скриптов
create_helper_scripts() {
    log "Создание вспомогательных скриптов..."
    
    # Скрипт исправления ярлыков с обновлением иконок
    cat > "$HOME_DIR/Исправить_ярлыки.sh" << EOF
#!/bin/bash
echo "=== ИСПРАВЛЕНИЕ ЯРЛЫКОВ И ИКОНОК ==="
echo ""

# Обновляем кэш .desktop файлов
echo "Обновление кэша .desktop файлов..."
update-desktop-database ~/.local/share/applications 2>/dev/null

# Обновляем кэш иконок
echo "Обновление кэша иконок..."
if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f -t ~/.local/share/icons 2>/dev/null
fi

# Даем права на выполнение всем .desktop файлам
echo "Исправление прав доступа..."
find ~/Рабочий\ стол -name "*.desktop" -exec chmod +x {} \; 2>/dev/null
find ~/Desktop -name "*.desktop" -exec chmod +x {} \; 2>/dev/null
find ~/.local/share/applications -name "*.desktop" -exec chmod +x {} \; 2>/dev/null

# Проверяем иконки
echo ""
echo "Проверка иконок:"
if [ -d ~/.local/share/icons/medorg ] && [ "\$(ls ~/.local/share/icons/medorg/*.png 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "  ✓ Иконки найдены в ~/.local/share/icons/medorg/"
else
    echo "  ⚠ Иконки не найдены, будут использоваться стандартные"
fi

echo ""
echo "Готово! Ярлыки должны отображаться с иконками в меню."
echo ""
echo "Если ярлыки все еще не работают, попробуйте:"
echo "  1. Выйти из системы и зайти снова"
echo "  2. Или выполнить: xdg-desktop-menu forceupdate"
echo "  3. Или перезапустить сессию: pkill gnome-shell || pkill plasmashell"
EOF
    
    chmod +x "$HOME_DIR/Исправить_ярлыки.sh"
    chown "$USER:$USER" "$HOME_DIR/Исправить_ярлыки.sh"
    
    # Скрипт пересоздания ярлыков с извлечением иконок
    cat > "$HOME_DIR/Обновить_ярлыки.sh" << EOF
#!/bin/bash
echo "=== ПЕРЕСОЗДАНИЕ ЯРЛЫКОВ С ИКОНКАМИ ==="
echo ""

# Удаляем старые ярлыки
echo "Удаление старых ярлыков..."
rm -f ~/Рабочий\ стол/*.desktop 2>/dev/null
rm -f ~/Desktop/*.desktop 2>/dev/null
rm -f ~/.local/share/applications/medorg-*.desktop 2>/dev/null
rm -rf ~/Рабочий\ стол/Медицинские\ программы 2>/dev/null
rm -rf ~/Desktop/Медицинские\ программы 2>/dev/null

# Удаляем старые иконки
echo "Удаление старых иконок..."
rm -rf ~/.local/share/icons/medorg 2>/dev/null

echo "Создание новых ярлыков с извлечением иконок..."
# Запускаем модуль создания ярлыков
export TARGET_USER="\$USER"
export TARGET_HOME="\$HOME"
bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/05-create-shortcuts.sh")

echo ""
echo "Готово! Ярлыки пересозданы с иконками."
echo "Выполните для применения:"
echo "  ./Исправить_ярлыки.sh"
EOF
    
    chmod +x "$HOME_DIR/Обновить_ярлыки.sh"
    chown "$USER:$USER" "$HOME_DIR/Обновить_ярлыки.sh"
    
    success "Вспомогательные скрипты созданы"
}

main() {
    echo ""
    echo -e "${CYAN}СОЗДАНИЕ ЯРЛЫКОВ (.DESKTOP) С ИКОНКАМИ ДЛЯ МЕДИЦИНСКИХ ПРОГРАММ${NC}"
    echo ""
    
    check_environment
    get_desktop_path
    create_desktop_files
    create_helper_scripts
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ЯРЛЫКИ С ИКОНКАМИ УСПЕШНО СОЗДАНЫ!            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Создано:${NC}"
    echo -e "${BLUE}────────${NC}"
    echo -e "  ${GREEN}•${NC} Ярлыки на рабочем столе (.desktop файлы с иконками)"
    echo -e "  ${GREEN}•${NC} Системные ярлыки в меню приложений"
    echo -e "  ${GREEN}•${NC} Папка: ${YELLOW}$PROGRAM_DIR${NC}"
    echo -e "  ${GREEN}•${NC} Иконки: ${YELLOW}$ICONS_DIR/medorg/${NC}"
    echo ""
    
    echo -e "${CYAN}ВАЖНО! Для работы иконок:${NC}"
    echo -e "${BLUE}────────────────────────${NC}"
    echo -e "  1. ${YELLOW}Выйдите из системы и зайдите снова${NC}"
    echo -e "  2. Или выполните: ${YELLOW}./Исправить_ярлыки.sh${NC}"
    echo -e "  3. Или обновите кэш иконок: ${YELLOW}gtk-update-icon-cache -f -t ~/.local/share/icons${NC}"
    echo ""
    
    echo -e "${CYAN}Проверьте ярлыки:${NC}"
    echo -e "${BLUE}────────────────${NC}"
    echo -e "  ${YELLOW}./Проверить_ярлыки.sh${NC}"
    echo -e "  ${YELLOW}ls ~/.local/share/icons/medorg/*.png 2>/dev/null | wc -l${NC}"
    echo ""
}

trap 'echo -e "\n${RED}Прервано${NC}"; exit 1' INT
main "$@"