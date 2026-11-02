#!/bin/bash
# Removes the Cupertino theme and restores what it changed.
#   ./uninstall.sh [--theme <name>]   Theme to switch to (default: the one you had before)
set -euo pipefail

OMARCHY_CONFIG=$HOME/.config/omarchy
ICONS_DIR=$HOME/.local/share/icons
STATE_DIR=$HOME/.local/state/cupertino-omarchy
GHOSTTY_NOTE=0

theme=""
while (( $# > 0 )); do
  case $1 in
    --theme) theme=${2:?--theme needs a name}; shift 2 ;;
    -h | --help) sed -n 2,3p "$0" | cut -c3-; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
[[ -n $theme ]] || theme=$(cat "$STATE_DIR/previous-theme" 2>/dev/null || echo tokyo-night)

# The hook undoes its own changes when leaving the theme, so it must still be there.
current=$(omarchy theme current)
if [[ $current == Cupertino || $current == cupertino ]]; then
  echo "==> Switching to $theme"
  omarchy theme set "$theme"
fi

echo "==> Removing files"
rm -f "$OMARCHY_CONFIG/hooks/theme-set.d/cupertino"
rm -rf "$OMARCHY_CONFIG/themes/cupertino" "$ICONS_DIR/Cupertino"
rm -rf "$OMARCHY_CONFIG"/plugins/cupertino.*
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

if [[ -f $STATE_DIR/cursor-installed ]]; then
  rm -rf "$ICONS_DIR/macOS"
fi

if [[ -f $STATE_DIR/terminal-switched ]]; then
  if [[ -f $STATE_DIR/backup/xdg-terminals.list ]]; then
    cp "$STATE_DIR/backup/xdg-terminals.list" "$HOME/.config/xdg-terminals.list"
  else
    rm -f "$HOME/.config/xdg-terminals.list"
  fi
  GHOSTTY_NOTE=1
fi

rm -rf "$STATE_DIR"
echo "==> Restarting the shell"
omarchy restart shell

echo "==> Done. Packages it installed were left in place."
(( ! GHOSTTY_NOTE )) || echo "    Your previous default terminal is restored; Ghostty is still installed."
