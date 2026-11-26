{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.gnome = { lib, ... }: {
    # set by hosts/users; the home side reads them via osConfig.my.gnome
    options.my.gnome = {
      wallpaper = lib.mkOption {
        type = lib.types.str;
        description = "GNOME wallpaper (light mode) and lock screen background, as a file:// URI.";
        default = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
      };
      wallpaperDark = lib.mkOption {
        type = lib.types.str;
        description = "GNOME wallpaper in dark mode, as a file:// URI.";
        default = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-d.svg";
      };
      preferLight = lib.mkEnableOption "the light color scheme (dark is the default)";
      shellBlur = lib.mkEnableOption "blur-my-shell blur on the panel, overview, lock screen and some apps";
    };

    config = {
      home-manager.sharedModules = [ homeManager.gnome ];

      services = {
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
        gnome.gnome-keyring.enable = true;
        libinput.enable = true;

        xserver.enable = true;
        xserver.xkb = {
          layout = "us";
          variant = "";
        };
      };

      programs.dconf.profiles.gdm.databases = [
        {
          settings."org/gnome/desktop/peripherals/keyboard".numlock-state = true;
        }
      ];
    };
  };

  flake.modules.homeManager.gnome =
    { osConfig, pkgs, ... }:
    let
      cfg = osConfig.my.gnome;
    in
    {
      gtk.enable = true;

      home.packages =
        with pkgs;
        [
          gnome-tweaks
        ]
        ++ (with pkgs.gnomeExtensions; [
          blur-my-shell
          appindicator
        ]);

      dconf.enable = true;
      dconf.settings = {
        "org/gnome/shell/extensions/blur-my-shell" = {
          "panel/blur" = cfg.shellBlur;
          "overview/blur" = cfg.shellBlur;
          "dash-to-dock/blur" = cfg.shellBlur;
          "lockscreen/blur" = cfg.shellBlur;

          "applications/blur" = cfg.shellBlur;
          "applications/sigma" = 15;
          "applications/brightness" = 1.0;
          "applications/dynamic-opacity" = false;
          "applications/opacity" = 150;
          "applications/whitelist" = [
            "org.gnome.Console"
            "org.gnome.Nautilus"
            "org.gnome.Settings"

            "sportify"
            "signal"
          ];
        };

        "org/gnome/desktop/interface" = {
          color-scheme = if cfg.preferLight then "prefer-light" else "prefer-dark";
          text-scaling-factor = 1.0;
        };

        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [
            "cloudflarewarpindicator@depscian.com"
            "cloudflare-warp-toggle@khaled.is-a.dev"
            "blur-my-shell@aunetx"
          ];
        };

        "org/gnome/desktop/background" = {
          color-shading-type = "solid";
          picture-options = "zoom";
          picture-uri = cfg.wallpaper;
          picture-uri-dark = cfg.wallpaperDark;
          primary-color = "#241f31";
          secondary-color = "#000000";
        };

        "org/gnome/desktop/screensaver" = {
          color-shading-type = "solid";
          picture-options = "zoom";
          picture-uri = cfg.wallpaper;
          primary-color = "#241f31";
          secondary-color = "#000000";
        };

        "org/gnome/mutter" = {
          dynamic-workspaces = true;
          edge-tiling = true;
        };

        "org/gnome/desktop/wm/keybindings" = {
          move-to-workspace-1 = [ "<Shift><Super>1" ];
          move-to-workspace-2 = [ "<Shift><Super>2" ];
          move-to-workspace-3 = [ "<Shift><Super>3" ];
          move-to-workspace-4 = [ "<Shift><Super>4" ];

          switch-to-workspace-1 = [ "<Super>1" ];
          switch-to-workspace-2 = [ "<Super>2" ];
          switch-to-workspace-3 = [ "<Super>3" ];
          switch-to-workspace-4 = [ "<Super>4" ];

          toggle-fullscreen = [ "<Super>f" ];
        };

        "org/gnome/settings-daemon/plugins/media-keys" = {
          email = [ "<Super>m" ];
          decrease-text-size = [ "<Control><Alt>minus" ];
          increase-text-size = [ "<Control><Alt>equal" ];
          www = [ "<Super>w" ];
          custom-keybinding = [
            "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0"
            "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1"
            "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2"
          ];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>t";
          command = "kgx";
          name = "Terminal";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          binding = "<Super>c";
          command = "code";
          name = "Code";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
          binding = "<Super>u";
          command = "authenticator";
          name = "Authenticator";
        };

        "org/gnome/desktop/peripherals/keyboard" = {
          numlock-state = true;
        };
      };
    };
}
