{ pkgs, lib, config, ... }:

with lib; let 
  cfg = config.modules.hyprland;

  importFilesToHome = to: folder: builtins.listToAttrs 
    (map 
      (file: {
        name = "${to}/${file}"; 
        value = { source = ./. + "/${folder}/${file}"; executable = true; };
      }) 
      (builtins.attrNames (builtins.readDir ./${folder}))
    );

  # importFoldersToHome = to: folders: mkMerge (map (importFilesToHome to) folders);

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