#!/bin/sh
# Fades a window out quickly, then sends it to the Dock. Hyprland can't clear an
# opacity set at runtime, so this reads the window's opacity first and puts it back.
address=${1:-$(hyprctl activewindow -j | jq -r .address)}
target="address:$address"

# A second click during the fade would read the faded opacity as the original.
lock="${XDG_RUNTIME_DIR:-/tmp}/cupertino-minimize-$address"
mkdir "$lock" 2>/dev/null || exit 0
trap 'rmdir "$lock"' EXIT

set_opacity() {
  hyprctl dispatch "hl.dsp.window.set_prop({ prop = 'opacity', value = '$1', window = '$target' })" >/dev/null
}

opacity=$(hyprctl getprop "$target" opacity | head -1)
for level in 0.8 0.6 0.4 0.2 0; do
  set_opacity "$(awk "BEGIN { print $opacity * $level }")"
  sleep 0.015
done

hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:minimized', follow = false, window = '$target' })" >/dev/null
set_opacity "$opacity"
