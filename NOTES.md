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

The case fan RGB is a static hot pink, set at login and by hypridle (off with the screen, fading back up with activity) via `.config/hypr/scripts/case-rgb.sh`. The fans' ARGB cable must be on the motherboard's `JRAINBOW` header (not the case's own controller), and it needs OpenRGB — its package ships the udev rules for hidraw access. The script goes through a user-level OpenRGB server (`.config/systemd/user/openrgb.service`, enabled by `install.sh`); leave the package's root `openrgb.service` disabled so the two don't fight over the controller:

```sh
sudo pacman -S openrgb
```
