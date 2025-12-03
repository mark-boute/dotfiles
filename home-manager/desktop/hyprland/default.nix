{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.modules.hyprland;

  # importFilesToHome = to: folder: builtins.listToAttrs
  #   (map
  #     (file: {
  #       name = "${to}/${file}";
  #       value = { source = ./. + "/${folder}/${file}"; executable = true; };
  #     })
  #     (builtins.attrNames (builtins.readDir ./${folder}))
  #   );

  inherit (lib) mkEnableOption mkIf mkOption types;
in {
  imports = [
    ./shared
    ./cappuccino
  ];

  options.modules.hyprland = {
    enable = mkEnableOption "hyprland";

    configuration = mkOption {
      type = types.enum ["nord" "cappuccino"];
      default = "cappuccino";
      description = "configuration to use";
    };

    super-key = mkOption {
      type = types.str;
      default = "SUPER";
      description = "Key to use as super key.";
    };
  };

  config = mkIf cfg.enable {
    modules.hyprland.cappuccino.enable = true;

    programs.kitty.enable = true;

    wayland.windowManager.hyprland.enable = true;
    home.sessionVariables.NIXOS_OZONE_WL = "1";

    home.packages = with pkgs; [
      hyprpicker
      hyprlock
      hypridle
      hyprsunset
      hyprpolkitagent
      hyprlauncher

      pavucontrol # audio management
    ];

    wayland.windowManager.hyprland.systemd.variables = ["--all"];
    wayland.windowManager.hyprland.settings = {
      "$mod" = cfg.super-key;

      exec-once = [ "systemctl --user start hyprpolkitagent" ];
      env = [ "ELECTRON_OZONE_PLATFORM_HINT,wayland" ]; 

      # Move this to a seperate module if we want to expose options
      input = {
        # https://wiki.hypr.land/Configuring/Variables/#input

        # Keyboard
        kb_layout = "us";
        numlock_by_default = true;

        # Mouse
        follow_mouse = 2; # Click window to change focus

        # Touchpad
        scroll_method = "2fg"; # Two Fingers for scroll
        touchpad = {
          natural_scroll = true;
          drag_lock = 1; # Drag-lift with timeout
          clickfinger_behavior = true; # 1f:LMB, 2f: RMB, 3f: MMB
        };
      };

      cursor.no_hardware_cursors = 1;
      misc.disable_hyprland_logo = true;
    };

    # home.file = mkMerge [
    #   (importFilesToHome ".config/hypr/scripts" "scripts")
    #   (importFilesToHome ".config/hypr/" cfg.style)
    # ];
  };
}

