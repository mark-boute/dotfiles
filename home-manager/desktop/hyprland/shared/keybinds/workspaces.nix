{ config, lib, ... }:

let 
  cfg = config.modules.hyprland.shared.keybinds.workspaces;
  inherit (lib) mkEnableOption mkOption mkMerge mkIf;
in {
  options.modules.hyprland.shared.keybinds.workspaces = { 
    enable = mkEnableOption "Workspace keybinds";

    enable-scroll-workspace = mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable scrolling through workspaces.";
    };

    move-workspace-key = mkOption {
      type = lib.types.str;
      default = "SHIFT";
      description = "Key to use for moving windows to workspaces.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {

      wayland.windowManager.hyprland.settings.bind = (
        builtins.concatLists (builtins.genList (i:
            let workspace = i + 1;
            in [
              "$mod, code:1${toString i}, workspace, ${toString workspace}"
              "$mod ${cfg.move-workspace-key}, code:1${toString i}, movetoworkspacesilent, ${toString workspace}"
            ]
          )
          9)
      );

      wayland.windowManager.hyprland.settings.gestures = {
        gesture = "3, horizontal, workspace";
      };

    })
    (mkIf (cfg.enable && cfg.enable-scroll-workspace) {
      wayland.windowManager.hyprland.settings.bindd = [
        "$mod, mouse_up, Move to next workspace, workspace, e+1"
        "$mod, mouse_down, Move to previous workspace, workspace, e-1"
      ];
    })
  ];
}