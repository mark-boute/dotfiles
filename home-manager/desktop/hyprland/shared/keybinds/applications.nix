{ config, lib, ... }:

let 
  cfg = config.modules.hyprland.shared.keybinds.applications; 
  inherit (lib) mkEnableOption mkOption mkIf;
in {
  options.modules.hyprland.shared.keybinds.applications = { 
    enable = mkEnableOption "Window management keybinds";

  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings.bind = [
      # terminal
      "$mod, T, exec, kitty"
      # browser
      "$mod, W, exec, zen"
    ];
  };
}