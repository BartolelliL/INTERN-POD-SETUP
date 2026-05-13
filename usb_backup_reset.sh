#!/bin/bash

LOG="/tmp/usb_test.log"

echo "===================" >> "$LOG"
echo "SCRIPT STARTED" >> "$LOG"

DEVICE="$1"

echo "PARAM DEVICE = $DEVICE" >> "$LOG"

PARTITION="$DEVICE"

echo "PARTITION = $PARTITION" >> "$LOG"

########################################
# LABEL DETECTION
########################################

LABEL=$(blkid -s LABEL -o value "$PARTITION" 2>/dev/null)

echo "LABEL = $LABEL" >> "$LOG"

TARGET_LABEL="4GB-PEN"

if [ "$LABEL" != "$TARGET_LABEL" ]; then
    echo "LABEL NOT MATCH" >> "$LOG"
    exit 0
fi

echo "LABEL MATCH" >> "$LOG"

########################################
# WAIT BEFORE MOUNT
########################################

echo "WAIT BEFORE MOUNT..." >> "$LOG"

sleep 5

########################################
# MOUNT
########################################

MOUNT_POINT="/mnt/usb-backup"

mkdir -p "$MOUNT_POINT"

mount -o rw "$PARTITION" "$MOUNT_POINT" >> "$LOG" 2>&1

if [ $? -ne 0 ]; then
    echo "MOUNT FAILED" >> "$LOG"
    exit 1
fi

echo "MOUNT OK" >> "$LOG"

########################################
# DETECT REAL USER
########################################

REAL_USER=$(who | awk 'NR==1{print $1}')

if [ -z "$REAL_USER" ]; then
    echo "USER NOT FOUND" >> "$LOG"
    umount "$MOUNT_POINT"
    exit 1
fi

echo "REAL USER = $REAL_USER" >> "$LOG"

USER_HOME="/home/$REAL_USER"

echo "USER HOME = $USER_HOME" >> "$LOG"

########################################
# BACKUP FOLDER
########################################

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

BACKUP_FOLDER="$MOUNT_POINT/${REAL_USER}_backup_${TIMESTAMP}"

mkdir -p "$BACKUP_FOLDER"

echo "BACKUP FOLDER = $BACKUP_FOLDER" >> "$LOG"

########################################
# RSYNC BACKUP
########################################

echo "BACKUP START" >> "$LOG"

rsync -a \
    --exclude=".cache" \
    --exclude=".local/share/Trash" \
    --exclude=".gvfs" \
    --exclude="node_modules" \
    --exclude="snap" \
    --exclude="*.sock" \
    --exclude="*.lock" \
    "$USER_HOME/Desktop/" \
    "$BACKUP_FOLDER/Desktop/" >> "$LOG" 2>&1

rsync -a \
    "$USER_HOME/Documents/" \
    "$BACKUP_FOLDER/Documents/" >> "$LOG" 2>&1

rsync -a \
    "$USER_HOME/Downloads/" \
    "$BACKUP_FOLDER/Downloads/" >> "$LOG" 2>&1

rsync -a \
    "$USER_HOME/Pictures/" \
    "$BACKUP_FOLDER/Pictures/" >> "$LOG" 2>&1

rsync -a \
    "$USER_HOME/Videos/" \
    "$BACKUP_FOLDER/Videos/" >> "$LOG" 2>&1

rsync -a \
    "$USER_HOME/Music/" \
    "$BACKUP_FOLDER/Music/" >> "$LOG" 2>&1

echo "BACKUP COMPLETE" >> "$LOG"

########################################
# FLUSH TO USB
########################################

sync

echo "SYNC COMPLETE" >> "$LOG"

########################################
# RESET USER FILES
########################################

echo "RESET START" >> "$LOG"

rm -rf "$USER_HOME/Desktop/"*
rm -rf "$USER_HOME/Documents/"*
rm -rf "$USER_HOME/Downloads/"*
rm -rf "$USER_HOME/Pictures/"*
rm -rf "$USER_HOME/Videos/"*
rm -rf "$USER_HOME/Music/"*

echo "RESET COMPLETE" >> "$LOG"

########################################
# FINAL SYNC
########################################

sync

########################################
# UNMOUNT
########################################

umount "$MOUNT_POINT" >> "$LOG" 2>&1

echo "UNMOUNT OK" >> "$LOG"

########################################
# END
########################################

echo "SCRIPT FINISHED" >> "$LOG"
