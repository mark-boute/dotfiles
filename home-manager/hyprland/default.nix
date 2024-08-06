{ inputs, pkgs, lib, config, ... }:

with lib;

let 
  cfg = config.modules.hyprland;
in {
  options.modules.hyprland= { 

    enable = mkEnableOption "hyprland"; 

    style = lib.mkOption {
      default = "nord";
      description = "style to use";
    };

  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      wofi swaybg wlsunset wl-clipboard hyprland
    ];

    home.file.".config/hypr/hyprland.conf".source = ./${cfg.style}/hyprland.conf;

  };
}