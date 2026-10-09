-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

-- eDP-1/eDP-2 are 2880x1800 panels stacked vertically. In logical (scaled)
-- coordinates a panel is 2880x1800 / scale, so the base screen's y-offset is
-- its logical height, 1800 / scale. Deriving it keeps the two screens stacked
-- no matter what value "omarchy hyprland monitor scaling" writes above.
local omarchy_bottom_y = math.floor(1800 / omarchy_monitor_scale)

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- ASUS Zenbook Duo: eDP-1 is the top screen, eDP-2 is the base screen
-- physically below it (position 0x<logical height> stacks it directly under the
-- top display instead of overlapping it or sitting to the right). eDP-2 is
-- DISABLED by default so the laptop behaves as a single monitor -- workspaces
-- never jump to the base screen. ~/.local/bin/zenbook-duo-screen re-enables it
-- when the keyboard is lifted off the pogo-pin bridge and re-disables it
-- (within a couple of seconds) whenever a config reload such as a monitor-scale
-- change would otherwise turn it back on.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
hl.monitor({ output = "eDP-2", mode = "preferred", position = "0x" .. omarchy_bottom_y, scale = omarchy_monitor_scale, disabled = true })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
