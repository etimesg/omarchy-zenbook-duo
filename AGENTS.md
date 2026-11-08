# AGENTS.md

This repository ships **one thing**: the DKMS package that patches `hid-asus`
for the **ASUS Zenbook Duo (UX8406MA)** detachable keyboard.

The desktop configuration that used to live here (`home/`, `setup.sh`) moved to
[locomarchy](https://github.com/etimesg/locomarchy), whose `zenbook-duo` feature
owns the monitor layout, the dock watcher, and the workspace sync. Those files
remain here for history only and are not maintained. `setup.sh` refuses to run
while locomarchy's managed blocks are present, because copying the old files
over them would replace the dock watcher and the monitor layout.

## Hardware

The Duo has two internal panels:

| Output | Panel        | Where it sits                 |
|--------|--------------|-------------------------------|
| `eDP-1`| Main display | Top (2880x1800, scale 1.6)    |
| `eDP-2`| Base display | Bottom (2880x1800, scale 1.6) |

The keyboard is detachable. It connects over a **pogo-pin USB bridge** (vendor
`0b05`, product `1b2c`) when docked over the base screen, and falls back to
**Bluetooth** (`0b05:1b2d`) when lifted off. USB presence is the dock sensor.

## Before changing anything

Everything here is a workaround. First check whether it is still needed:

- **Kernel / HID:** is Zenbook Duo support merged upstream yet? Look for a
  `QUIRK_ZENBOOK_DUO*` quirk or a `UX8406MA`/`UX8406CA` device entry in
  `drivers/hid/hid-asus.c` and `drivers/hid/hid-ids.h`. As of kernel 7.2.15
  (checked against `v7.2` and `master`) there are none, so the package is still
  required. If it lands upstream, delete `pkg/hid-asus-zenbook-duo-dkms/`
  rather than extending it.
- **Desktop behaviour:** monitor stacking, dock detection, and workspace
  synchronization are locomarchy's problem now, not this repo's.
- Prefer deleting a workaround over adding to it. Record what you checked.

## File layout

- `pkg/hid-asus-zenbook-duo-dkms/` — the maintained part: patched `hid-asus`
  source, `PKGBUILD`, `dkms.conf`, and the `.install` script.
- `home/`, `setup.sh` — legacy, superseded by locomarchy. Do not extend.

## Build and install

```bash
cd pkg/hid-asus-zenbook-duo-dkms
makepkg -f                 # needs dkms + linux-omarchy-headers on Omarchy
sudo pacman -U hid-asus-zenbook-duo-dkms-0.1.0-2-x86_64.pkg.tar.zst
```

The `.install` script runs `dkms add/build/install` for the running kernel and
reloads the module. DKMS rebuilds it on kernel upgrades, so a reinstall is not
needed after each update.

## Verify

```bash
dkms status                      # hid-asus-zenbook-duo/0.1.0, <kernel>: installed
lsmod | grep hid_asus            # loaded
modinfo -n hid_asus              # must resolve under updates/dkms, not kernel/
journalctl -k | grep -i asus     # "Fixing up ZENBOOK DUO keyb report descriptor"
                                 # and no "handshake ... failed to send"
```

The in-tree `hid-asus.ko` has no Zenbook strings, so a path outside
`updates/dkms` means the patched module is not the one loaded.

## Legacy notes worth keeping

These only matter if you deliberately revive `home/`:

- **Hyprland 0.56 uses the Lua config parser.** `hyprctl keyword monitor …` is
  rejected; monitor changes must go through `hyprctl eval` with `hl.monitor`.
- **Read USB vendor/product with `cat`, not `$(<file 2>/dev/null)`.** The
  redirection disables bash's fast-read and returns an empty string.
- Re-enabling a monitor needs `disabled = false` explicitly.
- Validate any Hyprland config change with `hyprctl reload && hyprctl configerrors`
  before committing.

## Committing

Keep `PKGBUILD`/`dkms.conf` versions in step, rebuild the package, and confirm
`dkms status` plus the dmesg lines above on the running kernel. Do not commit
built `.pkg.tar.zst` artifacts unless the release process explicitly calls for
it.
