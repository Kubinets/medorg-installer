#!/bin/bash
# install_fixed.sh - РАБОЧИЙ установщик

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== УСТАНОВЩИК MEDORG (ИСПРАВЛЕННЫЙ) ===${NC}"

# Получаем пользователя и модули
if [ -z "$1" ]; then
    read -p "Имя пользователя для установки [meduser]: " USER
    USER=${USER:-meduser}
else
    USER="$1"
fi

if [ -z "$2" ]; then
    echo "Доступные модули:"
    echo "  all - все модули"
    echo "  none - только обязательные"
    echo "  или список модулей через запятую: Admin,BolList,DayStac"
    read -p "Выберите модули [none]: " MODULES_INPUT
    if [ "$MODULES_INPUT" = "all" ]; then
        SELECTED_MODULES="Admin BolList DayStac Dispanser DopDisp Econ EconRA EconRost Fluoro Kiosk KTFOMSAgentDisp KTFOMSAgentGosp KTFOMSAgentPolis KTFOMSAgentReg KubNaprAgent MainSestStac MedOsm MISAgent OtdelStac Pokoy RegPeople RegPol San SanDoc SpravkaOMS StatPol StatStac StatYear Tablo Talon Vedom VistaAgent WrachPol"
    elif [ "$MODULES_INPUT" = "none" ]; then
        SELECTED_MODULES=""
    else
        # Конвертируем запятые в пробелы
        SELECTED_MODULES=$(echo "$MODULES_INPUT" | tr ',' ' ')
    fi
else
    SELECTED_MODULES=$(echo "$2" | tr ',' ' ')
fi

HOME_DIR=$(getent passwd "$USER" | cut -d: -f6)

echo ""
echo -e "${GREEN}Настройки установки:${NC}"
echo "  Пользователь: $USER"
echo "  Домашняя директория: $HOME_DIR"
echo "  Выбранные модули: $SELECTED_MODULES"
echo ""

read -p "Начать установку? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Установка отменена"
    exit 0
fi

# 1. Зависимости
echo -e "${YELLOW}[1/5] Установка зависимостей...${NC}"
curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/01-dependencies.sh" | bash

# 2. Wine
echo -e "${YELLOW}[2/5] Настройка Wine...${NC}"
export TARGET_USER="$USER"
export TARGET_HOME="$HOME_DIR"
curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/02-wine-setup.sh" | bash

# 3. Копирование файлов
echo -e "${YELLOW}[3/5] Копирование файлов...${NC}"
export TARGET_USER="$USER"
export TARGET_HOME="$HOME_DIR"
export SELECTED_MODULES="$SELECTED_MODULES"
curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/03-copy-files.sh" | bash

# 4. Midas.dll
echo -e "${YELLOW}[4/5] Исправление midas.dll...${NC}"
export TARGET_USER="$USER"
export TARGET_HOME="$HOME_DIR"
curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/04-fix-midas.sh" | bash

# 5. Ярлыки
echo -e "${YELLOW}[5/5] Создание ярлыков...${NC}"
export TARGET_USER="$USER"
export TARGET_HOME="$HOME_DIR"
curl -s "https://raw.githubusercontent.com/kubinets/medorg-installer/main/modules/05-create-shortcuts.sh" | bash

# Финальный фикс
echo -e "${GREEN}Создание финального фикс-скрипта...${NC}"
cat > "$HOME_DIR/final_fix_all.sh" << 'EOF'
#!/bin/bash
export WINEPREFIX="$HOME/.wine_medorg"

echo "=== ФИНАЛЬНЫЙ ФИКС ==="
cd "$WINEPREFIX/drive_c/MedCTech/MedOrg/Lib"
ln -sf midas.dll MIDAS.DLL 2>/dev/null
ln -sf midas.dll Midas.dll 2>/dev/null
ln -sf midas.dll midas.DLL 2>/dev/null
cp -f midas.dll "$WINEPREFIX/drive_c/windows/system32/" 2>/dev/null

echo "Готово! Запускайте программы через ярлыки."
EOF

chmod +x "$HOME_DIR/final_fix_all.sh"
chown "$USER:$USER" "$HOME_DIR/final_fix_all.sh"

echo ""
echo -e "${GREEN}=== УСТАНОВКА ЗАВЕРШЕНА! ===${NC}"
echo "Войдите как пользователь $USER и выполните:"
echo "  cd /home/$USER"
echo "  ./final_fix_all.sh"
echo ""