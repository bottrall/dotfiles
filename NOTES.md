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

The case fan RGB is a static hot pink (`FF0080`, picked by eye: the theme's pinks wash out on these LEDs), turned off with the screen and back on with activity by hypridle. The fans' ARGB cable must be on the motherboard's `JRAINBOW` header (not the case's own controller), and it needs OpenRGB — its package ships the udev rules for hidraw access. hypridle's calls go through a user-level OpenRGB server (`.config/systemd/user/openrgb.service`, enabled by `install.sh`); leave the package's root `openrgb.service` disabled so the two don't fight over the controller:

```sh
sudo pacman -S openrgb
```

The board shows the mode saved on it whenever its controller resets — at boot and on every resume from suspend — and the factory one is rainbow. The OpenRGB CLI can't save, so once, with the server running, size the JRAINBOW zones (they default to 0 LEDs, and the controller ignores mode changes until sized; the server remembers the sizes), set the pink, and save it over the SDK:

```sh
openrgb --nodetect -d "MSI PRO B650M-P" -z 2 -sz 30 -d "MSI PRO B650M-P" -z 3 -sz 30 -d "MSI PRO B650M-P" -m static -c FF0080
uv run --no-project --with openrgb-python python -c 'from openrgb import OpenRGBClient; next(d for d in OpenRGBClient().devices if "B650M" in d.name).save_mode()'
```
