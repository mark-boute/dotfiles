{ config, lib, pkgs, ... }:

let
  cfg = config.modules.hyprland.cappuccino;
  inherit (lib) mkIf;

  wallpaper = {
    "2560x1600" = config.lib.file.mkOutOfStoreSymlink ./assets/coffee_pixel_art_2560x1600.png;
    "2560x1080" = config.lib.file.mkOutOfStoreSymlink ./assets/coffee_pixel_art_2560x1080.png;
    "3440x1440" = config.lib.file.mkOutOfStoreSymlink ./assets/coffee_pixel_art_3440x1440.png;
  };
in
{
  config = mkIf cfg.enable {
    services.hyprpaper = {
      enable = false;
      settings = {
        ipc = true;

        # Set Wallpaper
        preload = [
          "${wallpaper."3440x1440"}"
          "${wallpaper."2560x1600"}"
        ];
        wallpaper = [
          "HDMI-A-1, ${wallpaper."3440x1440"}"
          "desc:California Institute of Technology 0x1637 0x00006000, ${wallpaper."2560x1600"}"
        ];
      };
    };
  };
}