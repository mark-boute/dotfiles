{ inputs, lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.eww;

    importFiles = folder: builtins.listToAttrs 
      (map 
        (file: {
          name = ".config/eww/${folder}/${file}"; 
          value = { source = ./. + "/${folder}/${file}"; executable = true; };
        }) 
        (builtins.attrNames (builtins.readDir ./${folder}))
      );

    importFolders = folders: lib.mkMerge (map importFiles folders);
in {
    options.modules.eww = { 
      enable = mkEnableOption "eww"; 
    };

    config = mkIf cfg.enable {
      
      # eww packages
      home.packages = with pkgs; [
        eww
        pamixer
        brightnessctl
        (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
      ];

      # configuration
      home.file = lib.mkMerge [
        (importFolders [ 
          "assets"
          "css"
          "modules"
          "scripts" 
          "windows" 
        ])
        {
          ".config/eww/eww.scss".source = ./eww.scss;
          ".config/eww/eww.yuck".source = ./eww.yuck;
        }
      ];

    };
}