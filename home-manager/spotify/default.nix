{ config, inputs, lib, pkgs, ... }:

let 
  cfg = config.modules.spotify;
  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.spotify = { 
    enable = mkEnableOption "Spotify spicetify configuration file";
  };

  config = mkIf cfg.enable {
    programs.spicetify =
    let
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
    in
    {
      enable = true;
      theme = spicePkgs.themes.catppuccin;
      colorScheme = "macchiato";
      wayland = false;
    };
  };
}