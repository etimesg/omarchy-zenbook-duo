# AGENTS.md

This repository contains my Omarchy (Arch + Hyprland) configuration for the
**ASUS Zenbook Duo (UX8406MA)**, which has two internal panels:

| Output | Panel        | Where it sits           |
|--------|--------------|-------------------------|
| `eDP-1`| Main display | Top (2880x1800, scale 2)|
| `eDP-2`| Base display | Bottom (2880x1800, scale 2) |

The Duo's keyboard is detachable. It connects over a **pogo-pin USB bridge**
(vendor `0b05`, product `1b2c`) when docked over the base screen, and falls
back to **Bluetooth** (vendor `0b05`, product `1b2d`) when lifted off. We use
the USB presence as the dock sensor.

## File layout

Files mirror a normal `~` home directory so they can be dropped in place or
symlinked directly:

- `home/.config/hypr/monitors.lua` — places `eDP-2` *below* `eDP-1` at `0x900`
  (Omarchy's default auto-layout put it to the right at `1440x0`) and keeps it
  `disabled` by default so the laptop behaves as a single monitor.
- `home/.config/hypr/autostart.lua` — starts `zenbook-duo-screen` at login.
- `home/.local/bin/zenbook-duo-screen` — daemon that keeps `eDP-2` disabled
  while the keyboard is docked, re-enables it when lifted, and re-asserts the
  docked state every couple of seconds so Hyprland config reloads can't turn
  the base screen back on behind its back.
- `pkg/hid-asus-zenbook-duo-dkms/` — Arch package + DKMS module making the
  keyboard's Fn hotkeys work (see its PKGBUILD and the README).
- `setup.sh` — one-command installer for a fresh machine.

## Install on a fresh machine

```bash
./setup.sh --reload --daemon
```

This detects the Zenbook Duo, copies (or `--symlink`s) the config into `~`,
makes the daemon executable, reloads Hyprland after verifying
`hyprctl configerrors`, and starts the daemon. It is idempotent and safe to
re-run.

Manual equivalent:

```bash
ln -s "$PWD/home/." ~/            # or: cp -r "$PWD/home/." ~/
chmod +x ~/.local/bin/zenbook-duo-screen
hyprctl reload
systemd-run --user --unit=zenbook-duo-screen --collect ~/.local/bin/zenbook-duo-screen
```

## Update safety

These files **survive `omarchy update`**:

- Omarchy migrations only rewrite `input.lua`/`bindings.lua` when they still
  byte-match the stock file (untouched by the user) plus `hyprland.lua`
  entrypoint path fixups. `monitors.lua` and `autostart.lua` are never
  touched by any migration.
- `~/.local/bin/zenbook-duo-screen` is outside everything Omarchy manages
  (it only manages mise wrappers and `herdr` there, matched by exact
  content/filename).

The only ways to reset them are explicit: `omarchy refresh hyprland` (backs up
first) or `omarchy reinstall-configs` (destructive). Neither runs during a
normal update.

Note on `--symlink`: a future Omarchy migration that rewrites one of the
symlinked files would write *through* the symlink into this repo. Copy is the
default for that reason. Nothing today rewrites these two files, so the risk
is theoretical.

## How the screen toggle works

`zenbook-duo-screen` runs a stateless, idempotent loop:

1. On startup and on every USB add/remove event it checks whether the keyboard
   bridge (`0b05:1b2c`) is present under `/sys/bus/usb/devices/`.
2. Docked → `hyprctl eval 'hl.monitor({ output = "eDP-2", disabled = true })'`.
3. Detached → re-enable with position/scale preserved.
4. A 2s read-timeout turns the `udevadm monitor` wait into a poll, so the
   live Hyprland state is re-asserted even with no USB event. `apply()` reads
   the *actual* monitor state (`hyprctl monitors -j`) instead of a cached
   flag, so a Hyprland config reload — e.g. `omarchy hyprland monitor scaling`
   rewriting `monitors.lua`, or an Omarchy update — that re-enables `eDP-2`
   is reverted within a couple of seconds. The re-enable scale is read from
   `monitors.lua` so lifting the keyboard never snaps back to a stale scale.
5. It logs decisions to `$XDG_RUNTIME_DIR/zenbook-duo-screen.log`.

`monitors.lua` also ships `eDP-2` with `disabled = true`, so a reload never
turns the base screen on in the first place and the laptop stays single-monitor
even if the daemon is not running.

### Important implementation notes

- **Hyprland 0.56 uses the Lua config parser.** The old `hyprctl keyword
  monitor eDP-2,disable` is rejected (`keyword can't work with non-legacy
  parsers. Use eval.`). Monitor changes MUST go through `hyprctl eval` with
  the `hl.monitor` helper, as in the script.
- **Read USB vendor/product with `cat`, not `$(<file 2>/dev/null)`.**
  In bash, adding `2>/dev/null` to the `$(<file)` fast-read disables it and
  returns an empty string, making the keyboard always look detached.
- `hyprctl eval` needs the compositor's environment, so the daemon must run
  from a Hyprland session (autostart.lua), not from a bare shell.
- Re-enabling a monitor requires `disabled = false` explicitly; just passing
  mode/position does not clear the flag.

## Committing changes

When editing Hyprland config in this repo, keep the live copy in sync
(`~/.config/hypr/`, `~/.local/bin/`) and validate with:

```bash
hyprctl reload && hyprctl configerrors
```

Then re-run `systemd-run` above (or restart Hyprland) to verify the daemon.
Only commit after `hyprctl configerrors` reports clean.
