{ config, lib, ... }:

let 
  cfg = config.modules.hyprland.shared.keybinds.applications; 
  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.hyprland.shared.keybinds.applications = { 
    enable = mkEnableOption "Window management keybinds";

  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings.bindd = [
      "$mod, T, Open kitty terminal, exec, kitty"
      "$mod, W, Open browser, exec, zen"
    ];
  };
}