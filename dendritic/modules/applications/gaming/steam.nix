{
  flake.modules.nixos.steam = { pkgs, ... }: {
    programs.steam.enable = true;
    programs.steam.gamescopeSession.enable = true;

    environment.systemPackages = [ pkgs.protonup-ng ];
    environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATH = "\${HOME}/.steam/root/compatibilitytools.d";
  };

  flake.modules.nixos.mangohud = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.mangohud ];
    # inside Steam's FHS env too, so `mangohud %command%` and MANGOHUD=1 find the Vulkan layer
    programs.steam.extraPackages = [ pkgs.mangohud ];
  };

  flake.modules.nixos.gamemode = {
    programs.gamemode.enable = true;
  };
}
