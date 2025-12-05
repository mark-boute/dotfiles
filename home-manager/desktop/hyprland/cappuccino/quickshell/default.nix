{ config, pkgs, lib, ... }:

let
  cfg = config.modules.hyprland.cappuccino.quickshell;
  inherit (lib) mkEnableOption mkIf mkOption types;
in
{
  imports = [
  ];

  options.modules.hyprland.cappuccino.quickshell = { 
    enable = mkEnableOption "Enable Quickshell for Cappucinno";
    catppuccin-pallete = mkOption {
      type = types.enum [ "latte" "frappe" "macchiato" "mocha" ];
      default = "macchiato";
    };

  };

  config = mkIf cfg.enable {

    programs.quickshell = {
      enable = true;
      systemd.enable = true;
    };

    xdg.configFile."quickshell".source = ./cappuccino;

    home.pointerCursor = {
      enable = true;
      name = "catppuccin-macchiato-rosewater-cursors";
      package = pkgs.catppuccin-cursors.macchiatoRosewater;
      size = 24;
      hyprcursor = {
        enable = true;
        size = 24;
      };
      gtk.enable = true;
    };

    wayland.windowManager.hyprland.settings = {
      env = [ "HYPRCURSOR_THEME,rose-pine-hyprcursor" ];

      general = {
        gaps_in = "5";
        gaps_out = "0,5,5,5";
        gaps_workspaces = 50;

        # "col.active_border" = "rgba(125,196,228,1)";
        # "col.inactive_border" = "rgba(125,196,228,0.5)";

        "col.active_border" = "rgba(244,219,214,1)";
        "col.inactive_border" = "rgba(244,219,214,0.4)";

        border_size = 2;
        resize_on_border = true;

        snap.enabled = true;
      };

      decoration = {
        rounding = 15;

        shadow = {
          enabled = true;
          range = 4;
        };

        blur = {
          enabled = true;
          size = 5;
          passes = 2;
        };
      };

    };
  };
}