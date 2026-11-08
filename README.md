# omarchy-zenbook-duo

The **DKMS-packaged patched `hid-asus` driver** that makes the ASUS Zenbook Duo
UX8406MA detachable keyboard's Fn hotkeys and backlight work under Linux.

> **The desktop configuration moved to
> [locomarchy](https://github.com/etimesg/locomarchy).** `home/` and `setup.sh`
> are kept for history only. They are not installed and not maintained, and
> `setup.sh` now refuses to run while locomarchy's Duo blocks are present —
> it would overwrite them with older copies. Use locomarchy's `zenbook-duo`
> feature for the monitor layout, dock watcher, and workspace sync.

## Contents

- `pkg/hid-asus-zenbook-duo-dkms/` — the patched `hid-asus` kernel module as an
  Arch package (DKMS), described below. **This is the part to install.**
- `home/`, `setup.sh` — legacy Omarchy config from before locomarchy; not
  installed, not maintained.

## Why a patched kernel module?

The Duo's keyboard is a standard HID keyboard for typing, but its **hotkeys**
(Fn+F2 brightness, Fn+F5, media keys, backlight, …) live on a separate
vendor-specific USB interface (the keyboard reports these keys on an ASUS
vendor usage page, `0xff31`). Upstream `hid-asus` doesn't know this keyboard
yet, so without the patch:

- the vendor hotkey interface is ignored (Fn combos do nothing),
- the keyboard backlight LED is never registered.

The module in this repo is built from the upstream linux-input patch series
**"ASUS Zenbook Duo keyboard support"** (May 2026), plus a backport of the
**Aug 11 2026** follow-up fix that re-sends the `0x5a` "ASUS Tech.Inc."
handshake after probe (see [Attribution](#attribution)).

## Installation

The package is a normal Arch package. It installs the module source under
`/usr/src`, and an `.install` script registers it with **DKMS**, builds it for
the running kernel, and loads it. Because of DKMS it survives kernel upgrades
(after a reboot you get the module automatically; no need to re-install).

```bash
cd pkg/hid-asus-zenbook-duo-dkms
makepkg -f                 # build the package (needs dkms and kernel headers;
                           # on Omarchy: linux-omarchy-headers)
sudo pacman -U hid-asus-zenbook-duo-dkms-0.1.0-2-x86_64.pkg.tar.zst
```

That's it. The `.install` script handles `dkms add/build/install` and reloads
the module so hotkeys work immediately. After a kernel upgrade, reboot and the
module is built and loaded by DKMS automatically.

### Verification

After installation (or a reboot):

```bash
dkms status                      # should list hid-asus-zenbook-duo/0.1.0, <kernel>, x86_64: installed
lsmod | grep hid_asus            # module loaded
sudo dmesg | grep -i asus        # look for "Fixing up ZENBOOK DUO keyb report descriptor"
                                 #   and no "Asus handshake ... failed to send"
ls /sys/class/leds/asus::kbd_backlight  # keyboard backlight LED (from asus-nb-wmi)
```

Then press **Fn+F2** / **Fn+F1** (brightness) — a brightness OSD should appear
and the keyboard backlight (Fn+A) should cycle.

If Fn combos still don't work, the handshake probably failed. Check:

```bash
sudo dmesg | grep -i "handshake\|re-init"
```

It should log neither. If it logs `Asus handshake 5a failed to send`, see
[Downgrade / troubleshooting](#downgrade--troubleshooting).

### Upgrading the package

`pkgrel` is bumped for a new build; run `makepkg -f` then `sudo pacman -U`
again. The install script rebuilds the DKMS module and reloads it.

## How the driver patch works

Two things had to be fixed in `hid-asus`:

1. **The vendor hotkey interface must be turned into an input device.** The
   kernel skips interfaces whose report descriptor has no input application, so
   the patch prepends a fake generic-desktop keyboard report to the vendor
   interface's descriptor. The Fn hotkey codes (vendor page `0xff31`) then map
   through the driver's normal `asus_input_mapping()` (brightness, display off,
   sleep, mic-mute, camera, MyASUS, screen-swap, …).

2. **The keyboard needs the `0x5a` handshake to emit hotkeys at all.** When the
   touchpad on the sibling USB interface is configured, it resets the keyboard
   to plain F-key mode and discards the handshake the driver sends from probe.
   The patch therefore re-sends the handshake from **delayed work ~2s after
   probe** on the USB vendor interface. (This is the same mechanism as the
   upstream Aug 11 2026 UX8407AA fix.)

### The handshake in detail

The handshake is a 16-byte HID feature report:

```
report_id 0x5a, then "ASUS Tech.Inc." (15 bytes, zero-padded)
```

It is sent as a `HIDIOCSFEATURE`-style SET_REPORT. The device STALLs it
(`-EPIPE`/`-32`) if it arrives too early — which is exactly what happens at
probe time before the delayed re-send.

## Downgrade / troubleshooting

- **Remove the module entirely:**

  ```bash
  sudo pacman -R hid-asus-zenbook-duo-dkms
  ```

- **Handshake still failing after install:** the delayed re-send runs 2s after
  probe. If `dmesg` still shows `Asus re-init failed: -32`, the keyboard
  firmware on your unit may need more time; open an issue with the dmesg
  output and `ls /sys/bus/usb/devices/*/idProduct`.

- **Touchpad stopped working:** the touchpad is on interface 5 and is
  deliberately left to `hid-multitouch` (see device table comment in
  `hid-asus.c`). If it's not working after install, check `dmesg` for
  `hid-multitouch` binding.

## Attribution

This package is a backport of *upstream linux-input patch series*, written by
others; we take no credit for the driver code:

- **May 2026 series — "ASUS Zenbook Duo keyboard support"** (adds
  UX8406MA/CA/AA support, vendor hotkey interface fixup, fake keyboard,
  mappings):
  <https://patchwork.kernel.org/project/linux-input/list/?series=1094331>
- **Aug 11 2026 follow-up — "HID: asus: Reinitialize Zenbook Duo keyboard
  after touchpad config"** by Rebecca Mara Müller (delayed 0x5a handshake
  re-send that this package backports for the UX8406MA):
  <https://patchwork.kernel.org/project/linux-input/list/?series=14743250>
- Reference implementation used for cross-checking on the UX8406MA:
  **lewisdenny/zenbook-duo-hid-asus-dkms**
  (Fedora DKMS packaging of the same work):
  <https://github.com/lewisdenny/zenbook-duo-hid-asus-dkms>

Neither series is merged into mainline as of kernel 7.2.15 (checked against
`v7.2` and `master`: no `UX8406` or `ZENBOOK_DUO` hits in
`drivers/hid/hid-asus.c` / `hid-ids.h`), which is why this package ships the
patched source. Re-check those files for a Zenbook Duo quirk before extending
this package (see `AGENTS.md`).

The legacy desktop configuration (`home/`, `setup.sh`) is original to this
repository; the maintained version lives in
[locomarchy](https://github.com/etimesg/locomarchy).

## License

`hid-asus.c`/`hid-ids.h` are kernel code, licensed **GPL-2.0-only** (as
declared in the PKGBUILD). The rest of this repository is licensed under
**MIT** unless noted otherwise.
