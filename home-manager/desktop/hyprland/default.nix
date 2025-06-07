{ pkgs, lib, config, ... }:

let 
  cfg = config.modules.hyprland;

  importFilesToHome = to: folder: builtins.listToAttrs 
    (map 
      (file: {
        name = "${to}/${file}"; 
        value = { source = ./. + "/${folder}/${file}"; executable = true; };
      }) 
      (builtins.attrNames (builtins.readDir ./${folder}))
    );

  inherit (lib) mkEnableOption mkIf mkOption mkMerge;
in {
  options.modules.hyprland = { 

    enable = mkEnableOption "hyprland"; 

    style = mkOption {
      default = "nord";
      description = "style to use";
    };

  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      wofi swaybg wlsunset wl-clipboard hyprland
    ];


    home.file = mkMerge [
      (importFilesToHome ".config/hypr/scripts" "scripts")
      (importFilesToHome ".config/hypr/" cfg.style)
    ];

  };
}