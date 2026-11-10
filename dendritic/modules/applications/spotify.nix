{ config, inputs, ... }:
{
  flake.modules.nixos.spotify = {
    home-manager.sharedModules = [ config.flake.modules.homeManager.spotify ];
  };

  flake.modules.homeManager.spotify = { pkgs, ... }:
  let
    spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  in
  {
    imports = [ inputs.spicetify-nix.homeManagerModules.default ];

    programs.spicetify = {
      enable = true;
      theme = spicePkgs.themes.catppuccin;
      colorScheme = "macchiato";
      wayland = true;
      spotifyLaunchFlags = "--enable-features=UseOzonePlatform --ozone-platform=wayland";
    };
  };
}
