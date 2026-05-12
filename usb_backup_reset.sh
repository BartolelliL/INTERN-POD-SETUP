#!/bin/bash

# EXPECTED PATH: /usr/local/bin/usb_backup_reset.sh

########################################
# LOGGING & INIT
########################################

echo "SCRIPT STARTED" >> /tmp/usb_test.log

touch /tmp/WORKS

set +e

########################################
# INPUT DEVICE (FROM UDEV / SYSTEMD-RUN)
########################################

DEVICE="$1"

echo "PARAM DEVICE = $DEVICE" >> /tmp/usb_test.log

if [ -z "$DEVICE" ]; then
    echo "NO DEVICE PROVIDED" >> /tmp/usb_test.log
    exit 1
fi

echo "DEVICE: $DEVICE" >> /tmp/usb_test.log

########################################
# LABEL DETECTION
########################################

LABEL=$(blkid -s LABEL -o value "$DEVICE")

echo "LABEL: $LABEL" >> /tmp/usb_test.log

# TARGET LABEL
TARGET_LABEL="4GB-PEN"

if [ "$LABEL" != "$TARGET_LABEL" ]; then
    echo "LABEL NOT MATCH - EXIT" >> /tmp/usb_test.log
    exit 0
fi

echo "LABEL MATCH - USB ACCEPTED" >> /tmp/usb_test.log

########################################
# MOUNT POINT RESOLUTION
########################################

#USB_MOUNT=""

#for i in {1..10}; do
#    USB_MOUNT=$(lsblk -no MOUNTPOINT "$DEVICE" | head -n 1)

#    if [ -n "$USB_MOUNT" ]; then
#       break
#    fi

#    sleep 1

#done

#echo "USB_MOUNT = $USB_MOUNT" >> /tmp/usb_test.log

#if [ -z "$USB_MOUNT" ]; then
#    echo "USB NOT MOUNTED" >> /tmp/usb_test.log
#    exit 1
#fi

#echo "MOUNT: $USB_MOUNT" >> /tmp/usb_test.log

PARTITION="${DEVICE}1"

echo "PARTITION: $PARTITION" >> /tmp/usb_test.log

# Waiting partition...

for i in {1..10}; do
    if [ -b "$PARTITION" ]; then 
        break
    fi

    echo "WAITING FOR PARTITION..." >> /tmp/usb_test.log
    sleep 1
done

if [ ! -b "$PARTITION" ]; then
    echo "PARTITION NOT FOUND" >> /tmp/usb_test.log
    exit 1
fi

MOUNT_POINT="/mnt/usb-backup"

mkdir -p "$MOUNT_POINT"

mount "$PARTITION" "$MOUNT_POINT" >> /tmp/usb_test.log 2>&1

if [ $? -ne 0 ]; then
    echo "MOUNT FAILED" >> /tmp/usb_test.log
    exit 1
fi

USB_MOUNT="$MOUNT_POINT"

echo "USB_MOUNT = $USB_MOUNT" >> /tmp/usb_test.log

########################################
# USER CONTEXT
########################################

########################################
# USER CONTEXT (FIXED FOR KUBUNTU)
########################################
# Trova l'utente reale che possiede la home (escludendo root)
USER_NAME=$(ls /home | grep -v "lost+found" | head -n 1)
USER_HOME="/home/$USER_NAME"

# Forza il mount point se udisks è lento
USB_MOUNT=$(lsblk -no MOUNTPOINT "$DEVICE" | head -n 1)

if [ -z "$USB_MOUNT" ]; then
    # Se Kubuntu non l'ha ancora montata, la montiamo noi manualmente in /mnt
    echo "MANUAL MOUNTING..." >> /tmp/usb_test.log
    mount "$DEVICE" /mnt
    USB_MOUNT="/mnt"
fi

########################################
# BACKUP PHASE
########################################

echo "BACKUP START" >> /tmp/usb_test.log

rsync -a \
    --exclude=".cache" \
    --exclude=".local/share/Trash" \
    --exclude=".local/state" \
    --exclude=".gvfs" \
    --exclude="node_modules" \
    --exclude="snap" \
    --exclude="*.sock" \
    --exclude="*.lock" \
    --exclude=".config/google-chrome/*" \
    --exclude=".config/BraveSoftware/*" \
    "$USER_HOME/" \
    "$DEST/" >> /tmp/usb_test.log 2>&1

echo "BACKUP COMPLETE" >> /tmp/usb_test.log

########################################
# SYNC TO DISK
########################################

sync
udevadm settle

########################################
# USB UNMOUNT (OPTIONAL SAFE STEP)
########################################

echo "UNMOUNTING USB" >> /tmp/usb_test.log

umount "$USB_MOUNT" >> /tmp/usb_test.log 2>&1

########################################
# USER DATA RESET (CRITICAL PHASE)
########################################

echo "RESET START" >> /tmp/usb_test.log

rm -rf "$USER_HOME/Desktop/"*
rm -rf "$USER_HOME/Documents/"*
rm -rf "$USER_HOME/Downloads/"*
rm -rf "$USER_HOME/Pictures/"*
rm -rf "$USER_HOME/Videos/"*
rm -rf "$USER_HOME/Music/"*

echo "RESET COMPLETE" >> /tmp/usb_test.log

########################################
# FINAL SYNC
########################################

sync

########################################
# END
########################################

echo "SCRIPT FINISHED" >> /tmp/usb_test.log
