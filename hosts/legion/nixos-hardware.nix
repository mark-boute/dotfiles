{ lib, config, pkgs, inputs, ...}:
with lib; let 
  hardware-modules = inputs.nixos-hardware.nixosModules;
  nvidiaPackage = config.hardware.nvidia.package;
in {

  imports = [
    # cpu
    hardware-modules.common-cpu-amd
    hardware-modules.common-cpu-amd-pstate

    # gpu (in seperate modules)


    # laptop
    hardware-modules.common-pc-laptop
    hardware-modules.common-pc-laptop-ssd
  ];

  config = {
    # ensure use of latest LTS kernel for more Raphael fixes
    boot = mkIf (versionOlder pkgs.linux.version "6.6") {
      kernelPackages = pkgs.linuxPackages_latest;
      kernelParams = [ "amdgpu.sg_display=0" ];
    };

    # AMD has better battery life with PPD over TLP
    services.power-profiles-daemon.enable = mkDefault true;

    # enable the open source drivers for nvidia
    hardware.nvidia.open = mkOverride 990 (nvidiaPackage ? open && nvidiaPackage ? firmware);

    # cooling
    services.thermald.enable = mkDefault true;
  };
}