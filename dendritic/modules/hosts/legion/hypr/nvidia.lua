-- HYPR_DGPU=1 comes from the "Hyprland (dGPU)" GDM session (gpu.nix).
if os.getenv("HYPR_DGPU") == "1" then
    -- The dGPU renders and copies frames to the iGPU-wired panel; apps
    -- inherit these so GL, Vulkan and VA-API all pick NVIDIA.
    hl.env("AQ_DRM_DEVICES", "/dev/dri/nvidia-dgpu:/dev/dri/amd-igpu")
    hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("__VK_LAYER_NV_optimus", "NVIDIA_only")
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
else
    -- The iGPU renders; the dGPU is listed so monitors on its ports (the HDMI
    -- port is wired to it) hotplug mid-session. Holding it open doesn't keep it
    -- out of D3cold. LIBVA_DRIVER_NAME is set by resonate's PlatformProfileService.
    hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")
end

-- https://wiki.hypr.land/Nvidia/#multi-gpu-or-hybrid-graphics-not-working-for-monitors-attached-to-nvidia-gpu

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
