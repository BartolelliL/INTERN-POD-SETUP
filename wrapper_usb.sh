#!/usr/bin/env bash

# EXPECTED PATH: /usr/local/bin/wrapper_usb.sh

set -Eeuo pipefail

source /etc/usb-backup.conf

DEVICE="$1"

mounted_here=0
mount_point=""

log() {
    logger "[usb-backup] $1"
    echo "[usb-backup] $1"
}

cleanup() {
    if [[ $mounted_here -eq 1 ]]; then
        sync

        if [[ "$LEAVE_MOUNTED" != "yes" ]]; then
            umount "$mount_point" || true
            rmdir "$mount_point" || true
        fi
    fi
}

trap cleanup EXIT

LABEL=$(blkid -o value -s LABEL "$DEVICE" 2>/dev/null || true)

if [[ "$LABEL" != "$EXPECTED_LABEL" ]]; then
    log "LABEL errata: $LABEL"
    exit 0
fi

mount_point=$(findmnt -n -o TARGET --source "$DEVICE" | head -n1 || true)

if [[ -z "$mount_point" ]]; then
    mkdir -p "$MOUNT_ROOT"

    mount_point="$MOUNT_ROOT/${DEVICE##*/}"

    mkdir -p "$mount_point"

    mount "$DEVICE" "$mount_point"

    mounted_here=1
fi

log "USB corretta rilevata"

"$ACTION_SCRIPT" "$DEVICE" "$mount_point"

log "Script completato"
