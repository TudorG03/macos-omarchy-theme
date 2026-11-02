#!/bin/bash
# Installs the Cupertino theme for Omarchy. Run it again to update.
#   ./install.sh [--yes] [--keep-terminal] [--no-cursor] [--no-title-bars]
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OMARCHY_CONFIG=$HOME/.config/omarchy
ICONS_DIR=$HOME/.local/share/icons
STATE_DIR=$HOME/.local/state/cupertino-omarchy
TESTED_OMARCHY=4
TESTED_HYPRLAND=0.56
PACKAGES=(yaru-icon-theme adwaita-fonts ttf-jetbrains-mono-nerd nautilus gtk3 uwsm networkmanager bluez-utils wireplumber jq)
BUILD_PACKAGES=(git gcc make pkgconf)
PLUGINS_URL=https://github.com/hyprwm/hyprland-plugins.git
PLUGINS_DIR=$HOME/.local/share/hyprland-plugins
GHOSTTY_ID=com.mitchellh.ghostty.desktop
CURSOR_URL=https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS.tar.xz
CURSOR_SHA256=9c6e5e13b068ce51a9e90a9abd6ce232ec7d25d4ceb05aa8ac76efbb99c76762

ASSUME_YES=0 KEEP_TERMINAL=0 WITH_CURSOR=1 WITH_BARS=1
for arg in "$@"; do
  case $arg in
    --yes | -y) ASSUME_YES=1 ;;
    --keep-terminal) KEEP_TERMINAL=1 ;;
    --no-cursor) WITH_CURSOR=0 ;;
    --no-title-bars) WITH_BARS=0 ;;
    -h | --help) sed -n 2,3p "$0" | cut -c3-; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mWarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
  (( ASSUME_YES )) && return 0
  [[ -t 0 ]] || die "$1 Re-run with --yes to accept."
  read -rp "$1 [y/N] " reply
  [[ $reply == [yY]* ]]
}

# Preflight
(( EUID != 0 )) || die "Run this as your normal user, not root."
command -v omarchy >/dev/null || die "Omarchy was not found. This theme only works on Omarchy."
command -v hyprctl >/dev/null || die "Hyprland was not found."
hyprctl version >/dev/null 2>&1 || die "Run this from inside your Hyprland session."
omarchy-shell shell ping >/dev/null 2>&1 || die "The Omarchy shell is not running. Try: omarchy restart shell"

omarchy_version=$(omarchy version | cut -d- -f1)
hyprland_version=$(hyprctl version -j | jq -r .version 2>/dev/null || hyprctl version | awk 'NR == 1 { print $2 }')
if [[ ${omarchy_version%%.*} != "$TESTED_OMARCHY" || $hyprland_version != "$TESTED_HYPRLAND"* ]]; then
  warn "Tested on Omarchy $TESTED_OMARCHY.x with Hyprland $TESTED_HYPRLAND.x; you have Omarchy $omarchy_version with Hyprland $hyprland_version."
  warn "A failed reload can be undone with ./uninstall.sh."
fi

switch_terminal=0
if (( ! KEEP_TERMINAL )) && [[ $(grep -sv '^#' "$HOME/.config/xdg-terminals.list" | head -1) != "$GHOSTTY_ID" ]]; then
  switch_terminal=1
fi

(( ! WITH_BARS )) || PACKAGES+=("${BUILD_PACKAGES[@]}")
missing=()
for package in "${PACKAGES[@]}"; do
  pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
done

say "This will:"
(( ${#missing[@]} == 0 )) || echo "  - install packages (needs sudo): ${missing[*]}"
(( ! switch_terminal )) || echo "  - make Ghostty your default terminal (keep yours with --keep-terminal)"
(( ! WITH_CURSOR )) || echo "  - download the macOS cursor from github.com/ful1e5/apple_cursor (skip with --no-cursor)"
(( ! WITH_BARS )) || echo "  - build hyprbars from github.com/hyprwm/hyprland-plugins for traffic lights on every app (skip with --no-title-bars)"
echo "  - add the Cupertino theme, 13 shell plugins, a theme hook and an icon theme"
echo "  - back up your shell.json to $STATE_DIR, then switch to the theme"
echo "  Plugins, the hook and the theme run as your user, so read them first if you don't trust this repo."
confirm "Continue?" || { echo "Nothing changed."; exit 0; }

# Remembered before anything changes, so uninstalling can put it back.
mkdir -p "$STATE_DIR/backup"
if [[ ! -f $STATE_DIR/previous-theme ]]; then
  current=$(omarchy theme current)
  if [[ $current != Cupertino && $current != cupertino ]]; then
    echo "$current" >"$STATE_DIR/previous-theme"
  fi
  cp "$OMARCHY_CONFIG/shell.json" "$STATE_DIR/backup/shell.json"
fi

if (( ${#missing[@]} > 0 )); then
  say "Installing packages"
  omarchy pkg add "${missing[@]}"
fi

if (( switch_terminal )); then
  say "Setting Ghostty as the default terminal"
  [[ ! -f $HOME/.config/xdg-terminals.list ]] || cp "$HOME/.config/xdg-terminals.list" "$STATE_DIR/backup/xdg-terminals.list"
  touch "$STATE_DIR/terminal-switched"
  omarchy-install-terminal ghostty
elif (( ! KEEP_TERMINAL )) && ! pacman -Q ghostty >/dev/null 2>&1; then
  omarchy pkg add ghostty
fi

if (( WITH_CURSOR )) && [[ ! -d $ICONS_DIR/macOS || -f $STATE_DIR/cursor-installed ]]; then
  say "Downloading the cursor"
  scratch=$(mktemp -d)
  trap 'rm -rf "$scratch"' EXIT
  if curl -fsSL --retry 2 -m 120 -o "$scratch/cursor.tar.xz" "$CURSOR_URL" &&
    echo "$CURSOR_SHA256  $scratch/cursor.tar.xz" | sha256sum -c --status; then
    mkdir -p "$ICONS_DIR"
    tar -xJf "$scratch/cursor.tar.xz" -C "$scratch" --no-same-owner ./macOS
    rm -rf "$ICONS_DIR/macOS"
    mv "$scratch/macOS" "$ICONS_DIR/macOS"
    touch "$STATE_DIR/cursor-installed"
  else
    warn "Could not download the cursor, so you'll keep your current one."
  fi
fi

# Built here because a plugin only loads in the exact Hyprland it was compiled against.
# Hyprland's plugin repo lists which of its commits matches each Hyprland commit.
build_hyprbars() {
  local version commit pin source
  version=$(hyprctl version -j | jq -r .version)
  commit=$(hyprctl version -j | jq -r .commit)
  source=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$source'" RETURN

  git clone -q "$PLUGINS_URL" "$source" || return 1
  pin=$(grep -m1 -oE "\"$commit\", *\"[0-9a-f]{40}\"" "$source/hyprpm.toml" | grep -oE '[0-9a-f]{40}"$' | tr -d '"')
  [[ -n $pin ]] || { warn "hyprbars has no build for Hyprland $version yet."; return 1; }
  git -C "$source" checkout -q "$pin" || return 1
  make -C "$source/hyprbars" all >/dev/null 2>&1 || return 1

  mkdir -p "$PLUGINS_DIR"
  install -m 755 "$source/hyprbars/hyprbars.so" "$PLUGINS_DIR/hyprbars-$version.so"
  touch "$STATE_DIR/hyprbars-installed"
}

if (( WITH_BARS )); then
  say "Building hyprbars, which can take a minute"
  build_hyprbars || warn "Could not build hyprbars, so only GTK apps and Ghostty will have traffic lights."
fi

say "Copying files"
mkdir -p "$OMARCHY_CONFIG/themes" "$OMARCHY_CONFIG/plugins" "$OMARCHY_CONFIG/hooks/theme-set.d" "$ICONS_DIR"

# Copied rather than cloned: Omarchy drops a cloned theme's hyprland.lua and ghostty.conf,
# which are most of this theme, and the copy has no .git so it counts as the user's own.
rm -rf "$OMARCHY_CONFIG/themes/cupertino"
cp -r "$REPO/theme" "$OMARCHY_CONFIG/themes/cupertino"

for plugin in "$REPO"/plugins/*/; do
  id=$(basename "$plugin")
  omarchy plugin validate "$plugin" >/dev/null || die "Plugin $id failed validation."
  rm -rf "${OMARCHY_CONFIG:?}/plugins/$id"
  cp -r "$plugin" "$OMARCHY_CONFIG/plugins/$id"
done

install -m 755 "$REPO/hooks/cupertino" "$OMARCHY_CONFIG/hooks/theme-set.d/cupertino"
rm -rf "$ICONS_DIR/Cupertino"
cp -r "$REPO/icons/Cupertino" "$ICONS_DIR/Cupertino"

say "Loading the plugins"
omarchy-shell shell rescanPlugins >/dev/null
expected=$(find "$REPO/plugins" -mindepth 1 -maxdepth 1 -type d | wc -l)
for (( attempt = 0; attempt < 100; attempt++ )); do
  found=$(omarchy plugin list --json | jq '[.[] | select(.id | startswith("cupertino."))] | length')
  (( found == expected )) && break
  sleep 0.1
done
(( found == expected )) || die "The shell only found $found of $expected plugins."

say "Applying the theme"
omarchy theme set cupertino

# Plugins that replace a built-in only take over its IPC target after a restart.
say "Restarting the shell"
omarchy restart shell

errors=$(hyprctl configerrors 2>/dev/null || true)
if [[ -n ${errors//[[:space:]]/} && $errors != "no errors"* ]]; then
  warn "Hyprland reported config errors:"
  echo "$errors" >&2
fi

if [[ -f $STATE_DIR/hyprbars-installed ]]; then
  echo "Chromium and VS Code draw their own buttons too. To avoid two sets, see \"Traffic lights\" in the README."
fi
say "Done. Tap Super for Launchpad, press Super+Space for Spotlight, and use ./uninstall.sh to remove it."
