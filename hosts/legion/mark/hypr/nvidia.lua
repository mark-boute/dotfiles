-- Decide at login whether to expose the nvidia dGPU to the compositor.
-- Include it (as a fallback after the iGPU) only when an external display is
-- wired to the dGPU, or we're on AC. Otherwise pin the compositor to the AMD
-- iGPU alone so the dGPU can reach D3cold on battery instead of being held at
-- D0 by Xwayland. Evaluated once, at Hyprland startup -- not mid-session.
local function dgpu_needed()
    local cmd = [[
        nv=$(for c in /sys/class/drm/card[0-9]*; do
            [ "$(basename "$(readlink -f "$c/device")")" = 0000:01:00.0 ] && basename "$c" && break
        done)
        ext=no
        for s in /sys/class/drm/"$nv"-*/status; do
            case "$s" in *eDP*) continue ;; esac
            [ "$(cat "$s" 2>/dev/null)" = connected ] && ext=yes
        done
        ac=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)
        { [ "$ext" = yes ] || [ "$ac" = 1 ]; } && echo yes || echo no
    ]]
    local p = io.popen(cmd)
    if not p then return true end -- detection failed: keep the fallback to be safe
    local out = p:read("*l")
    p:close()
    return out ~= "no" -- default to including the dGPU unless explicitly "no"
end

if dgpu_needed() then
    hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia") -- GLX rendering on dGPU only when it's kept awake anyway
else
    hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu")
end
-- video decode stays on NVDEC: with fine-grained runtime PM the card
-- suspends again seconds after playback stops
hl.env("LIBVA_DRIVER_NAME", "nvidia")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- https://wiki.hypr.land/Nvidia/#multi-gpu-or-hybrid-graphics-not-working-for-monitors-attached-to-nvidia-gpu

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")