{ inputs, ...}:
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

    # boot.extraModulePackages = with config.boot.kernelPackages; [
    #   rtw89
    # ];

    boot = {
      kernelParams = [ 
        "amd_pstate=active"
      ];
    };

  # This is next up to try out. note that PCIE_ASPM_ON_BAT = "powersupersave"; should be changed. Read tlp docs on that variable first. 
  # boot = {
  #     kernelParams = [ 
  #       "amd_pstate=active"
  #       "nvidia-drm.modeset=1"
  #       "nvidia-drm.fbdev=1"
  #       "acpi_osi=Linux" # Bypasses the buggy [\_SB.PCI0.GPP0.PEGP.GPS.NVD1] ACPI bug
  #     ];

  #     extraModprobeConfig = ''
  #       options nvidia "NVreg_DynamicPowerManagement=0x02"
  #       options snd_hda_intel power_save=1 power_save_controller=Y # Silences the Nvidia Audio link loop
  #     '';
  #   };

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

          START_CHARGE_THRESH_BAT1 = 40;
          STOP_CHARGE_THRESH_BAT1 = 80;
        };
      };
    };
  };
}