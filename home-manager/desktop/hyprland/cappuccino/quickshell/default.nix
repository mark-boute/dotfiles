{ config, pkgs, lib, ... }:

let
  cfg = config.modules.hyprland.cappuccino.quickshell;
  inherit (lib) mkEnableOption mkIf mkOption types;
in
{
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

    # Symlink to the quickshell config folder.
    xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/home-manager/desktop/hyprland/cappuccino/quickshell";

    xdg.configFile."hypr/qs-config.lua".text = ''
      return "cappuccino"
    '';

    home.pointerCursor = lib.mkForce {
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
  };
}