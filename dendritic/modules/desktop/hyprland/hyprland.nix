{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.hyprland = { pkgs, ... }: {
    home-manager.sharedModules = [ homeManager.hyprland ];

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      # nixpkgs builds hyprland with UWSM support, so this keeps it from cache.nixos.org.
      # Log in with the plain "Hyprland" GDM entry, not "Hyprland (uwsm-managed)".
      withUWSM = true;
    };

    xdg.portal = {
      enable = true;
      wlr.enable = false;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

      config = {
        common.default = [ "gtk" ];
        hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];

          "org.freedesktop.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.portal.OpenURI" = [ "gtk" ];

          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      };
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";

      NIXOS_XDG_OPEN_USE_PORTAL = "1";

      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      _JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };

  flake.modules.homeManager.hyprland =
    {
      config,
      osConfig,
      pkgs,
      ...
    }:
    {
      # configured through out-of-store symlinks to the lua files, not generated
      wayland.windowManager.hyprland.enable = false;

      xdg.configFile = builtins.listToAttrs (
        map (name: {
          name = "hypr/${name}";
          value.source = config.lib.file.mkOutOfStoreSymlink "${osConfig.my.live ./hypr}/${name}";
        }) (builtins.attrNames (builtins.readDir ./hypr))
      );

      home.sessionVariables = {
        NIXOS_OZONE_WL = "1";
      };

      programs = {
        kitty.enable = true;
        hyprshot = {
          enable = true;
          saveLocation = "$HOME/Pictures/Screenshots";
        };
      };

      home.packages =
        with pkgs;
        [
          pavucontrol
          pamixer
          brightnessctl

          hyprpwcenter
          hypridle
        ]
        ++ [
          inputs.hyprshutdown.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];

      # xdg-desktop-portal >=1.22 gates its unit on graphical-session.target (Requisite=),
      # but that target refuses manual starts and only activates via a compositor session
      # target binding to it (see wiki.hypr.land/Useful-Utilities/Systemd-start). Hyprland
      # itself doesn't create one, so without this, portals (incl. screen share) never start.
      systemd.user.targets.hyprland-session = {
        Unit = {
          Description = "hyprland compositor session";
          BindsTo = [ "graphical-session.target" ];
          Wants = [ "graphical-session-pre.target" ];
          After = [ "graphical-session-pre.target" ];
        };
      };

      services = {
        hyprsunset.enable = true;
        hyprpolkitagent.enable = true; # password prompts (pkexec, the system panel update)
        hypridle = {
          enable = true;
          settings = {
            general = {
              lock_cmd = ''hyprctl dispatch 'hl.dsp.global("quickshell:Lock")' '';
              # the dim listener's on-resume can be skipped while locked, leaving gamma at 50%
              unlock_cmd = "hyprctl hyprsunset gamma 100%";
              # after hibernate, DPMS-on alone leaves the PRIME (nvidia render ->
              # amdgpu scanout) handoff stale; reload forces Hyprland to
              # re-negotiate every output against the freshly resumed GPUs.
              after_sleep_cmd = ''hyprctl reload && hyprctl dispatch 'hl.dsp.dpms({ state = "on" })' '';
            };

            listener = [
              {
                # Dim screen after 5 minutes
                timeout = 300;
                on-timeout = "hyprctl hyprsunset gamma 50%";
                on-resume = "hyprctl hyprsunset gamma 100%";
              }
              {
                # Lock screen after 10 minutes (MUST happen before DPMS off)
                timeout = 600;
                on-timeout = ''hyprctl dispatch 'hl.dsp.global("quickshell:Lock")' '';
              }
              {
                # Turn off screen after 15 minutes (after lock is active)
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
