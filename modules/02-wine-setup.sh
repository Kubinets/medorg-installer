#!/bin/bash
# Настройка Wine - упрощенная версия

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
    echo -e "${RED}Ошибка: TARGET_USER и TARGET_HOME не установлены${NC}"
    exit 1
fi

USER="$TARGET_USER"
HOME_DIR="$TARGET_HOME"
WINE_PREFIX="$HOME_DIR/.wine_medorg"

log "Настройка Wine для пользователя $USER..."

# 1. Удаляем старый prefix, если есть
if [ -d "$WINE_PREFIX" ]; then
    log "Удаляем старый Wine prefix..."
    rm -rf "$WINE_PREFIX"
fi

# 2. Создаем директорию с правильными правами
mkdir -p "$WINE_PREFIX"
chown -R "$USER:$USER" "$WINE_PREFIX"

# 3. Создаем скрипт настройки
cat > /tmp/setup_wine.sh << 'EOF'
#!/bin/bash
USER="$1"
HOME_DIR="$2"
WINE_PREFIX="$HOME_DIR/.wine_medorg"

# Экспортируем переменные для Wine
export WINEARCH=win32
export WINEPREFIX="$WINE_PREFIX"
export WINEDEBUG=-all
export HOME="$HOME_DIR"

# Создаем Wine prefix
cd "$HOME_DIR"
wine wineboot --init 2>&1 | grep -v "fixme\|err" | tail -5

# Ждем
sleep 3

# Устанавливаем компоненты
echo "Устанавливаем corefonts..."
winetricks -q corefonts 2>&1 | grep -v "fixme" | tail -5

echo "Устанавливаем vcrun6..."
winetricks -q vcrun6 2>&1 | grep -v "fixme" | tail -5

echo "Устанавливаем mdac28..."
winetricks -q mdac28 2>&1 | grep -v "fixme" | tail -5

echo "Настройка завершена!"
EOF

chmod +x /tmp/setup_wine.sh

# 4. Запускаем от имени пользователя
log "Запускаем настройку Wine..."
sudo -u "$USER" /tmp/setup_wine.sh "$USER" "$HOME_DIR"

# 5. Проверяем результат
if [ -f "$WINE_PREFIX/system.reg" ]; then
    success "Wine успешно настроен!"
    success "Prefix: $WINE_PREFIX"
else
    log "Wine prefix создан, но возможны ошибки в настройке"
fi

# 6. Убираем временный файл
rm -f /tmp/setup_wine.sh