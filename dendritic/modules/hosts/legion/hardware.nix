{ inputs, ... }:
{
  # Lenovo Legion (AMD Raphael iGPU + NVIDIA dGPU). Merged from the generated
  # hardware-configuration.nix and the nixos-hardware / power-management tweaks.
  flake.modules.nixos.legion-hardware = { config, lib, pkgs, modulesPath, ... }: {
    imports = with inputs.nixos-hardware.nixosModules; [
      (modulesPath + "/installer/scan/not-detected.nix")

      common-cpu-amd
      common-cpu-amd-zenpower
      common-cpu-amd-raphael-igpu
      common-pc-laptop-ssd
    ];

    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "usbhid" "sd_mod" ];
    boot.initrd.includeDefaultModules = true;
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    boot.supportedFilesystems = [ "vfat" "ext4" "ntfs" ];

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/dbeb5768-76e7-496b-ad9e-c54f2c29c9e1";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/CEDC-EDAE";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    # ntfs-3g (FUSE) instead of the kernel ntfs driver: deleting large files with
    # the kernel driver corrupted the volume and needed a Windows chkdsk to repair.
    fileSystems."/run/media/${config.my.user.name}/windows" = {
      device = "/dev/disk/by-uuid/D63A9CFF3A9CDDB5";
      fsType = "ntfs-3g";
      noCheck = true;
      options = [ "nofail" "rw" "uid=1000" "gid=100" "umask=0022" "windows_names" ];
    };

    swapDevices = [ { device = "/dev/disk/by-uuid/7cc7f337-c05e-499d-9cc0-02481d10ccc0"; } ];
    # Needed for resume from hibernation to be attempted at all.
    boot.resumeDevice = "/dev/disk/by-uuid/7cc7f337-c05e-499d-9cc0-02481d10ccc0"; # swap

    networking.useDHCP = lib.mkDefault true;
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    hardware.enableRedistributableFirmware = true;

    hardware.bluetooth.enable = true;
    services.fwupd.enable = true; # BIOS/firmware updates via LVFS (fwupdmgr)

    # 64M initrds on a 1G ESP
    boot.loader.grub.configurationLimit = 5;

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
    # TLP doesn't set PLATFORM_PROFILE_*, so there's no fight.
    systemd.tmpfiles.rules = [
      "z /sys/firmware/acpi/platform_profile 0664 root users - -"
    ];

    environment.systemPackages = with pkgs; [
      lenovo-legion
      powertop
      htop
    ];

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

          DEVICES_TO_DISABLE_ON_STARTUP = "bluetooth wwan";
          DEVICES_TO_DISABLE_ON_LAN_CONNECT = "wifi wwan";
          DEVICES_TO_DISABLE_ON_WIFI_CONNECT = "wwan";
          DEVICES_TO_ENABLE_ON_LAN_DISCONNECT = "wifi";

          START_CHARGE_THRESH_BAT1 = 20;
          STOP_CHARGE_THRESH_BAT1 = 80;
        };
      };
    };
  };
}
