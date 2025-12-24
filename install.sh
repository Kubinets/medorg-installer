#!/bin/bash
# install.sh - СУПЕР ПРОСТОЙ установщик

set -e

echo "=== УСТАНОВКА MEDORG ==="

# Создаем пользователя если нет
if ! id "meduser" &>/dev/null; then
    echo "Создаем пользователя meduser..."
    useradd -m -s /bin/bash meduser
    echo "meduser:meduser" | chpasswd
fi

USER="meduser"
HOME_DIR="/home/meduser"
SELECTED_MODULES="WrachPol"

echo "Установка для пользователя: $USER"
echo "Модули: $SELECTED_MODULES"

# 1. Зависимости
echo "[1/5] Установка зависимостей..."
curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/01-dependencies.sh" | bash

# 2. Wine
echo "[2/5] Настройка Wine..."
TARGET_USER="$USER" TARGET_HOME="$HOME_DIR" bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/02-wine-setup.sh")

# 3. Копирование
echo "[3/5] Копирование файлов..."
TARGET_USER="$USER" TARGET_HOME="$HOME_DIR" SELECTED_MODULES="$SELECTED_MODULES" bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/03-copy-files.sh")

# 4. Midas
echo "[4/5] Исправление midas.dll..."
TARGET_USER="$USER" TARGET_HOME="$HOME_DIR" bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/04-fix-midas.sh")

# 5. Ярлыки
echo "[5/5] Создание ярлыков..."
TARGET_USER="$USER" TARGET_HOME="$HOME_DIR" bash <(curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/05-create-shortcuts.sh")

echo ""
echo "=== ГОТОВО! ==="
echo "Выполните:"
echo "  su - meduser"
echo "  cd /home/meduser"
echo "  ./final_fix_all.sh"