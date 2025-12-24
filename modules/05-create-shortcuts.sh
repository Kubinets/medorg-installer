#!/bin/bash
# Создание ЯРЛЫКОВ (.desktop файлов) для медицинских программ

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
    
    success "Рабочий стол: $DESKTOP_DIR"
    success "Системные ярлыки: $SYSTEM_DESKTOP_DIR"
}

# Создание правильных .desktop файлов
create_desktop_files() {
    log "Создание .desktop файлов..."
    
    INSTALL_DIR="$HOME_DIR/.wine_medorg/drive_c/MedCTech/MedOrg"
    
    # Создаем папку для ярлыков на рабочем столе
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
    
    # Создаем ярлыки для каждого модуля
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
        
        # Имя EXE файла без расширения
        local exe_name=$(basename "$exe_file" .exe)
        
        # ========== СОЗДАЕМ .DESKTOP ФАЙЛ ==========
        
        # 1. Сначала создаем скрипт-обертку
        local wrapper_script="$PROGRAM_DIR/$module_name-wrapper.sh"
        
        cat > "$wrapper_script" << EOF
#!/bin/bash
# Обертка для запуска $module_name через Wine

export WINEPREFIX="$HOME_DIR/.wine_medorg"
export WINEARCH=win32
export WINEDEBUG="-all"
export DISPLAY=":0"

cd "$module_dir"
exec wine "$exe_name.exe"
EOF
        
        chmod +x "$wrapper_script"
        chown "$USER:$USER" "$wrapper_script"
        
        # 2. Создаем .desktop файл на рабочем столе
        local desktop_file="$DESKTOP_DIR/$module_name.desktop"
        
        cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$module_name
Comment=Медицинская программа $module_name
Exec=env WINEPREFIX="$HOME_DIR/.wine_medorg" WINEARCH=win32 wine "$INSTALL_DIR/$module_name/$exe_name.exe"
Path=$module_dir
Icon=wine
Terminal=false
Categories=Medical;
StartupNotify=true
StartupWMClass=$exe_name.exe
EOF
        
        chmod +x "$desktop_file"
        chown "$USER:$USER" "$desktop_file"
        
        # 3. Создаем .desktop файл в системной папке
        local system_desktop_file="$HOME_DIR/.local/share/applications/medorg-$module_name.desktop"
        
        cat > "$system_desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$module_name (MedOrg)
GenericName=Медицинская программа
Comment=Запуск $module_name через Wine
Exec=env WINEPREFIX="$HOME_DIR/.wine_medorg" WINEARCH=win32 WINEDEBUG=-all wine "$INSTALL_DIR/$module_name/$exe_name.exe"
Path=$module_dir
Icon=wine
Terminal=false
Categories=Medical;
StartupNotify=true
StartupWMClass=$exe_name.exe
MimeType=
Keywords=medical;wine;medorg;
EOF
        
        chmod +x "$system_desktop_file"
        chown "$USER:$USER" "$system_desktop_file"
        
        # 4. Копируем .desktop файл в папку "Медицинские программы"
        cp "$desktop_file" "$PROGRAM_DIR/"
        
        echo -e "  ${GREEN}✓${NC} $module_name (.desktop файл создан)"
        created=$((created + 1))
    done
    
    if [ $created -gt 0 ]; then
        # Создаем мастер-ярлык для запуска всех программ
        cat > "$DESKTOP_DIR/Медицинские программы.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Медицинские программы
Comment=Папка с медицинскими программами
Exec=xdg-open "$PROGRAM_DIR"
Icon=folder
Terminal=false
Categories=Medical;
EOF
        
        chmod +x "$DESKTOP_DIR/Медицинские программы.desktop"
        chown "$USER:$USER" "$DESKTOP_DIR/Медицинские программы.desktop"
        
        # Обновляем кэш .desktop файлов
        log "Обновление кэша .desktop файлов..."
        sudo -u "$USER" update-desktop-database "$HOME_DIR/.local/share/applications" 2>/dev/null || true
        
        success "Создано ярлыков: $created"
        
        # Создаем файл со списком
        cat > "$PROGRAM_DIR/СПИСОК_ПРОГРАММ.txt" << EOF
Установленные медицинские программы:
$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "[A-Z]*" | xargs -I {} basename {} | grep -vE '^(Lib|LibDRV|LibLinux)$' | sort)

Общее количество: $created

Ярлыки созданы в двух местах:
1. На рабочем столе (отдельные .desktop файлы)
2. В меню приложений (через ~/.local/share/applications/)

Если ярлыки не отображаются в меню, обновите кэш:
  update-desktop-database ~/.local/share/applications
EOF
        chown "$USER:$USER" "$PROGRAM_DIR/СПИСОК_ПРОГРАММ.txt"
    else
        warning "Ярлыки не созданы (модули не найдены)"
    fi
}

# Создание вспомогательных скриптов
create_helper_scripts() {
    log "Создание вспомогательных скриптов..."
    
    # Скрипт исправления ярлыков
    cat > "$HOME_DIR/Исправить_ярлыки.sh" << EOF
#!/bin/bash
echo "=== ИСПРАВЛЕНИЕ ЯРЛЫКОВ ==="
echo ""

# Обновляем кэш .desktop файлов
echo "Обновление кэша .desktop файлов..."
update-desktop-database ~/.local/share/applications 2>/dev/null

# Даем права на выполнение всем .desktop файлам
echo "Исправление прав доступа..."
find ~/Рабочий\ стол -name "*.desktop" -exec chmod +x {} \; 2>/dev/null
find ~/Desktop -name "*.desktop" -exec chmod +x {} \; 2>/dev/null
find ~/.local/share/applications -name "*.desktop" -exec chmod +x {} \; 2>/dev/null

echo ""
echo "Готово! Ярлыки должны отображаться в меню."
echo ""
echo "Если ярлыки все еще не работают, попробуйте:"
echo "  1. Выйти из системы и зайти снова"
echo "  2. Или выполнить: xdg-desktop-menu forceupdate"
EOF
    
    chmod +x "$HOME_DIR/Исправить_ярлыки.sh"
    chown "$USER:$USER" "$HOME_DIR/Исправить_ярлыки.sh"
    
    # Скрипт проверки
    cat > "$HOME_DIR/Проверить_ярлыки.sh" << EOF
#!/bin/bash
echo "=== ПРОВЕРКА ЯРЛЫКОВ ==="
echo ""

INSTALL_DIR="\$HOME/.wine_medorg/drive_c/MedCTech/MedOrg"

echo "1. Установленные программы в \$INSTALL_DIR/:"
echo "-------------------------------------------"
if [ -d "\$INSTALL_DIR" ]; then
    find "\$INSTALL_DIR" -maxdepth 1 -type d -name "[A-Z]*" | xargs -I {} basename {} | grep -vE '^(Lib|LibDRV|LibLinux)$' | sort
else
    echo "  Не найдены!"
fi

echo ""
echo "2. Ярлыки на рабочем столе:"
echo "---------------------------"
if [ -d "\$HOME/Рабочий стол" ]; then
    find "\$HOME/Рабочий стол" -name "*.desktop" -exec basename {} \; | sort
elif [ -d "\$HOME/Desktop" ]; then
    find "\$HOME/Desktop" -name "*.desktop" -exec basename {} \; | sort
else
    echo "  Папка рабочего стола не найдена"
fi

echo ""
echo "3. Системные ярлыки:"
echo "-------------------"
find "\$HOME/.local/share/applications" -name "medorg-*.desktop" -exec basename {} \; 2>/dev/null | sort

echo ""
echo "4. Права доступа:"
echo "----------------"
echo -n "  .desktop файлы на рабочем столе: "
if find "\$HOME/Рабочий стол" -name "*.desktop" -executable 2>/dev/null | grep -q .; then
    echo "OK (есть исполняемые)"
else
    echo "НЕТ исполняемых!"
fi

echo -n "  Системные .desktop файлы: "
if find "\$HOME/.local/share/applications" -name "*.desktop" -executable 2>/dev/null | grep -q .; then
    echo "OK"
else
    echo "НЕТ исполняемых!"
fi
EOF
    
    chmod +x "$HOME_DIR/Проверить_ярлыки.sh"
    chown "$USER:$USER" "$HOME_DIR/Проверить_ярлыки.sh"
    
    # Скрипт пересоздания ярлыков
    cat > "$HOME_DIR/Обновить_ярлыки.sh" << EOF
#!/bin/bash
echo "=== ПЕРЕСОЗДАНИЕ ЯРЛЫКОВ ==="
echo ""

# Удаляем старые ярлыки
echo "Удаление старых ярлыков..."
rm -f ~/Рабочий\ стол/*.desktop 2>/dev/null
rm -f ~/Desktop/*.desktop 2>/dev/null
rm -f ~/.local/share/applications/medorg-*.desktop 2>/dev/null
rm -rf ~/Рабочий\ стол/Медицинские\ программы 2>/dev/null
rm -rf ~/Desktop/Медицинские\ программы 2>/dev/null

echo "Создание новых ярлыков..."
# Запускаем модуль создания ярлыков
export TARGET_USER="\$USER"
export TARGET_HOME="\$HOME"
bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/05-create-shortcuts.sh")

echo ""
echo "Готово! Ярлыки пересозданы."
echo "Выполните для применения:"
echo "  ./Исправить_ярлыки.sh"
EOF
    
    chmod +x "$HOME_DIR/Обновить_ярлыки.sh"
    chown "$USER:$USER" "$HOME_DIR/Обновить_ярлыки.sh"
    
    success "Вспомогательные скрипты созданы"
}

main() {
    echo ""
    echo -e "${CYAN}СОЗДАНИЕ ЯРЛЫКОВ (.DESKTOP) ДЛЯ МЕДИЦИНСКИХ ПРОГРАММ${NC}"
    echo ""
    
    check_environment
    get_desktop_path
    create_desktop_files
    create_helper_scripts
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      ЯРЛЫКИ УСПЕШНО СОЗДАНЫ!                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Создано:${NC}"
    echo -e "${BLUE}────────${NC}"
    echo -e "  ${GREEN}•${NC} Ярлыки на рабочем столе (.desktop файлы)"
    echo -e "  ${GREEN}•${NC} Системные ярлыки в меню приложений"
    echo -e "  ${GREEN}•${NC} Папка: ${YELLOW}$PROGRAM_DIR${NC}"
    echo ""
    
    echo -e "${CYAN}ВАЖНО! Для работы ярлыков:${NC}"
    echo -e "${BLUE}────────────────────────${NC}"
    echo -e "  1. ${YELLOW}Выйдите из системы и зайдите снова${NC}"
    echo -e "  2. Или выполните: ${YELLOW}./Исправить_ярлыки.sh${NC}"
    echo -e "  3. Ярлыки появятся в меню приложений и на рабочем столе"
    echo ""
    
    echo -e "${CYAN}Проверьте ярлыки:${NC}"
    echo -e "${BLUE}────────────────${NC}"
    echo -e "  ${YELLOW}./Проверить_ярлыки.sh${NC}"
    echo ""
}

trap 'echo -e "\n${RED}Прервано${NC}"; exit 1' INT
main "$@"