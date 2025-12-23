#!/bin/bash
# Настройка Wine - максимально упрощенная версия

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} Начинаем настройку Wine..."

# Проверяем аргументы
if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
    echo -e "${RED}Ошибка: TARGET_USER и TARGET_HOME не установлены${NC}"
    exit 1
fi

USER="$TARGET_USER"
HOME_DIR="$TARGET_HOME"
WINE_PREFIX="$HOME_DIR/.wine_medorg"

echo -e "${BLUE}[INFO]${NC} Настройка для пользователя: $USER"
echo -e "${BLUE}[INFO]${NC} Домашняя директория: $HOME_DIR"

# 1. Проверяем, существует ли пользователь
if ! id "$USER" >/dev/null 2>&1; then
    echo -e "${RED}Ошибка: Пользователь $USER не существует${NC}"
    exit 1
fi

# 2. Проверяем установлен ли wine
if ! command -v wine >/dev/null 2>&1; then
    echo -e "${RED}Ошибка: Wine не установлен. Сначала установите зависимости.${NC}"
    exit 1
fi

# 3. Удаляем старый wine prefix, если есть
if [ -d "$WINE_PREFIX" ]; then
    echo -e "${BLUE}[INFO]${NC} Удаляем старый Wine prefix..."
    rm -rf "$WINE_PREFIX"
fi

# 4. Устанавливаем правильные права на домашнюю директорию
chown -R "$USER:$USER" "$HOME_DIR" 2>/dev/null || true

# 5. СОЗДАЕМ ОТДЕЛЬНЫЙ СКРИПТ ДЛЯ НАСТРОЙКИ WINE
# который будет запущен от имени пользователя
SCRIPT_PATH="/tmp/wine_setup_$$.sh"

cat > "$SCRIPT_PATH" << 'WINE_SCRIPT'
#!/bin/bash
set -e

USER="$1"
HOME_DIR="$2"
WINE_PREFIX="$HOME_DIR/.wine_medorg"

echo "Настройка Wine для пользователя: $USER"
echo "Wine prefix: $WINE_PREFIX"

# Экспортируем переменные окружения
export WINEARCH=win32
export WINEPREFIX="$WINE_PREFIX"
export WINEDEBUG=-all
export DISPLAY=:0
export HOME="$HOME_DIR"
export USER="$USER"

# Переходим в домашнюю директорию
cd "$HOME_DIR"

# Создаем wine prefix
echo "Создаем Wine prefix..."
timeout 60 wineboot --init 2>&1 | grep -v "fixme\|warn\|err" || true

# Ждем
sleep 3

# Проверяем, создался ли prefix
if [ -f "$WINE_PREFIX/system.reg" ]; then
    echo "Wine prefix успешно создан"
else
    echo "Предупреждение: Возможны проблемы с созданием Wine prefix"
fi

# Пытаемся установить компоненты (но не прерываемся при ошибках)
echo "Пытаемся установить компоненты..."

# Core Fonts
if command -v winetricks >/dev/null 2>&1; then
    echo "Устанавливаем corefonts..."
    winetricks -q corefonts 2>&1 | grep -v "fixme\|warn" || true
    sleep 1
    
    echo "Устанавливаем vcrun6..."
    winetricks -q vcrun6 2>&1 | grep -v "fixme\|warn" || true
    sleep 1
    
    echo "Устанавливаем mdac28..."
    winetricks -q mdac28 2>&1 | grep -v "fixme\|warn" || true
else
    echo "Winetricks не найден, пропускаем установку компонентов"
fi

echo "Базовая настройка Wine завершена"
WINE_SCRIPT

# Делаем скрипт исполняемым
chmod +x "$SCRIPT_PATH"

# 6. ЗАПУСКАЕМ СКРИПТ ОТ ИМЕНИ ПОЛЬЗОВАТЕЛЯ
echo -e "${BLUE}[INFO]${NC} Запускаем настройку Wine..."
if sudo -u "$USER" DISPLAY=:0 bash "$SCRIPT_PATH" "$USER" "$HOME_DIR"; then
    echo -e "${GREEN}✓${NC} Настройка Wine завершена успешно"
else
    echo -e "${RED}✗${NC} Были ошибки при настройке Wine"
    echo -e "${BLUE}[INFO]${NC} Продолжаем установку несмотря на ошибки Wine..."
fi

# 7. Устанавливаем права на wine prefix
if [ -d "$WINE_PREFIX" ]; then
    chown -R "$USER:$USER" "$WINE_PREFIX"
    echo -e "${GREEN}✓${NC} Wine prefix создан: $WINE_PREFIX"
else
    echo -e "${RED}✗${NC} Wine prefix не был создан"
fi

# 8. Очищаем временные файлы
rm -f "$SCRIPT_PATH"

# 9. СОЗДАЕМ СКРИПТ ДЛЯ РУЧНОЙ НАСТРОЙКИ WINE (на всякий случай)
FIX_SCRIPT="$HOME_DIR/fix_wine.sh"
cat > "$FIX_SCRIPT" << EOF
#!/bin/bash
# Ручная настройка Wine
echo "Ручная настройка Wine..."
echo "1. Удаляем старый Wine prefix..."
rm -rf ~/.wine_medorg
echo "2. Создаем новый Wine prefix..."
export WINEARCH=win32
export WINEPREFIX=~/.wine_medorg
wineboot --init
echo "3. Устанавливаем компоненты..."
winetricks -q corefonts vcrun6 mdac28
echo "Готово!"
EOF

chmod +x "$FIX_SCRIPT"
chown "$USER:$USER" "$FIX_SCRIPT"

echo -e "${GREEN}✓${NC} Создан скрипт для ручной настройки: $FIX_SCRIPT"
echo -e "${BLUE}[INFO]${NC} Если автоматическая настройка не сработала, запустите: sudo -u $USER $FIX_SCRIPT"