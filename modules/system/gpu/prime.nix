{ config, pkgs, lib, ... }:

with lib; let 
  cfg = config.modules.system.gpu.optimus-prime;
in {
  # This needs device IDs to be set! See:
  # https://github.com/vimjoyer/nixos-gaming-video
  # and if possible:
  # https://github.com/NixOS/nixos-hardware

  options.modules.system.gpu.optimus-prime = {
    enable = mkEnableOption "optimus-prime";

    mode = mkOption {
      default = "offload";
      type = types.str;
      description = ''
        The mode to use for NVIDIA Optimus.
        Possible values are:
        - "sync": NVIDIA Sync mode
        - "reverse-sync": NVIDIA Reverse Sync mode
        - "offload": Adds a special boot entry for NVIDIA sync mode, defaults to offload mode
      '';
    };

    setDeviceIds = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Set the device IDs for NVIDIA Optimus.
        This is required for the modes to work.
        But may also be set using:
          https://github.com/NixOS/nixos-hardware
      '';
    };

    cpu = mkOption {
      default = "intel";
      type = types.str;
      description = ''
        The CPU to use for NVIDIA Optimus.
        Possible values are:
        - "intel": Intel CPU
        - "amd": AMD CPU
      '';
    };

    cpuId = mkOption {
      default = "PCI:0:0:0";
      type = types.str;
      description = ''
        The CPU ID to use for NVIDIA Optimus.
        This is required for the modes to work.
      '';
    };

    gpuId = mkOption {
      default = "PCI:1:0:0";
      type = types.str;
      description = ''
        The GPU ID to use for NVIDIA Optimus.
        This is required for the modes to work.
      '';
    };

    externalGpu = mkEnableOption "externalGpu";
  };

  config = mkMerge [

    # require nvidia module
    (mkIf cfg.enable { modules.system.gpu.nvidia.enable = true; })

    # (mkIf (cfg.enable && cfg.mode != "offload") { powerManagement.finegrained = true; })

    # sync
    (mkIf (cfg.enable && cfg.mode == "sync") { hardware.nvidia.prime.sync.enable = true; })

    # reverse-sync
    (mkIf (cfg.enable && cfg.mode == "reverse-sync") { 
      hardware.nvidia.prime.reverseSync.enable = true; 
      hardware.nvidia.prime.allowExternalGpu = cfg.externalGpu;
    })

    # offload
    (mkIf (cfg.enable && cfg.mode == "offload") {
      # hardware.nvidia.powerManagement.finegrained = true;

      hardware.nvidia.prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };

      # add a special boot entry NVIDIA Sync mode for gaming
      specialisation = {
        gaming.configuration = {
          programs.gamemode.enable = true;

          hardware.nvidia = {
            prime.sync.enable = lib.mkForce true;
            prime.offload = {
              enable = lib.mkForce false;
              enableOffloadCmd = lib.mkForce false;
            };
          };

        };
      };
    })

    # set device IDs for intel cpu and nvidia gpu
    (mkIf (cfg.enable && cfg.setDeviceIds && cfg.cpu == "intel") {
      hardware.nvidia.prime = {
        intelBusId = cfg.cpuId;
        nvidiaBusId = cfg.gpuId;
      };
    })

    # set device IDs for amd cpu and nvidia gpu
    (mkIf (cfg.enable && cfg.setDeviceIds && cfg.cpu == "amd") {
      hardware.nvidia.prime = {
        amdgpuBusId = cfg.cpuId;
        nvidiaBusId = cfg.gpuId;
      };
    })

  ];
}