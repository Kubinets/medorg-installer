#!/bin/bash
# Создание ярлыков (исправленная версия)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${RED}!${NC} $1"; }

create_shortcuts() {
    log "Создание ярлыков..."
    
    # Определяем путь к рабочему столу (для разных локалей)
    DESKTOP_RU="$TARGET_HOME/Рабочий стол/Медицинские программы"
    DESKTOP_EN="$TARGET_HOME/Desktop/Медицинские программы"
    DESKTOP=""
    
    # Проверяем, какая директория существует
    if [ -d "$(dirname "$DESKTOP_RU")" ]; then
        DESKTOP="$DESKTOP_RU"
    elif [ -d "$(dirname "$DESKTOP_EN")" ]; then
        DESKTOP="$DESKTOP_EN"
    else
        # Создаем стандартный путь
        DESKTOP="$TARGET_HOME/Desktop/Медицинские программы"
    fi
    
    # Создаем директорию для ярлыков
    sudo -u "$TARGET_USER" mkdir -p "$DESKTOP"
    log "Директория для ярлыков: $DESKTOP"
    
    # Базовый путь к программе
    MEDORG_PATH="$TARGET_HOME/.wine_medorg/drive_c/MedCTech/MedOrg"
    
    # Проверяем существование пути
    if [ ! -d "$MEDORG_PATH" ]; then
        warning "Директория MedOrg не найдена: $MEDORG_PATH"
        warning "Ярлыки не будут созданы"
        return 1
    fi
    
    # Создаем ярлыки для всех модулей, которые существуют
    log "Поиск модулей для создания ярлыков..."
    
    # Используем массив из основной программы
    # Если SELECTED_MODULES не пустой, используем его
    # Иначе используем обязательные модули
    if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
        MODULES_TO_CREATE=("Lib" "LibDRV" "LibLinux")
    else
        MODULES_TO_CREATE=("${SELECTED_MODULES[@]}")
    fi
    
    # Добавляем обязательные модули, если их нет в списке
    for req_module in "Lib" "LibDRV" "LibLinux"; do
        if [[ ! " ${MODULES_TO_CREATE[@]} " =~ " ${req_module} " ]]; then
            MODULES_TO_CREATE+=("$req_module")
        fi
    done
    
    created_count=0
    
    # Создаем ярлык для каждого модуля
    for module in "${MODULES_TO_CREATE[@]}"; do
        MODULE_PATH="$MEDORG_PATH/$module"
        
        if [ -d "$MODULE_PATH" ]; then
            # Ищем exe файл в директории модуля
            EXE_FILE=$(find "$MODULE_PATH" -name "*.exe" -type f | head -1)
            
            if [ -n "$EXE_FILE" ]; then
                # Создаем .desktop файл
                DESKTOP_FILE="$DESKTOP/${module}.desktop"
                
                # Создаем содержимое .desktop файла
                sudo -u "$TARGET_USER" bash -c "
cat > '$DESKTOP_FILE' << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=MedOrg $module
Comment=Медицинская информационная система
Exec=env WINEPREFIX='$TARGET_HOME/.wine_medorg' WINEARCH=win32 wine '$EXE_FILE'
Path=$MODULE_PATH
Icon=wine
Terminal=false
StartupNotify=false
Categories=Medical;
EOF
"
                
                # Устанавливаем права
                sudo -u "$TARGET_USER" chmod +x "$DESKTOP_FILE"
                
                log "  Создан: $module → $(basename "$EXE_FILE")"
                created_count=$((created_count + 1))
            else
                warning "  Нет .exe файла в модуле: $module"
            fi
        else
            warning "  Директория модуля не найдена: $module"
        fi
    done
    
    # Создаем скрипт запуска всех программ
    create_launcher_script "$DESKTOP"
    
    if [ $created_count -gt 0 ]; then
        success "Создано ярлыков: $created_count"
        success "Ярлыки расположены в: $DESKTOP"
    else
        warning "Не создано ни одного ярлыка!"
    fi
}

# Функция создания скрипта-лаунчера
create_launcher_script() {
    local desktop_dir="$1"
    
    LAUNCHER_SCRIPT="$desktop_dir/Запустить все программы.sh"
    
    sudo -u "$TARGET_USER" bash -c "
cat > '$LAUNCHER_SCRIPT' << 'EOF'
#!/bin/bash
# Скрипт запуска всех медицинских программ

echo 'Запуск медицинских программ...'
echo '================================'

PROGRAMS_DIR='$MEDORG_PATH'
WINE_PREFIX='$TARGET_HOME/.wine_medorg'

# Экспортируем переменные Wine
export WINEPREFIX=\"\$WINE_PREFIX\"
export WINEARCH=win32

# Запускаем основные модули
for module in Lib LibDRV LibLinux; do
    if [ -d \"\$PROGRAMS_DIR/\$module\" ]; then
        exe_file=\$(find \"\$PROGRAMS_DIR/\$module\" -name \"*.exe\" -type f | head -1)
        if [ -n \"\$exe_file\" ]; then
            echo \"Запускаем \$module...\"
            wine \"\$exe_file\" &
            sleep 1
        fi
    fi
done

echo '================================'
echo 'Программы запущены в фоновом режиме'
echo 'Закройте это окно после запуска всех программ'
EOF
"
    
    sudo -u "$TARGET_USER" chmod +x "$LAUNCHER_SCRIPT"
    log "  Создан скрипт-лаунчер: $(basename "$LAUNCHER_SCRIPT")"
}

# Основная функция
main() {
    if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
        warning "Ошибка: TARGET_USER или TARGET_HOME не установлены"
        exit 1
    fi
    
    log "Пользователь: $TARGET_USER"
    log "Домашняя директория: $TARGET_HOME"
    
    # Проверяем, установлена ли переменная SELECTED_MODULES
    if [ -z "${SELECTED_MODULES+x}" ]; then
        warning "Переменная SELECTED_MODULES не установлена, используются только обязательные модули"
        SELECTED_MODULES=()
    fi
    
    create_shortcuts
}

# Запуск
main "$@"