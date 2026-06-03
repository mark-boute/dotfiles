hl.env(
    "AQ_DRM_DEVICES",
    "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu"
)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- https://wiki.hypr.land/Nvidia/#multi-gpu-or-hybrid-graphics-not-working-for-monitors-attached-to-nvidia-gpu

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")