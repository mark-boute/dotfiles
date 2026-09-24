{ inputs, pkgs, ...}:
let 
  hardware-modules = inputs.nixos-hardware.nixosModules;
in {

  imports = [
    hardware-modules.common-cpu-amd
    hardware-modules.common-cpu-amd-zenpower
    hardware-modules.common-cpu-amd-raphael-igpu

    # hardware-modules.common-pc-laptop
    hardware-modules.common-pc-laptop-ssd
  ];

  config = {

    # Load amdgpu in the initrd so the iGPU always gets the first render node
    # (renderD128); in stage 2 nvidia-drm can win the race, and apps that open
    # renderD128 by default then lose VA-API decode (radeonsi on nvidia fails).
    hardware.amdgpu.initrd.enable = true;

    # boot.extraModulePackages = with config.boot.kernelPackages; [
    #   rtw89
    # ];

    boot = {
      kernelParams = [ 
        "amd_pstate=active"
        "acpi_osi=Linux"
        # firmware spams wake events (GPE 0x10) at the dGPU root port,
        # yanking it out of D3cold every ~18s; mask until a BIOS fix
        "acpi_mask_gpe=0x10"
        # firmware can ACPI-eject the dGPU slot after unplugging AC; with
        # Hyprland holding the card the removal hangs and pins it awake.
        # The nvidia driver's runtime D3 does the sleeping instead.
        "acpiphp.disable=1"
        # panel adaptive backlight (saved ~0.5-1.5W) was silently dimming the
        # panel well past the requested brightness on dark (Catppuccin)
        # content — disabled 2026-09-23 so the slider means what it says.
        "amdgpu.abmlevel=0"
      ];

      extraModprobeConfig = ''
        options snd_hda_intel power_save=1 power_save_controller=Y # Silences the Nvidia Audio link loop
      '';
    };

    # resonate's PlatformProfileService owns the ACPI platform profile
    # (low-power / balanced / performance — Legion firmware fan/TDP curves).
    # TLP doesn't set PLATFORM_PROFILE_*, so there's no fight. Open the sysfs
    # attr to the `users` group so the service writes it without a helper.
    systemd.tmpfiles.rules = [
      "z /sys/firmware/acpi/platform_profile 0664 root users - -"
    ];

    # ACPI S4 (platform) handoff cuts power before the NVMe write cache
    # commits the hibernation image's final signature block, so every resume
    # reads a corrupted/missing image (kernel: "PM: Image not found (code
    # -22)") and either hangs mid-restore or falls through to a cold boot.
    # Force the kernel-controlled poweroff path instead, which waits for the
    # write to actually complete before cutting power.
    systemd.services.systemd-hibernate.serviceConfig.ExecStartPre =
      "${pkgs.bash}/bin/sh -c 'echo shutdown > /sys/power/disk'";

    services = {
      power-profiles-daemon.enable = false;
      tlp = {
        enable = true;
        settings = {
          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

          CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
          CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

          PCIE_ASPM_ON_AC = "default";
          PCIE_ASPM_ON_BAT = "powersupersave";

          USB_AUTOSUSPEND = 1;

          DEVICES_TO_DISABLE_ON_STARTUP= "bluetooth wwan";
          DEVICES_TO_DISABLE_ON_LAN_CONNECT= "wifi wwan";
          DEVICES_TO_DISABLE_ON_WIFI_CONNECT= "wwan";
          DEVICES_TO_ENABLE_ON_LAN_DISCONNECT= "wifi";

          START_CHARGE_THRESH_BAT1 = 20;
          STOP_CHARGE_THRESH_BAT1 = 80;
        };
      };
    };
  };
}