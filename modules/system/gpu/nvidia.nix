{ config, lib, ... }:

# READ: https://nixos.wiki/wiki/Nvidia

let 
  cfg = config.modules.system.gpu.nvidia;
  inherit (lib) mkEnableOption mkIf types mkOption;
in {

  options.modules.system.gpu.nvidia = {
    enable = mkEnableOption "nvidia";

    open = mkEnableOption "open";
    powerManagement = mkEnableOption "powerManagement";
    finegrained = mkEnableOption "finegrained";
    nvidiaPackage = mkOption {
      type = types.package;
      default = config.boot.kernelPackages.nvidiaPackages.production;
      description = "The Nvidia driver package to use.";
    };
  };

  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];

    hardware.nvidia = {

      # Modesetting is required.
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      # Enable this if you have graphical corruption issues or application crashes after waking
      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
      # of just the bare essentials.
      powerManagement.enable = cfg.powerManagement;

      # Fine-grained power management. Turns off the GPU when not in use.
      powerManagement.finegrained = cfg.finegrained && cfg.powerManagement;

      # NVIDIA's open kernel module (not nouveau); recommended by NVIDIA for
      # Turing and newer since driver 560, required for Blackwell.
      open = cfg.open;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      package = cfg.nvidiaPackage;
    };

  };
}
