{ config, lib, pkgs, inputs, ... }:

let 
  cfg = config.modules.hyprland.shared.keybinds.applications; 
  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.hyprland.shared.keybinds.hardware-control = { 
    enable = mkEnableOption "Hardware control keybinds";
  };

  config = mkIf cfg.enable {

    services.hyprsunset.enable = true;
    home.packages = [
      # audio control
      pkgs.pavucontrol
      pkgs.pamixer

      # hyprshutdown  # wait for nixos release
      inputs.hyprshutdown.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    wayland.windowManager.hyprland.settings = {
      bindo = [
        # Reboot and Shutdown
        "SUPERSHIFT,Delete,exec,hyprshutdown -t 'Restarting...' --post-cmd 'reboot'"
        "SUPER,Delete,exec,hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'"
      ];

      bindlde = [
        # Volume Control
        ",XF86AudioRaiseVolume,Increase volume,exec,pamixer --increase 5"
        ",XF86AudioLowerVolume,Decrease volume,exec,pamixer --decrease 5"
        ",XF86AudioMute,Mute audio,exec,pamixer --toggle-mute"

        # Brightness and Color Temperature Control
        "SUPER,XF86MonBrightnessUp, Increase temperature, exec, hyprctl hyprsunset temperature +250"
        "SUPER,XF86MonBrightnessDown, Decrease temperature, exec, hyprctl hyprsunset temperature -250"
        ",XF86MonBrightnessUp, Increase gamma, exec, hyprctl hyprsunset gamma +10"
        ",XF86MonBrightnessDown, Decrease gamma, exec, hyprctl hyprsunset gamma -10"
      ];
    };
  };
}
