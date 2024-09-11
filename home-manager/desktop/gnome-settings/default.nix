{ inputs, pkgs, lib, config, ... }:

with lib; let 
  cfg = config.modules.gnome-settings;

in {
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

  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      
    ];
  dconf.enable = true;
    dconf.settings = {

      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        text-scaling-factor = 1.20;
      };
        
      # set background
      "org/gnome/desktop/background" = {
        color-shading-type = "solid";
        picture-options = "zoom";
        picture-uri = background-light;
        picture-uri-dark = background-dark;
        primary-color = "#241f31";
        secondary-color = "#000000";
      };

      # set screensaver
      "org/gnome/desktop/screensaver" = {
        color-shading-type = "solid";
        picture-options = "zoom";
        picture-uri = background-light;
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
        decrease-text-size = [ "<Control><Alt>minus" ];
        increase-text-size = [ "<Control><Alt>equal" ];
        www = [ "<Super>w" ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Super>t";
        command = "kgx";
        name = "Terminal";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        binding = "<Super>e";
        command = "nautilus";
        name = "Files";
      };

      "org/gnome/desktop/peripherals/keyboard" = {
        numlock-state = true;
      };
    };
  };
}