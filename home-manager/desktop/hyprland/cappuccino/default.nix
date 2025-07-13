{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.modules.hyprland.cappuccino;
  inherit (lib) mkEnableOption mkIf mkOption types mkForce;
in
{
  imports = [
    ./wallpaper.nix
    ./quickshell
  ];

  options.modules.hyprland.cappuccino = { 
    enable = mkEnableOption "Enable Cappucinno Hyprland configuration";

    catppuccinPallete = mkOption {
      type = types.enum [ "latte" "frappe" "macchiato" "mocha" ];
      default = "macchiato";
      description = ''
        The catppuccin pallete to use for the theme.
      '';
    };
  };

  config = mkIf cfg.enable {
    modules.hyprland.cappuccino.quickshell.enable = true;

    programs.kitty.settings = {
      confirm_os_window_close = 0;
      dynamic_background_opacity = true;
      window_padding_width = 10;
      background_opacity = "0.7";
      background_blur = 50;
    };

    catppuccin = mkForce {
      enable = true;
      flavor = cfg.catppuccinPallete;
      accent = "rosewater";
      kitty = {
        enable = true;
        flavor = cfg.catppuccinPallete;
      };
    };
  };
}