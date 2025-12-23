#!/bin/bash
# Исправление midas.dll

fix_midas() {
    local user="$1"
    local home="$(getent passwd "$user" | cut -d: -f6)"
    
    echo "Исправление midas.dll..."
    
    # Пути
    LIB_DIR="$home/.wine_medorg/drive_c/MedCTech/MedOrg/Lib"
    SYSTEM32="$home/.wine_medorg/drive_c/windows/system32"
    
    # Создаем ссылки для регистра
    if [ -f "$LIB_DIR/midas.dll" ]; then
        cd "$LIB_DIR"
        ln -sf midas.dll MIDAS.DLL
        ln -sf midas.dll Midas.dll
    fi
    
    # В system32
    cp -f "$LIB_DIR/midas.dll" "$SYSTEM32/" 2>/dev/null
    cd "$SYSTEM32"
    ln -sf midas.dll MIDAS.DLL 2>/dev/null
    ln -sf midas.dll Midas.dll 2>/dev/null
    
    # Реестр
    sudo -u "$user" env WINEPREFIX="$home/.wine_medorg" bash << 'EOF'
cat > /tmp/midas.reg << 'REGEOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"
REGEOF

wine regedit /tmp/midas.reg 2>/dev/null
EOF
    
    echo "midas.dll исправлена"
}

if [ $# -eq 1 ]; then
    fix_midas "$1"
fi