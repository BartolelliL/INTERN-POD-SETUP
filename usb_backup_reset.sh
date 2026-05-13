#!/bin/bash

LOG="/tmp/usb_test.log"

log() {
    echo "$1" >> "$LOG"
}

log "==================="
log "SCRIPT STARTED"

DEVICE="$1"
MOUNT_POINT_ARG="${2:-}"

log "PARAM DEVICE = $DEVICE"

if [ -n "$MOUNT_POINT_ARG" ]; then
    log "PARAM MOUNT POINT = $MOUNT_POINT_ARG"
fi

PARTITION="$DEVICE"

log "PARTITION = $PARTITION"

########################################
# LABEL DETECTION
########################################

LABEL=$(blkid -s LABEL -o value "$PARTITION" 2>/dev/null)

log "LABEL = $LABEL"

TARGET_LABEL="4GB-PEN"

if [ "$LABEL" != "$TARGET_LABEL" ]; then
    log "LABEL NOT MATCH"
    exit 0
fi

log "LABEL MATCH"

########################################
# WAIT BEFORE MOUNT
########################################

log "WAIT BEFORE MOUNT..."

sleep 5

########################################
# MOUNT
########################################

MOUNT_POINT=""
mounted_here=0

existing_mount=$(findmnt -n -o TARGET --source "$PARTITION" 2>/dev/null | head -n1 || true)

if [ -n "$existing_mount" ]; then
    MOUNT_POINT="$existing_mount"
    if [ -n "$MOUNT_POINT_ARG" ] && [ "$MOUNT_POINT_ARG" != "$existing_mount" ]; then
        log "MOUNT POINT OVERRIDE IGNORED: $MOUNT_POINT_ARG"
    fi
    log "DEVICE ALREADY MOUNTED AT $existing_mount"
else
    MOUNT_POINT="${MOUNT_POINT_ARG:-/mnt/usb-backup}"
    mkdir -p "$MOUNT_POINT"

    mount -o rw "$PARTITION" "$MOUNT_POINT" >> "$LOG" 2>&1

    if [ $? -ne 0 ]; then
        log "MOUNT FAILED"
        exit 1
    fi

    mounted_here=1
fi

log "MOUNT OK: $MOUNT_POINT"

########################################
# DETECT REAL USER
########################################

detect_real_user() {
    local user=""

    if command -v loginctl >/dev/null 2>&1; then
        while read -r session; do
            [ -z "$session" ] && continue

            local active class type remote name
            active=$(loginctl show-session "$session" -p Active --value 2>/dev/null || true)
            class=$(loginctl show-session "$session" -p Class --value 2>/dev/null || true)
            type=$(loginctl show-session "$session" -p Type --value 2>/dev/null || true)
            remote=$(loginctl show-session "$session" -p Remote --value 2>/dev/null || true)
            name=$(loginctl show-session "$session" -p Name --value 2>/dev/null || true)

            if [ "$active" = "yes" ] && [ "$class" = "user" ] && [ "$remote" = "no" ]; then
                if [ "$type" = "wayland" ] || [ "$type" = "x11" ] || [ -z "$type" ]; then
                    user="$name"
                    break
                fi
            fi
        done < <(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}')
    fi

    if [ -z "$user" ]; then
        user=$(who | awk 'NR==1{print $1}')
    fi

    if [ -z "$user" ]; then
        user=$(getent passwd | awk -F: '$3>=1000 && $6 ~ /^\/home\// {print $1; exit}')
    fi

    echo "$user"
}

REAL_USER=$(detect_real_user)

if [ -z "$REAL_USER" ]; then
    log "USER NOT FOUND"
    if [ "$mounted_here" -eq 1 ]; then
        umount "$MOUNT_POINT"
    fi
    exit 1
fi

log "REAL USER = $REAL_USER"

USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [ -z "$USER_HOME" ]; then
    USER_HOME="/home/$REAL_USER"
fi

log "USER HOME = $USER_HOME"

if [ ! -d "$USER_HOME" ]; then
    log "USER HOME NOT FOUND"
    if [ "$mounted_here" -eq 1 ]; then
        umount "$MOUNT_POINT"
    fi
    exit 1
fi

########################################
# BACKUP FOLDER
########################################

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

BACKUP_FOLDER="$MOUNT_POINT/${REAL_USER}_backup_${TIMESTAMP}"

mkdir -p "$BACKUP_FOLDER"

log "BACKUP FOLDER = $BACKUP_FOLDER"

########################################
# RSYNC BACKUP
########################################

get_xdg_dir() {
    local key="$1"
    local fallback="$2"
    local config="$USER_HOME/.config/user-dirs.dirs"
    local value=""

    if [ -f "$config" ]; then
        value=$(grep -E "^${key}=" "$config" | tail -n1 | cut -d= -f2- | tr -d '"')
        value=${value/\$HOME/$USER_HOME}
        value=${value/#\~/$USER_HOME}
    fi

    if [ -z "$value" ]; then
        value="$USER_HOME/$fallback"
    fi

    echo "$value"
}

declare -a USER_DIRS=()
declare -A seen_dirs=()

add_user_dir() {
    local dir="$1"
    if [ -n "$dir" ] && [ -z "${seen_dirs[$dir]+set}" ]; then
        USER_DIRS+=("$dir")
        seen_dirs["$dir"]=1
    fi
}

add_user_dir "$(get_xdg_dir XDG_DESKTOP_DIR Desktop)"
add_user_dir "$(get_xdg_dir XDG_DOCUMENTS_DIR Documents)"
add_user_dir "$(get_xdg_dir XDG_DOWNLOAD_DIR Downloads)"
add_user_dir "$(get_xdg_dir XDG_PICTURES_DIR Pictures)"
add_user_dir "$(get_xdg_dir XDG_VIDEOS_DIR Videos)"
add_user_dir "$(get_xdg_dir XDG_MUSIC_DIR Music)"
add_user_dir "$(get_xdg_dir XDG_PUBLICSHARE_DIR Public)"
add_user_dir "$(get_xdg_dir XDG_TEMPLATES_DIR Templates)"

log "BACKUP START"

backup_ok=1

RSYNC_FLAGS=(
    -a
    --no-owner
    --no-group
    --no-perms
    --no-acls
    --no-xattrs
)

for dir in "${USER_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        name=$(basename "$dir")
        rsync "${RSYNC_FLAGS[@]}" "$dir/" "$BACKUP_FOLDER/$name/" >> "$LOG" 2>&1
        if [ $? -ne 0 ]; then
            log "RSYNC FAILED: $dir"
            backup_ok=0
        fi
    else
        log "SKIP MISSING DIR: $dir"
    fi
done

log "BACKUP COMPLETE"

########################################
# FLUSH TO USB
########################################

sync

log "SYNC COMPLETE"

########################################
# RESET USER FILES
########################################

if [ "$backup_ok" -ne 1 ]; then
    log "BACKUP FAILED - RESET SKIPPED"
    if [ "$mounted_here" -eq 1 ]; then
        umount "$MOUNT_POINT" >> "$LOG" 2>&1
    fi
    exit 1
fi

log "RESET START"

clear_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        return
    fi

    local dotglob_state=0
    local nullglob_state=0

    shopt -q dotglob && dotglob_state=1
    shopt -q nullglob && nullglob_state=1

    shopt -s dotglob nullglob
    rm -rf "$dir"/* >> "$LOG" 2>&1

    if [ "$dotglob_state" -eq 0 ]; then
        shopt -u dotglob
    fi

    if [ "$nullglob_state" -eq 0 ]; then
        shopt -u nullglob
    fi
}

for dir in "${USER_DIRS[@]}"; do
    clear_dir "$dir"
done

log "RESET COMPLETE"

########################################
# FINAL SYNC
########################################

sync

########################################
# UNMOUNT
########################################

if [ "$mounted_here" -eq 1 ]; then
    umount "$MOUNT_POINT" >> "$LOG" 2>&1
    log "UNMOUNT OK"
fi

########################################
# END
########################################

log "SCRIPT FINISHED"
