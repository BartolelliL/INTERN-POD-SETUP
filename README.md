# IT INFRASTRUCTURE PROJECT — Automatic USB Backup and User Reset

This solution allows a corporation or institution to automatically back up user files from *shared Linux computers* to a specific USB stick and then reset those files, ensuring privacy and easy onboarding for each new user.

## How Each Part Works

- **usb-backup.conf** — Customizes operation. Example content:
  ```
  EXPECTED_LABEL="4GB-PEN" // TODO: Modify this parameter accordingly
  ACTION_SCRIPT="/usr/local/bin/usb_backup_reset.sh"
  MOUNT_ROOT="/run/usb-backup"
  LEAVE_MOUNTED="no"
  ```

- **99-usb-backup.rules** — Tells the system to run the systemd service when a new USB drive is detected (with correct label).

- **usb-backup@.service** — systemd runs `usb_backup_reset.sh`, passing the USB device as parameter.

- **wrapper_usb.sh** — Handles mounting of the USB and executes the backup logic as specified.

- **usb_backup_reset.sh** — 
  1. Verifies the USB label.
  2. Mounts the USB (if needed).
  3. Detects the current user and key user folders.
  4. Uses `rsync` to copy folders (Desktop, Documents, Downloads, etc.) to the USB.
  5. If backup succeeds, those folders are then cleared and reset.
  6. Unmounts the USB and logs success/failure.

---

## Components & What They Do

| File                           | Purpose                                            | Predefined Path                      |
|---------------------------------|----------------------------------------------------|-----------------------------------|
| `usb_backup_reset.sh`           | Main backup & user folder reset logic              | `/usr/local/bin/usb_backup_reset.sh` |
| `wrapper_usb.sh`                | Handles mounting of the USB and starts scripts     | `/usr/local/bin/wrapper_usb.sh`   |
| `usb-backup@.service`           | systemd service: runs backup script for USB event  | `/etc/systemd/system/usb-backup@.service` |
| `99-usb-backup.rules`           | udev rule: triggers systemd service on USB insert  | `/etc/udev/rules.d/99-usb-backup.rules` |
| `usb-backup.conf`               | Configuration: label, scripts, mount options       | `/etc/usb-backup.conf`            |

---

## INSTRUCTIONS BEFORE USAGE

After moving the files into the wanted directories which are specified in the files themselves, in order to make the service work automatically, execute the following commands with sudo permissions:

```bash
cd ~
sudo chmod +x /usr/local/bin/usb_backup_reset.sh
sudo chmod +x /usr/local/bin/wrapper_usb.sh
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Troubleshooting

- **Logs**: See `/tmp/usb_test.log` for detailed information if things go wrong.
- **Permissions**: All scripts must be executable. If any script fails, re-check permissions and paths.
- **USB Label**: Ensure the USB device label matches the one in `usb-backup.conf`. Only then will the backup trigger.
