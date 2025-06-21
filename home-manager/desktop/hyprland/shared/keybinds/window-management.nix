{ config, lib, ... }:

let 
  cfg = config.modules.hyprland.shared.keybinds.window-management; 
  inherit (lib) mkEnableOption mkOption mkIf;
in {
  options.modules.hyprland.shared.keybinds.window-management = { 
    enable = mkEnableOption "Window management keybinds";

    keyboard-resize-extra-key = mkOption {
      type = lib.types.str;
      default = "ALT";
      description = "Key to use for resizing windows with keyboard: super-key + <value> + arrow-keys";
    };

    keyboard-move-extra-key = mkOption {
      type = lib.types.str;
      default = "SHIFT";
      description = "Key to use for moving windows with keyboard: super-key + <value> + arrow-keys";
    };

  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings.bind = [
      # General window management keybinds
      "$mod, x, closewindow"
      "$mod, q, killactive"
      "$mod, space, togglefloating"
      "$mod, f, fullscreen, 0"


      # Change focus with keyboard
      "$mod, left, movefocus, l"
      "$mod, right, movefocus, r"
      "$mod, up, movefocus, u"
      "$mod, down, movefocus, d"

      # Resize windows with keyboard
      "$mod ${cfg.keyboard-resize-extra-key}, left, resizeactive, -25 0"
      "$mod ${cfg.keyboard-resize-extra-key}, right, resizeactive, 25 0"
      "$mod ${cfg.keyboard-resize-extra-key}, up, resizeactive, 0 -25"
      "$mod ${cfg.keyboard-resize-extra-key}, down, resizeactive, 0 25"

      # Move windows with keyboard
      "$mod ${cfg.keyboard-move-extra-key}, left, movewindow, l"
      "$mod ${cfg.keyboard-move-extra-key}, right, movewindow, r"
      "$mod ${cfg.keyboard-move-extra-key}, up, movewindow, u"
      "$mod ${cfg.keyboard-move-extra-key}, down, movewindow, d"

      # Move/Resize windows with mouse (LMB for move, RMB for resize)
      "$mod, mouse_left, movewindow"
      "$mod, mouse_right, resizeactive"

    ];
  };
}