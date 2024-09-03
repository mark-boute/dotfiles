{ pkgs, lib, ... }:

{
  # This needs device IDs to be set! See:
  # https://github.com/vimjoyer/nixos-gaming-video
  # and if possible:
  # https://github.com/NixOS/nixos-hardware

  hardware.nvidia.open = true;
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

}