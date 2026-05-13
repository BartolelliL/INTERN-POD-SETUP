#!/usr/bin/env bash

# EXPECTED PATH: /usr/local/bin/wrapper_usb.sh
# Lightweight entrypoint triggered by USB events.
# It validates the USB label, mounts the device if needed,
# and delegates the real work to ACTION_SCRIPT from config.

set -Eeuo pipefail

# Load configurable values (expected label, script path, mount root, etc.).
source /etc/usb-backup.conf

DEVICE="$1"

mounted_here=0
mount_point=""

log() {
    logger "[usb-backup] $1"
    echo "[usb-backup] $1"
}

cleanup() {
    # Always run at exit to reduce risk of data loss and stale mounts.
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

# Ignore unknown USB devices and exit cleanly.
if [[ "$LABEL" != "$EXPECTED_LABEL" ]]; then
    log "LABEL errata: $LABEL"
    exit 0
fi

# If already mounted, reuse it; otherwise mount under MOUNT_ROOT.
mount_point=$(findmnt -n -o TARGET --source "$DEVICE" | head -n1 || true)

if [[ -z "$mount_point" ]]; then
    mkdir -p "$MOUNT_ROOT"

    mount_point="$MOUNT_ROOT/${DEVICE##*/}"

    mkdir -p "$mount_point"

    mount "$DEVICE" "$mount_point"

    mounted_here=1
fi

log "USB corretta rilevata"

# Execute the configured action script with device + mount point.
"$ACTION_SCRIPT" "$DEVICE" "$mount_point"

log "Script completato"
