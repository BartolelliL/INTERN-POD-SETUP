#!/usr/bin/env bash

# EXPECTED PATH: /usr/local/bin/usb_backup_reset.sh

set -Eeuo pipefail

LOG_FILE="/tmp/usb_test.log"
DEVICE="${1:-}"
USB_MOUNT="${2:-}"
SKIP_RESET="${SKIP_RESET:-no}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "SCRIPT STARTED"
log "PARAM DEVICE = ${DEVICE:-<empty>}"
log "PARAM USB_MOUNT = ${USB_MOUNT:-<empty>}"

if [[ -z "$DEVICE" ]]; then
    log "NO DEVICE PROVIDED"
    exit 1
fi

if [[ -z "$USB_MOUNT" ]]; then
    USB_MOUNT="$(findmnt -n -o TARGET --source "$DEVICE" | head -n1 || true)"
fi

if [[ -z "$USB_MOUNT" || ! -d "$USB_MOUNT" ]]; then
    log "INVALID OR MISSING USB_MOUNT"
    exit 1
fi

if [[ "$USB_MOUNT" == "/" ]]; then
    log "REFUSING TO USE ROOT AS DESTINATION"
    exit 1
fi

DEST_ROOT="${USB_MOUNT%/}/backup-$(hostname)-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST_ROOT"
log "DEST_ROOT = $DEST_ROOT"

# UID 1000-59999 targets standard local human users (excluding system/service accounts).
mapfile -t USERS < <(awk -F: '$3 >= 1000 && $3 < 60000 && $6 ~ /^\/home\// {print $1 ":" $6}' /etc/passwd)

if [[ "${#USERS[@]}" -eq 0 ]]; then
    log "NO /home USERS FOUND"
    exit 0
fi

for entry in "${USERS[@]}"; do
    USER_NAME="${entry%%:*}"
    USER_HOME="${entry#*:}"

    if [[ ! -d "$USER_HOME" ]]; then
        log "SKIP $USER_NAME (HOME NOT FOUND: $USER_HOME)"
        continue
    fi
    if [[ "$USER_HOME" != /home/* || "$USER_HOME" == "/home" ]]; then
        log "SKIP $USER_NAME (UNSAFE HOME PATH: $USER_HOME)"
        continue
    fi

    USER_DEST="$DEST_ROOT/$USER_NAME"
    mkdir -p "$USER_DEST"

    log "BACKUP START FOR $USER_NAME ($USER_HOME -> $USER_DEST)"
    set +e
    rsync -aHAX --numeric-ids --one-file-system "$USER_HOME/." "$USER_DEST/" >> "$LOG_FILE" 2>&1
    RSYNC_EXIT="$?"
    set -e

    if [[ "$RSYNC_EXIT" -eq 0 ]]; then
        log "BACKUP COMPLETE FOR $USER_NAME"
        if [[ "$SKIP_RESET" == "yes" ]]; then
            log "RESET SKIPPED FOR $USER_NAME (SKIP_RESET=yes)"
        else
            log "RESET START FOR $USER_NAME"
            find "$USER_HOME" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
            log "RESET COMPLETE FOR $USER_NAME"
        fi
    else
        log "BACKUP FAILED FOR $USER_NAME - RSYNC EXIT CODE=$RSYNC_EXIT - SKIPPING RESET"
    fi
done

sync
log "SCRIPT FINISHED"
