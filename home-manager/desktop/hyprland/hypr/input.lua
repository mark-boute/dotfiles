-- Base input configuration. Per-device overrides live in device.lua.

hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 2,
    numlock_by_default = true,
    natural_scroll = false,
    special_fallthrough = true,
    touchpad = {
      natural_scroll = true,
      drag_lock = 1,
      clickfinger_behavior = true;
    },
  },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
