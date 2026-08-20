{ config, lib, pkgs, ... }:

let
  cfg = config.modules.hyprland.resonate;
  inherit (lib) mkEnableOption mkIf mkForce;
in
{
  options.modules.hyprland.resonate = {
    enable = mkEnableOption "Enable the Resonate quickshell system";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      hyprtoolkit
      hyprlauncher
    ];

    catppuccin = mkForce {
      enable = true;
      flavor = "macchiato";
      accent = "rosewater";
      kitty = {
        enable = true;
        flavor = "macchiato";
      };
    };

    programs.quickshell = {
      enable = true;
      systemd.enable = true;
    };

    programs.kitty.settings = {
      confirm_os_window_close = 0;
      dynamic_background_opacity = true;
      window_padding_width = 10;
      background_opacity = "0.7";
      background_blur = 50;
    };

    # Symlink just this shell's own subdirectory under ~/.config/quickshell,
    # so it can live alongside other quickshell configs (e.g. cappuccino)
    # without either fighting over the whole ~/.config/quickshell symlink.
    xdg.configFile."quickshell/resonate".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/home-manager/desktop/hyprland/resonate";

    xdg.configFile."hypr/qs-config.lua".text = ''
      return "resonate"
    '';
  };
}
