#!/usr/bin/env bash

# EXPECTED PATH: /usr/local/bin/usb_backup_reset.sh

set -Eeuo pipefail

LOG_FILE="/tmp/usb_test.log"
DEVICE="${1:-}"
USB_MOUNT="${2:-}"

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

    USER_DEST="$DEST_ROOT/$USER_NAME"
    mkdir -p "$USER_DEST"

    log "BACKUP START FOR $USER_NAME ($USER_HOME -> $USER_DEST)"
    if rsync -aHAX --numeric-ids --one-file-system "$USER_HOME/." "$USER_DEST/" >> "$LOG_FILE" 2>&1; then
        log "BACKUP COMPLETE FOR $USER_NAME"
        log "RESET START FOR $USER_NAME"
        find "$USER_HOME" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
        log "RESET COMPLETE FOR $USER_NAME"
    else
        log "BACKUP FAILED FOR $USER_NAME - SKIPPING RESET"
    fi
done

sync
log "SCRIPT FINISHED"
