{ inputs, pkgs, lib, config, ... }:

with lib; let 
  cfg = config.modules.gnome-settings;

in {
  options.modules.gnome-settings = { 

    enable = mkEnableOption "gnome-settings"; 

  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      
    ];
  dconf.enable = true;
    dconf.settings = {

      "/org/gnome/desktop" = {
        # dark theme
        interface = {
          color-scheme = "prefer-dark";
          text-scaling-factor = 1.2;
        };
        
        # set background
        background = {
          color-shading-type = "solid";
          picture-options = "zoom";
          picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
          picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-d.svg";
          primary-color = "#241f31";
          secondary-color = "#000000";
        };

        # set screensaver
        screensaver = {
          color-shading-type = "solid";
          picture-options = "zoom";
          picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
          primary-color = "#241f31";
          secondary-color = "#000000";
        };

        "wm/keybindings/toggle-fullscreen" = ["<Super>f"];
      };

      "/org/gnome/settings-daemon/plugins/media-keys" = {
        www = ["<Super>w"];

        terminal = [ "<Super>t" ];

        decrease-text-size = [ "<Control><Alt>minus" ];
        increase-text-size = [ "<Control><Alt>equal" ];


        # workspace navigation
        switch-to-workspace-1 = ["<Super>1"];
        switch-to-workspace-2 = ["<Super>2"];
        switch-to-workspace-3 = ["<Super>3"];
        switch-to-workspace-4 = ["<Super>4"];
        switch-to-workspace-5 = ["<Super>5"];

        move-to-workspace-1 = ["<Super><Shift>1"];
        move-to-workspace-2 = ["<Super><Shift>2"];
        move-to-workspace-3 = ["<Super><Shift>3"];
        move-to-workspace-4 = ["<Super><Shift>4"];
        move-to-workspace-5 = ["<Super><Shift>5"];

      };

      "org/gnome/desktop/peripherals/keyboard" = {
        numlock-state = true;
      };

      "org/gnome/desktop/interface" = {
        clock-show-date = "true";
        clock-show-seconds = "true";
      };


    };

  };
}