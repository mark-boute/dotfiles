{ lib, config, pkgs, inputs, ...}:
with lib; let 
  hardware-modules = inputs.nixos-hardware.nixosModules;
  nvidiaPackage = config.hardware.nvidia.package;
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

    boot.kernelParams = [ "amd_pstate=active" ];

    # powerManagement.enable = true;
    # powerManagement.powertop.enable = true;
    services = {
      power-profiles-daemon.enable = false;
      tlp = {
        enable = true;
        settings = {
          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

          CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
          CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

          # CPU_MIN_PERF_ON_AC = 0;
          # CPU_MAX_PERF_ON_AC = 100;
          # CPU_MIN_PERF_ON_BAT = 0;
          # CPU_MAX_PERF_ON_BAT = 20;

          DEVICES_TO_DISABLE_ON_STARTUP= "bluetooth wwan";
          DEVICES_TO_DISABLE_ON_LAN_CONNECT= "wifi wwan";
          DEVICES_TO_DISABLE_ON_WIFI_CONNECT= "wwan";

          DEVICES_TO_ENABLE_ON_LAN_DISCONNECT= "wifi";

          #Optional helps save long term battery health
          START_CHARGE_THRESH_BAT1 = 40; # 40 and bellow it starts to charge
          STOP_CHARGE_THRESH_BAT1 = 80; # 80 and above it stops charging
        };
    };
  };

#     # enable the open source drivers for nvidia
#     hardware.nvidia.open = mkOverride 990 (nvidiaPackage ? open && nvidiaPackage ? firmware);
  };
}