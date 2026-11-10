{ config, ... }:
{
  flake.modules.nixos.minecraft = {
    home-manager.sharedModules = [ config.flake.modules.homeManager.minecraft ];
  };

  flake.modules.homeManager.minecraft = { pkgs, ... }: {
    home.packages = with pkgs; [
      lunar-client
      prismlauncher
    ];
  };
}
