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
    wayland.windowManager.hyprland.settings.bindd = [
      # General window management keybinds
      "$mod, x, Close window, closewindow"
      "$mod, q, Close window, killactive"
      "$mod, d, Toggle floating, togglefloating"
      "$mod, f, Toggle fullsreen, fullscreen, 0"


      # Change focus with keyboard
      "$mod, left, Focus window to the left, movefocus, l"
      "$mod, right, Focus window to the right, movefocus, r"
      "$mod, up, Focus window above, movefocus, u"
      "$mod, down, Focus window below, movefocus, d"

      # Move windows with keyboard
      "$mod ${cfg.keyboard-move-extra-key}, left, Move window to the left, movewindow, l"
      "$mod ${cfg.keyboard-move-extra-key}, right, Move window to the right, movewindow, r"
      "$mod ${cfg.keyboard-move-extra-key}, up, Move window up, movewindow, u"
      "$mod ${cfg.keyboard-move-extra-key}, down, Move window down, movewindow, d"

      # Cycle windows and bring new_active to top
      "$mod, Tab, Cycle to next window and move to top, cyclenext"
      "$mod, Tab, Cycle to next window and move to top, bringactivetotop"
    ];

    wayland.windowManager.hyprland.settings.binddm = [
      "$mod, mouse:272, Move window (LMB), movewindow"
      "$mod, mouse:273, Resize window (RMB), resizeactive"
    ];

    wayland.windowManager.hyprland.settings.binds.drag_threshold = 10;

    wayland.windowManager.hyprland.settings.binddc = [
      "$mod, mouse:272, Toggle floating, togglefloating"
    ];

    wayland.windowManager.hyprland.settings.bindde = [  # Repeat when held
      # Resize windows with keyboard
      "$mod ${cfg.keyboard-resize-extra-key}, left, Grow window left, resizeactive, -25 0"
      "$mod ${cfg.keyboard-resize-extra-key}, right, Grow window right, resizeactive, 25 0"
      "$mod ${cfg.keyboard-resize-extra-key}, up, Grow window up, resizeactive, 0 -25"
      "$mod ${cfg.keyboard-resize-extra-key}, down, Grow window down, resizeactive, 0 25"
    ];
  };
}