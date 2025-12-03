{ config, ... }:

let
  wallpaper-2560x1600 = config.lib.file.mkOutOfStoreSymlink ./assets/coffee_pixel_art_2560x1600.png;
  wallpaper-2560x1080 = config.lib.file.mkOutOfStoreSymlink ./assets/coffee_pixel_art_2560x1080.png;
  wallpaper-3440x1440 = config.lib.file.mkOutOfStoreSymlink ./assets/coffee_pixel_art_3440x1440.png;
in
{
  config = {
    services.hyprpaper = {
      enable = true;
      settings = {
        ipc = true;

        # Set Wallpaper
        preload = [
          "${wallpaper-3440x1440}"
          "${wallpaper-2560x1600}"
        ];
        wallpaper = [
          "HDMI-A-1, contain:${wallpaper-3440x1440}"
          "desc:California Institute of Technology 0x1637 0x00006000, contain:${wallpaper-2560x1600}"
        ];
      };
    };
  };
}