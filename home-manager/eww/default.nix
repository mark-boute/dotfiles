{ inputs, lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.eww;

    importFilesToHome = to: folder: builtins.listToAttrs 
      (map 
        (file: {
          name = "${to}/${folder}/${file}"; 
          value = { source = ./. + "/${folder}/${file}"; executable = true; };
        }) 
        (builtins.attrNames (builtins.readDir ./${folder}))
      );

    importFoldersToHome = to: folders: lib.mkMerge (map (importFilesToHome to) folders);
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
        (importFoldersToHome ".config/eww" [ 
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