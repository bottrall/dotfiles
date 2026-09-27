# Notes

Setup reminders and workarounds.

## Arch

Steam desktop needs the following:

```toml
Exec=env DRI_PRIME=0 steam
```

hypridle dims the monitor over DDC/CI, which needs `ddcutil` and the `i2c-dev` kernel module (the ddcutil package's udev `uaccess` rule grants the logged-in user access to the i2c buses — no `i2c` group needed):

```sh
sudo pacman -S ddcutil
echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf
sudo modprobe i2c-dev
```
