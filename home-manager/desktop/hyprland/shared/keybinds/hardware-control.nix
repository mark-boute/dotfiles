{ config, lib, pkgs, ... }:

let 
  cfg = config.modules.hyprland.shared.keybinds.applications; 
  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.hyprland.shared.keybinds.hardware-control = { 
    enable = mkEnableOption "Hardware control keybinds";

  };

  config = mkIf cfg.enable {

    services.hyprsunset.enable = true;

    home.packages = with pkgs; [
      pamixer
    ];

    wayland.windowManager.hyprland.settings = {
      bindo = [
        # Long press $mod + SHIFT + del to reboot system
        "SUPERSHIFT,del,exec,hyprshutdown -t 'Restarting...' --post-cmd 'reboot'"
      ];

      bind = [
        # Long press $mod + del to shutdown system
        "SUPER,del,exec,hyprshutdown -t 'Shutting down...' --post-cmd 'poweroff'"
      ];

      bindlde = [
        ",XF86AudioRaiseVolume,Increase volume,exec,pamixer --increase 5"
        ",XF86AudioLowerVolume,Decrease volume,exec,pamixer --decrease 5"
        ",XF86AudioMute,Mute audio,exec,pamixer --toggle-mute"

        "SUPER,XF86MonBrightnessUp, Increase temperature, exec, hyprctl hyprsunset temperature +250"
        "SUPER,XF86MonBrightnessDown, Decrease temperature, exec, hyprctl hyprsunset temperature -250"
        ",XF86MonBrightnessUp, Increase gamma, exec, hyprctl hyprsunset gamma +10"
        ",XF86MonBrightnessDown, Decrease gamma, exec, hyprctl hyprsunset gamma -10"
      ];
    };
  };
}
