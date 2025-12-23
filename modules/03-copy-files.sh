#!/bin/bash
# Копирование программы

log() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m✓\033[0m $1"; }
warning() { echo -e "\033[1;33m!\033[0m $1"; }

copy_files() {
    log "Подключение к сетевой шаре..."
    
    MNT="/tmp/medorg_mount"
    mkdir -p "$MNT"
    
    if mount -t cifs //10.0.1.11/auto "$MNT" -o username=Администратор,password=Ybyjxrf30lh* 2>/dev/null; then
        log "Сетевая шара подключена"
        
        # Копируем обязательные папки
        for folder in "${REQUIRED[@]}"; do
            if [ -d "$MNT/$folder" ]; then
                cp -r "$MNT/$folder" "$TARGET_DIR/"
                log "  ✓ $folder"
            else
                warning "  ✗ $folder не найдена"
            fi
        done
        
        # Копируем выбранные модули
        if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            for folder in "${SELECTED_MODULES[@]}"; do
                if [ -d "$MNT/$folder" ]; then
                    cp -r "$MNT/$folder" "$TARGET_DIR/"
                    log "  ✓ $folder"
                else
                    warning "  ✗ $folder не найдена"
                fi
            done
        fi
        
        # Копируем общие файлы
        if [ -f "$MNT/midasregMedOrg.cmd" ]; then
            cp "$MNT/midasregMedOrg.cmd" "$TARGET_DIR/"
        fi
        
        umount "$MNT"
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.wine_medorg"
        
        success "Файлы скопированы"
    else
        warning "Не удалось подключиться к сетевой шаре"
    fi
}

# Проверяем переменные
if [ -n "$TARGET_USER" ] && [ -n "$TARGET_HOME" ]; then
    TARGET_DIR="$TARGET_HOME/.wine_medorg/drive_c/MedCTech/MedOrg"
    mkdir -p "$TARGET_DIR"
    copy_files
fi