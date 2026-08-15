#!/usr/bin/env bash
# Install the ASUS Zenbook Duo Omarchy configuration on this machine.
#
#   setup.sh [--symlink] [--daemon] [--reload]
#
# Options:
#   --symlink   Symlink ~/.config/hypr/* and ~/.local/bin/* into the repo
#               instead of copying (keeps future git pulls live, but means a
#               future Omarchy migration that rewrites those exact files would
#               write through the symlink into the repo -- copy is the default
#               for that reason).
#   --daemon    Also start the screen-toggle daemon now (systemd user unit).
#   --reload    Also reload Hyprland after installing.
#
# Safe to re-run; every step is idempotent.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_TREE="$REPO_DIR/home"

MODE="copy"
RUN_DAEMON=0
RELOAD=0
for arg in "$@"; do
  case "$arg" in
    --symlink) MODE="symlink" ;;
    --daemon) RUN_DAEMON=1 ;;
    --reload) RELOAD=1 ;;
    --help|-h)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

# Refuse to run on anything but a Zenbook Duo (UX8406) unless forced.
if [[ ${1:-} != --force ]] && ! grep -q "Zenbook Duo" /sys/class/dmi/id/product_name 2>/dev/null; then
  echo "This config targets the ASUS Zenbook Duo (UX8406)." >&2
  echo "Detected product: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)" >&2
  echo "Re-run with --force to install anyway." >&2
  exit 1
fi

link_or_copy() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ $MODE == "symlink" ]]; then
    ln -sfn "$src" "$dst"
  else
    cp -f "$src" "$dst"
  fi
}

echo "Installing Zenbook Duo config ($MODE mode)..."

# Hyprland config files.
for file in monitors.lua autostart.lua; do
  link_or_copy "$HOME_TREE/.config/hypr/$file" "$HOME/.config/hypr/$file"
done

# Screen-toggle daemon.
link_or_copy "$HOME_TREE/.local/bin/zenbook-duo-screen" "$HOME/.local/bin/zenbook-duo-screen"
chmod +x "$HOME/.local/bin/zenbook-duo-screen"

# Stop any running instance before starting the freshly installed one.
if systemctl --user list-units --type=service 2>/dev/null | grep -q "zenbook-duo-screen"; then
  systemctl --user stop zenbook-duo-screen || true
fi

if (( RELOAD )); then
  echo "Reloading Hyprland..."
  if hyprctl reload && hyprctl configerrors; then
    echo "Hyprland reloaded cleanly."
  else
    echo "Hyprland reported config errors -- see output above." >&2
    exit 1
  fi
fi

if (( RUN_DAEMON )) || systemctl --user is-active zenbook-duo-screen &>/dev/null; then
  echo "Starting zenbook-duo-screen daemon..."
  systemd-run --user --unit=zenbook-duo-screen --collect "$HOME/.local/bin/zenbook-duo-screen"
  echo "Daemon running. Logs: \$XDG_RUNTIME_DIR/zenbook-duo-screen.log"
fi

echo "Done. The base screen (eDP-2) will now turn off when the keyboard is"
echo "docked over it and back on when it is lifted. It also auto-starts on"
echo "next login via autostart.lua."
