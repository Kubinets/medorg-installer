#!/bin/bash
# Создание ярлыков - ЛОКАЛЬНАЯ версия (без загрузок)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

create_shortcuts() {
    log "Создание ярлыков для пользователя: $TARGET_USER"
    
    # Определяем путь к рабочему столу
    DESKTOP_DIR="$TARGET_HOME/Рабочий стол"
    if [ ! -d "$DESKTOP_DIR" ]; then
        DESKTOP_DIR="$TARGET_HOME/Desktop"
    fi
    
    PROGRAM_DIR="$DESKTOP_DIR/Медицинские программы"
    
    # Создаем директорию для ярлыков
    mkdir -p "$PROGRAM_DIR"
    chown -R "$TARGET_USER:$TARGET_USER" "$PROGRAM_DIR"
    
    log "Директория для ярлыков: $PROGRAM_DIR"
    
    # Путь к установленным программам
    INSTALL_DIR="$TARGET_HOME/.wine_medorg/drive_c/MedCTech/MedOrg"
    
    if [ ! -d "$INSTALL_DIR" ]; then
        warning "Директория с программами не найдена: $INSTALL_DIR"
        warning "Создаю базовые ярлыки..."
        create_basic_shortcuts "$PROGRAM_DIR"
        return
    fi
    
    # Определяем какие модули создавать
    if [ -z "${SELECTED_MODULES+x}" ] || [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
        # Если SELECTED_MODULES не задан, используем обязательные модули
        MODULES=("Lib" "LibDRV" "LibLinux")
        log "Использую обязательные модули"
    else
        MODULES=("${SELECTED_MODULES[@]}")
        log "Использую выбранные модули"
    fi
    
    created=0
    
    # Создаем ярлыки для каждого модуля
    for module in "${MODULES[@]}"; do
        MODULE_PATH="$INSTALL_DIR/$module"
        
        if [ -d "$MODULE_PATH" ]; then
            # Ищем .exe файл в директории модуля
            EXE_FILE=$(find "$MODULE_PATH" -maxdepth 1 -name "*.exe" -type f | head -n 1)
            
            if [ -n "$EXE_FILE" ]; then
                create_desktop_file "$PROGRAM_DIR" "$module" "$EXE_FILE"
                created=$((created + 1))
            else
                warning "Не найден .exe файл для модуля: $module"
            fi
        else
            warning "Директория модуля не найдена: $module"
        fi
    done
    
    # Создаем вспомогательные ярлыки
    create_helper_shortcuts "$PROGRAM_DIR"
    
    if [ $created -gt 0 ]; then
        success "Создано ярлыков: $created"
        success "Ярлыки расположены в: $PROGRAM_DIR"
    else
        warning "Не удалось создать ни одного ярлыка"
    fi
}

create_desktop_file() {
    local program_dir="$1"
    local module="$2"
    local exe_file="$3"
    
    DESKTOP_FILE="$program_dir/$module.desktop"
    
    # Создаем .desktop файл
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MedOrg $module
Comment=Медицинская информационная система
Exec=env WINEPREFIX="$TARGET_HOME/.wine_medorg" WINEARCH=win32 wine "$exe_file"
Path=$(dirname "$exe_file")
Icon=wine
Terminal=false
StartupNotify=false
Categories=Medical;
EOF
    
    # Устанавливаем права
    chown "$TARGET_USER:$TARGET_USER" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    
    log "  Создан ярлык: $module"
}

create_basic_shortcuts() {
    local program_dir="$1"
    
    # Создаем хотя бы один базовый ярлык
    cat > "$program_dir/Запуск_MedOrg.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Запуск MedOrg
Comment=Запуск медицинской информационной системы
Exec=echo "Для запуска программ войдите под пользователем $TARGET_USER и запустите нужный модуль"
Icon=wine
Terminal=true
StartupNotify=false
Categories=Medical;
EOF
    
    chown "$TARGET_USER:$TARGET_USER" "$program_dir/Запуск_MedOrg.desktop"
    chmod +x "$program_dir/Запуск_MedOrg.desktop"
    
    # Создаем скрипт помощи
    cat > "$program_dir/README.txt" << EOF
Медицинская информационная система MedOrg

Для запуска программ:
1. Войдите в систему как пользователь: $TARGET_USER
2. Дважды щелкните на нужном ярлыке

Если программы не запускаются, выполните в терминале:
  cd ~/.wine_medorg/drive_c/MedCTech/MedOrg/Lib
  wine *.exe

Каталог с программами: $TARGET_HOME/.wine_medorg/drive_c/MedCTech/MedOrg
EOF
    
    chown "$TARGET_USER:$TARGET_USER" "$program_dir/README.txt"
}

create_helper_shortcuts() {
    local program_dir="$1"
    
    # Создаем скрипт для исправления прав
    cat > "$program_dir/Исправить_права.sh" << EOF
#!/bin/bash
echo "Исправление прав доступа..."
chown -R $TARGET_USER:$TARGET_USER $TARGET_HOME/.wine_medorg
chmod -R 755 $TARGET_HOME/.wine_medorg
echo "Готово!"
read -p "Нажмите Enter для закрытия..."
EOF
    
    chown "$TARGET_USER:$TARGET_USER" "$program_dir/Исправить_права.sh"
    chmod +x "$program_dir/Исправить_права.sh"
    
    # Создаем скрипт для пересоздания Wine
    cat > "$program_dir/Переустановить_Wine.sh" << EOF
#!/bin/bash
echo "Переустановка Wine prefix..."
rm -rf $TARGET_HOME/.wine_medorg
export WINEARCH=win32
export WINEPREFIX=$TARGET_HOME/.wine_medorg
wineboot --init
echo "Готово! Можете установить компоненты через winetricks"
read -p "Нажмите Enter для закрытия..."
EOF
    
    chown "$TARGET_USER:$TARGET_USER" "$program_dir/Переустановить_Wine.sh"
    chmod +x "$program_dir/Переустановить_Wine.sh"
}

# Проверка переменных окружения
check_variables() {
    if [ -z "$TARGET_USER" ]; then
        error "Переменная TARGET_USER не установлена"
        exit 1
    fi
    
    if [ -z "$TARGET_HOME" ]; then
        error "Переменная TARGET_HOME не установлена"
        exit 1
    fi
    
    # Проверяем существование пользователя
    if ! id "$TARGET_USER" &>/dev/null; then
        error "Пользователь $TARGET_USER не существует"
        exit 1
    fi
}

# Основная функция
main() {
    check_variables
    create_shortcuts
}

# Запуск
main "$@"