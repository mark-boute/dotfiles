{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.modules.hyprland;
  inherit (lib) mkEnableOption mkIf;
  hyprDir = "${config.home.homeDirectory}/dotfiles/home-manager/desktop/hyprland/hypr";
in {
  imports = [
    ./cappuccino
  ];

  options.modules.hyprland = {
    enable = mkEnableOption "hyprland";
  };

  config = mkIf cfg.enable {

    # configuration will be done with symlinks to dotfiles, so disable the default config generation
    wayland.windowManager.hyprland.enable = false;

    xdg.configFile = builtins.listToAttrs (
      map (name: {
        name = "hypr/${name}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${hyprDir}/${name}";
      }) 
      (builtins.attrNames (builtins.readDir ./hypr))
    );

    programs = {
      kitty.enable = true;
      hyprshot = {
        enable = true;
        saveLocation = "$HOME/Pictures/Screenshots";
      };
    };

    home.packages = with pkgs; [
      pavucontrol
      pamixer
      brightnessctl

      hyprpwcenter
      hypridle
      hyprpolkitagent
    ] ++ [
      inputs.hyprshutdown.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Based on: https://gitlab.com/nicky.tope/nixos-config/-/blob/main/user/desktop/hyprland/default.nix?ref_type=heads
    services = {
      hyprsunset.enable = true;
      hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = ''hyprctl dispatch 'hl.dsp.global("quickshell:Lock")' '';
            after_sleep_cmd = ''hyprctl dispatch 'hl.dsp.dpms({ state = "on" })' '';
          };

          listener = [
            { # Dim screen after 5 minutes
              timeout = 300;
              on-timeout = "hyprctl hyprsunset gamma 50%";
              on-resume = "hyprctl hyprsunset gamma 100%";
            }
            { # Lock screen after 10 minutes (MUST happen before DPMS off)
              timeout = 600;
              on-timeout = ''hyprctl dispatch 'hl.dsp.global("quickshell:Lock")' '';
            }
            { # Turn off screen after 15 minutes (after lock is active)
              timeout = 900;
              on-timeout = ''hyprctl dispatch 'hl.dsp.dpms({ state = "off" })' '';
              on-resume = ''hyprctl dispatch 'hl.dsp.dpms({ state = "on" })' '';
            }
          ];
        };
      };
    };
  };
}

