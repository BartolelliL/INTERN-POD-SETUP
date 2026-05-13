# IT INFRASTRUCTURE PROJECT

This project is a Linux-based script, that allows a corporation to reset a shared computer by copying all files and directory modification into a specific labeled-USB before resetting the machine.

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
