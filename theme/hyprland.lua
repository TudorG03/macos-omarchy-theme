local active_border_color = "rgba(ffffff40)"
local inactive_border_color = "rgba(ffffff14)"

hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 12,
    border_size = 1,

    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    rounding = 12,
    rounding_power = 3,

    shadow = {
      enabled = true,
      range = 36,
      render_power = 4,
      offset = "0 10",
      color = "rgba(000000a6)",
      color_inactive = "rgba(00000059)",
    },

    blur = {
      enabled = true,
      size = 10,
      passes = 3,
      vibrancy = 0.2,
      noise = 0.01,
      popups = true,
    },
  },
})

-- Slide between workspaces like Spaces, and let windows spring open.
hl.curve("macSpring", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1.1 } } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "macSpring", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "macSpring" })

-- Frosted Terminal.app-style windows.
o.window({ tag = "terminal" }, { opacity = "0.9 0.85" })

-- The hook applies the cursor live; this keeps it after a fresh login.
hl.env("XCURSOR_THEME", "macOS")

-- Frost the shell's translucent surfaces; ignore_alpha keeps full-screen scrims unblurred.
hl.layer_rule({
  match = { namespace = "^(omarchy-bar|omarchy-menu|omarchy-notifications|omarchy-osd|omarchy-polkit|omarchy-clipboard|omarchy-emojis|omarchy-keyboard-panel|omarchy-reminders|omarchy-dock|omarchy-dock-menu|omarchy-spotlight|omarchy-apple-menu|omarchy-control-center|omarchy-notification-center|omarchy-app-switcher|omarchy-launchpad)$" },
  blur = true,
  ignore_alpha = 0.3,
})

-- Super+Space opens Spotlight; the Omarchy menu stays on the Apple logo and in Spotlight.
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Spotlight", "omarchy-shell shell toggle cupertino.spotlight '{}'")

-- Finder floats at a size where its sidebar stays open.
o.window({ class = "^org\\.gnome\\.Nautilus$", title = "negative:^Properties$" }, { float = true, center = true, size = { 1100, 680 }, tag = "-default-opacity", opacity = "1 1" })

-- Mission Control animates itself, so it opts out of the compositor's layer fade.
hl.layer_rule({ match = { namespace = "omarchy-mission-control" }, no_anim = true, animation = "none" })
o.bind("SUPER + GRAVE", "Mission Control", "omarchy-shell shell toggle cupertino.mission-control '{}'")
o.bind("SUPER + SHIFT + GRAVE", "App Expose", "omarchy-shell shell toggle cupertino.mission-control '{\"app\":\"current\"}'")

hl.layer_rule({ match = { namespace = "omarchy-launchpad" }, no_anim = true, animation = "none" })
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + ALT + SPACE", "Launchpad", "omarchy-shell shell toggle cupertino.launchpad '{}'")
-- Not transparent, so pressing another key while Super is held cancels this.
o.bind("SUPER + SUPER_L", "Launchpad", "omarchy-shell shell toggle cupertino.launchpad '{}'", { release = true })

-- Command-Tab: Super+Tab steps through apps, and letting go of Super switches.
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + TAB", "App Switcher", "omarchy-shell shell summon cupertino.app-switcher '{\"direction\":1}'")
o.bind("SUPER + SHIFT + TAB", "App Switcher backwards", "omarchy-shell shell summon cupertino.app-switcher '{\"direction\":-1}'")
o.bind("SUPER + SUPER_L", "App Switcher commit", "omarchy-shell shell call cupertino.app-switcher commit ''", { release = true, transparent = true })

-- Command-Q.
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Hyprland ignores the minimize and maximize requests from GTK title bar buttons, so catch
-- the click itself. Positions are relative to the window and come from the theme's gtk.css.
local traffic_light_windows = { ["com.mitchellh.ghostty"] = true, ["org.omarchy.agent"] = true, ["org.gnome.Nautilus"] = true }
local traffic_light_y, traffic_light_reach = 22, 10

-- These cover the whole screen but let clicks through.
local click_through_layers = { ["omarchy-osd"] = true, ["omarchy-notifications"] = true }

local function covered_by_layer(x, y)
  for _, layer in ipairs(hl.get_layers()) do
    if layer.mapped and layer.layer >= 2 and not click_through_layers[layer.namespace]
      and x >= layer.x and x < layer.x + layer.w and y >= layer.y and y < layer.y + layer.h then
      return true
    end
  end
  return false
end

hl.bind("mouse:272", function()
  local window, cursor = hl.get_active_window(), hl.get_cursor_pos()
  if not window or not cursor or not traffic_light_windows[window.class] or window.fullscreen ~= 0 then return end
  local x, y = cursor.x - window.at.x, cursor.y - window.at.y
  if math.abs(y - traffic_light_y) > traffic_light_reach or covered_by_layer(cursor.x, cursor.y) then return end

  if math.abs(x - 39) <= traffic_light_reach then
    hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:" .. window.address }))
  elseif math.abs(x - 60) <= traffic_light_reach then
    hl.dispatch(hl.dsp.window.float({ action = "toggle", window = "address:" .. window.address }))
  end
end, { non_consuming = true, description = "Traffic light buttons" })
