{ config, ... }:
{
  # legion's monitors, GPU env and autostart, loaded by hyprland.lua's try_require
  flake.modules.nixos.legion-hyprland = {
    home-manager.sharedModules = [ config.flake.modules.homeManager.legion-hyprland ];
  };

  flake.modules.homeManager.legion-hyprland = { config, osConfig, ... }: {
    xdg.configFile = builtins.listToAttrs (
      map (name: {
        name = "hypr/${name}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${osConfig.my.live ./hypr}/${name}";
      })
      (builtins.attrNames (builtins.readDir ./hypr))
    );
  };
}
