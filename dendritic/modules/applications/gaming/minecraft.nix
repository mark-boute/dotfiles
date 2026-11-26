{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.minecraft = {
    home-manager.sharedModules = [ homeManager.minecraft ];
  };

  flake.modules.homeManager.minecraft = { pkgs, ... }: {
    home.packages = with pkgs; [
      lunar-client
      prismlauncher
    ];
  };
}
