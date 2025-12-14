{ config, lib, pkgs, ... }:

let
  cfg = config.modules.hyprland.cappuccino;
  inherit (lib) mkIf;
in
{
  # options.modules.hyprland.cappuccino.theme = { 
  #   enable = mkEnableOption "Cappuccino Hyprland theme settings";
  # };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      hyprtoolkit
      hyprlauncher
    ];
    
    programs.kitty.settings = {
      confirm_os_window_close = 0;
      dynamic_background_opacity = true;
      window_padding_width = 10;
      background_opacity = "0.7";
      background_blur = 50;
    };


    wayland.windowManager.hyprland.settings.exec-once = [ "hyprlauncher -d" ];

  };
}