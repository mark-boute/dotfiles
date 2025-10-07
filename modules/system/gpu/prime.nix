{ config, lib, inputs, ... }:

let 
  cfg = config.modules.system.gpu.optimus-prime;
  hardware-modules = inputs.nixos-hardware.nixosModules;
  inherit (lib) mkEnableOption mkIf mkOption types mkForce mkMerge;
in {
  # This needs device IDs to be set! See:
  # https://github.com/vimjoyer/nixos-gaming-video
  # and if possible:
  # https://github.com/NixOS/nixos-hardware

  options.modules.system.gpu.optimus-prime = {
    enable = mkEnableOption "optimus-prime";

    mode = mkOption {
      default = "";
      type = types.enum [ "" "sync" "reverse-sync" "offload" ];
      description = ''
        The mode to use for NVIDIA Optimus.
        Possible values are:
        - "": All options enabled as boot entries
        - "sync": NVIDIA Sync mode
        - "reverse-sync": NVIDIA Reverse Sync mode
        - "offload": Adds a special boot entry for NVIDIA sync mode, defaults to offload mode
      '';
    };

    open = mkEnableOption "open";
    powerManagement = mkEnableOption "powerManagement";
    finegrained = mkEnableOption "finegrained";

    setDeviceIds = mkEnableOption "setDeviceIds";

    cpu = mkOption {
      default = "intel";
      type = types.enum [ "intel" "amd" ];
      description = ''
        The CPU to use for NVIDIA Optimus.
        Possible values are:
        - "intel": Intel CPU
        - "amd": AMD CPU
      '';
    };

    integratedGraphicsId = mkOption {
      default = "PCI:6:0:0";
      type = types.str;
      description = ''
        The IntegradedGPU ID to use for NVIDIA Optimus.
        This is required for the modes to work.
      '';
    };

    dedicatedGraphicsId = mkOption {
      default = "PCI:1:0:0";
      type = types.str;
      description = ''
        The GPU ID to use for NVIDIA Optimus.
        This is required for the modes to work.
      '';
    };

    externalGpu = mkEnableOption "externalGpu";

    nvidiaPackage = mkOption {
      type = types.package;
      default = config.boot.kernelPackages.nvidiaPackages.production;
      description = "The Nvidia driver package to use.";
    };
  };

  config = mkMerge [

    # add correct cpu videodriver module
    (mkIf (cfg.enable && cfg.cpu == "intel") { 
      services.xserver.videoDrivers = [ "modesetting" ];
    })
    (mkIf (cfg.enable && cfg.cpu == "amd") { 
      services.xserver.videoDrivers = [ "amdgpu" ];
    })

    # require nvidia module
    (mkIf cfg.enable { 
      modules.system.gpu.nvidia = {
        enable = true;
        open = cfg.open;
        powerManagement = cfg.powerManagement;
        nvidiaPackage = cfg.nvidiaPackage;
      };
    })

    # no specification
    (mkIf (cfg.enable && cfg.mode == "") {
      specialisation = {
        prime.configuration = {
          imports = [ hardware-modules.common-gpu-nvidia ];
          modules.system.gpu.nvidia.finegrained = cfg.finegrained;
        };
        prime-sync.configuration = {
          imports = [ hardware-modules.common-gpu-nvidia-sync ];

          # fix slowness after waking up from sleep 
          # (this mode's main use is for high performance use anyways)
          modules.system.gpu.nvidia.powerManagement = mkForce false;
          modules.system.gpu.nvidia.finegrained = mkForce false;
        };
        no-prime.configuration = {
          imports = [ hardware-modules.common-gpu-nvidia-nonprime ];
        };
        iGPU.configuration = {
          imports = [ hardware-modules.common-gpu-nvidia-disable ];
          modules.system.gpu.nvidia = { 
            enable = mkForce false;
            open = mkForce false;
            powerManagement = mkForce false;
            finegrained = mkForce false;
          };
        };
      };
    })

    # sync
    (mkIf (cfg.enable && cfg.mode == "sync") { hardware.nvidia.prime.sync.enable = true; })

    # reverse-sync
    (mkIf (cfg.enable && cfg.mode == "reverse-sync") { 
      hardware.nvidia.prime.reverseSync.enable = true; 
      hardware.nvidia.prime.allowExternalGpu = cfg.externalGpu;
    })

    # offload
    (mkIf (cfg.enable && cfg.mode == "offload") {

      hardware.nvidia.prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };

      # hardware.nvidia.powerManagement.finegrained = mkDefault true;

      # add a special boot entry NVIDIA Sync mode for gaming
      specialisation = {
        gaming.configuration = {
          programs.gamemode.enable = true;

          hardware.nvidia.powerManagement.finegrained = false;
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
        intelBusId = cfg.integratedGraphicsId;
        nvidiaBusId = cfg.dedicatedGraphicsId;
      };
    })

    # set device IDs for amd cpu and nvidia gpu
    (mkIf (cfg.enable && cfg.setDeviceIds && cfg.cpu == "amd") {
      hardware.nvidia.prime = {
        amdgpuBusId = cfg.integratedGraphicsId;
        nvidiaBusId = cfg.dedicatedGraphicsId;
      };
    })

  ];
}