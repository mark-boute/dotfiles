{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.modules.gnome-settings;
  inherit (lib) mkEnableOption mkIf mkOption types;
in {
  imports = [
  ];

  options.modules.gnome-settings = {
    enable = mkEnableOption "gnome-settings";

    background-light = mkOption {
      type = types.str;
      default = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
      description = ''
        The URI of the background image in light mode.
      '';
    };

    background-dark = mkOption {
      type = types.str;
      default = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-d.svg";
      description = ''
        The URI of the background image in dark mode.
      '';
    };

    useCatppuccin = mkEnableOption "use catppuccin theme";
    catppuccinPallete = mkOption {
      type = types.enum ["latte" "frappe" "macchiato" "mocha"];
      default = "macchiato";
      description = ''
        The catppuccin pallete to use for the theme.
      '';
    };

    shellBlur = mkEnableOption "enable shell blur";
  };

  config = mkIf cfg.enable {
    gtk.enable = true;

    catppuccin = mkIf cfg.useCatppuccin {
      enable = true;
      flavor = cfg.catppuccinPallete;
      accent = "rosewater";
      gtk = {
        enable = true;
        gnomeShellTheme = true;
        flavor = cfg.catppuccinPallete;
        accent = "rosewater";
      };
    };

    home.packages = with pkgs;
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
        # gtk-theme = "Adwaita";
        color-scheme = "prefer-dark";
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

      # set background
      "org/gnome/desktop/background" = {
        color-shading-type = "solid";
        picture-options = "zoom";
        picture-uri = cfg.background-light;
        picture-uri-dark = cfg.background-dark;
        primary-color = "#241f31";
        secondary-color = "#000000";
      };

      # set screensaver
      "org/gnome/desktop/screensaver" = {
        color-shading-type = "solid";
        picture-options = "zoom";
        picture-uri = cfg.background-light;
        primary-color = "#241f31";
        secondary-color = "#000000";
      };

      "org/gnome/mutter" = {
        dynamic-workspaces = true;
        edge-tiling = true;
      };

      "org/gnome/desktop/wm/keybindings" = {
        move-to-workspace-1 = ["<Shift><Super>1"];
        move-to-workspace-2 = ["<Shift><Super>2"];
        move-to-workspace-3 = ["<Shift><Super>3"];
        move-to-workspace-4 = ["<Shift><Super>4"];

        switch-to-workspace-1 = ["<Super>1"];
        switch-to-workspace-2 = ["<Super>2"];
        switch-to-workspace-3 = ["<Super>3"];
        switch-to-workspace-4 = ["<Super>4"];

        toggle-fullscreen = ["<Super>f"];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        email = ["<Super>m"];
        decrease-text-size = ["<Control><Alt>minus"];
        increase-text-size = ["<Control><Alt>equal"];
        www = ["<Super>w"];
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
