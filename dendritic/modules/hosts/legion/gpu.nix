{
  # AMD iGPU (PCI 6:0:0) renders and drives the panel; NVIDIA dGPU (PCI 1:0:0)
  # is PRIME-offloaded and sleeps in D3cold when idle. The "Hyprland (dGPU)"
  # GDM session renders everything on the dGPU instead (see hypr/nvidia.lua).
  flake.modules.nixos.legion-gpu = { config, pkgs, lib, ... }: {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    services.xserver.videoDrivers = [ "nvidia" "amdgpu" ];

    hardware.nvidia = {
      modesetting.enable = true;
      # saves all of VRAM across suspend; fixes corruption/crashes after waking
      powerManagement.enable = true;
      # turns the dGPU off when not in use
      powerManagement.finegrained = true;
      # NVIDIA's open kernel module, recommended for Turing and newer
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        amdgpuBusId = "PCI:6:0:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

    hardware.nvidia-container-toolkit.enable = true;

    services.displayManager.sessionPackages = [
      ((pkgs.writeTextDir "share/wayland-sessions/hyprland-dgpu.desktop" ''
        [Desktop Entry]
        Name=Hyprland (dGPU)
        Comment=Hyprland and all apps rendered on the NVIDIA GPU
        Exec=${lib.getExe pkgs.uwsm} start -e -D Hyprland -N "Hyprland (dGPU)" -- ${pkgs.writeShellScript "hyprland-dgpu" ''
          export HYPR_DGPU=1
          exec ${config.programs.hyprland.package}/bin/start-hyprland "$@"
        ''}
        DesktopNames=Hyprland
        Type=Application
      '').overrideAttrs { passthru.providedSessions = [ "hyprland-dgpu" ]; })
    ];

    # Load amdgpu in the initrd so the iGPU always gets the first render node
    # (renderD128); in stage 2 nvidia-drm can win the race, and apps that open
    # renderD128 by default then lose VA-API decode (radeonsi on nvidia fails).
    hardware.amdgpu.initrd.enable = true;

    # resonate's dGPU slider writes the card's runtime-PM switch as this group.
    users.groups.gpucontrol = { };
    users.users.${config.my.user.name}.extraGroups = [ "gpucontrol" ];

    services.udev.extraRules = ''
      # NVIDIA dGPU (PCI 0000:01:00.0)
      KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"
      KERNEL=="renderD*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu-render"

      # AMD iGPU (PCI 0000:06:00.0)
      KERNEL=="card*", KERNELS=="0000:06:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu"
      KERNEL=="renderD*", KERNELS=="0000:06:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu-render"

      # Pin wakeup off on the dGPU's own functions so a spurious PME from the
      # card while it sits in D3cold can't resume the machine in a suspend loop.
      # (The parent root port 0000:00:01.1 is intentionally left alone: the
      # kernel re-enables its wakeup for runtime-PM, and the leaf rules below are
      # what actually stop the card from generating the wake event.)
      ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:01:00.0", ATTR{power/wakeup}="disabled"
      ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:01:00.1", ATTR{power/wakeup}="disabled"

      # dGPU runtime-PM switch (auto = sleep when idle, on = kept awake),
      # writable by gpucontrol for resonate's dGPU slider.
      ACTION=="add|bind", SUBSYSTEM=="pci", KERNEL=="0000:01:00.0", RUN+="${pkgs.coreutils}/bin/chgrp gpucontrol /sys%p/power/control", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys%p/power/control"
    '';

    # The dGPU's HDMI/DP audio (0000:01:00.1) is useless without an external
    # display, and WirePlumber holding its control device kept the codec at D0,
    # which in turn kept the dGPU pinned out of D3cold.
    services.pipewire.wireplumber.extraConfig."51-disable-nvidia-hdmi-audio" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "device.name" = "alsa_card.pci-0000_01_00.1"; } ];
          actions.update-props."device.disabled" = true;
        }
      ];
    };
  };
}
