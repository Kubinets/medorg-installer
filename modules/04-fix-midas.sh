#!/bin/bash
# Исправление midas.dll

log() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m✓\033[0m $1"; }

fix_midas() {
    log "Исправление midas.dll..."
    
    LIB_DIR="$TARGET_HOME/.wine_medorg/drive_c/MedCTech/MedOrg/Lib"
    
    if [ -f "$LIB_DIR/midas.dll" ]; then
        # Ссылки для регистра
        cd "$LIB_DIR"
        ln -sf midas.dll MIDAS.DLL
        ln -sf midas.dll Midas.dll
        ln -sf midas.dll midas.DLL
        
        # Реестр
        sudo -u "$TARGET_USER" env WINEPREFIX="$TARGET_HOME/.wine_medorg" bash << 'EOF'
cat > /tmp/midas_fix.reg << 'REGEOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Borland\Database Engine]
"DLLPATH"="C:\\MedCTech\\MedOrg\\Lib"

[HKEY_LOCAL_MACHINE\Software\Borland\BLW32]
"BLAPIPATH"="C:\\MedCTech\\MedOrg\\Lib"
REGEOF

wine regedit /tmp/midas_fix.reg 2>/dev/null
EOF
        
        success "midas.dll исправлена"
    else
        log "midas.dll не найдена"
    fi
}

if [ -n "$TARGET_USER" ] && [ -n "$TARGET_HOME" ]; then
    fix_midas
fi