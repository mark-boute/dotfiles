{ lib, config, pkgs, inputs, ...}:
with lib; let 
  hardware-modules = inputs.nixos-hardware.nixosModules;
  nvidiaPackage = config.hardware.nvidia.package;
in {
    imports = [
    # cpu
      hardware-modules.common-cpu-intel
      hardware-modules.common-pc-laptop
      hardware-modules.common-pc-laptop-ssd
    ];


}