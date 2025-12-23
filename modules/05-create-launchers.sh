#!/bin/bash
# Создание ярлыков - суперпростая версия

echo "=== Создание ярлыков ==="

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_HOME" ]; then
    echo "Ошибка: переменные не установлены"
    exit 1
fi

USER="$TARGET_USER"
HOME="$TARGET_HOME"
DESKTOP="$HOME/Рабочий стол/Медицинские программы"

echo "Создаем директорию: $DESKTOP"
sudo -u "$USER" mkdir -p "$DESKTOP"

# Просто создаем ярлык для основного модуля
echo "Создаем базовые ярлыки..."

# Ярлык для Lib
cat > /tmp/lib.desktop << EOF
[Desktop Entry]
Name=MedOrg Lib
Exec=env WINEPREFIX="$HOME/.wine_medorg" WINEARCH=win32 wine "$HOME/.wine_medorg/drive_c/MedCTech/MedOrg/Lib/Lib.exe"
Icon=wine
Terminal=false
Type=Application
EOF

sudo mv /tmp/lib.desktop "$DESKTOP/Lib.desktop"
sudo chown "$USER:$USER" "$DESKTOP/Lib.desktop"
sudo chmod +x "$DESKTOP/Lib.desktop"

echo "Ярлык создан: $DESKTOP/Lib.desktop"
echo "Готово!"