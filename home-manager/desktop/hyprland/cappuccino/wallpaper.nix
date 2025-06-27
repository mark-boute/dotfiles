{ config, ... }:

let
  wallpaper-2560x1600 = config.lib.file.mkOutOfStoreSymlink ./assets/coffee_pixel_art_2560x1600.png;
  wallpaper-2560x1080 = config.lib.file.mkOutOfStoreSymlink ./assets/coffee_pixel_art_2560x1080.png;
in
{
  config = {
    services.hyprpaper = {
      enable = true;
      settings = {
        ipc = "off";

        # Set Wallpaper
        preload = [
          "${wallpaper-2560x1080}"
          "${wallpaper-2560x1600}"
        ];
        wallpaper = [
          "HDMI-A-1, contain:${wallpaper-2560x1080}"
          "eDP-1, contain:${wallpaper-2560x1600}"
        ];
      };
    };
  };
}