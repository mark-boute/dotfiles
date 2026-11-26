{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.spotify = {
    home-manager.sharedModules = [ homeManager.spotify ];
  };

  flake.modules.homeManager.spotify =
    { pkgs, ... }:
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
