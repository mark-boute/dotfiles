-- The iGPU renders; the dGPU is listed so monitors on its ports (the HDMI
-- port is wired to it) hotplug mid-session. Holding it open doesn't keep it
-- out of D3cold. LIBVA_DRIVER_NAME is set by resonate's PlatformProfileService.
hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- https://wiki.hypr.land/Nvidia/#multi-gpu-or-hybrid-graphics-not-working-for-monitors-attached-to-nvidia-gpu

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
