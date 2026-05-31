{ config, lib, ... }:

let
  cfg = config.modules.hyprland.cappuccino;
  inherit (lib) mkEnableOption mkIf mkOption types mkForce;
in
{
  imports = [
    ./quickshell
    ./theme.nix
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