{ config, pkgs, lib, inputs, ... }:

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

    home.packages = with pkgs; [
    ] ++ [
      inputs.quickshell.packages.${pkgs.system}.default
    ];

    home.pointerCursor = {
      enable = true;
      name = "catppuccin-macchiato-rosewater-cursors";
      package = pkgs.catppuccin-cursors.macchiatoRosewater;
      # name = "rose-pine-hyprcursor";
      # package = inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default;
      size = 24;
      hyprcursor = {
        enable = true;
        size = 24;
      };
      gtk.enable = true;
    };

    # instead of using the default config-path (~/.config/quickshell/), read directly from nix-store
    wayland.windowManager.hyprland.settings = { 
      exec-once = "qs -p ${builtins.toString ./.}";  # quickshell
      env = "HYPRCURSOR_THEME,rose-pine-hyprcursor";
    };
  };
}