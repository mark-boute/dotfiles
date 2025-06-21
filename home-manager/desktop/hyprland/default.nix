{ pkgs, lib, config, ... }:

let 
  cfg = config.modules.hyprland;

  # importFilesToHome = to: folder: builtins.listToAttrs 
  #   (map 
  #     (file: {
  #       name = "${to}/${file}"; 
  #       value = { source = ./. + "/${folder}/${file}"; executable = true; };
  #     }) 
  #     (builtins.attrNames (builtins.readDir ./${folder}))
  #   );

  inherit (lib) mkEnableOption mkIf mkOption types;
in {
  imports = [
    ./shared
  ];


  options.modules.hyprland = { 

    enable = mkEnableOption "hyprland"; 

    configuration = mkOption {
      type = types.enum [ "nord" "cappuccino" ];
      default = "cappuccino";
      description = "configuration to use";
    };

    super-key = mkOption {
      type = types.str;
      default = "SUPER";
      description = "Key to use as super key.";
    };

  };

  config = mkIf cfg.enable {

    programs.kitty.enable = true;
    wayland.windowManager.hyprland.enable = true;
    home.sessionVariables.NIXOS_OZONE_WL = "1";

    # home.packages = with pkgs; [
    #   hyprpicker
    # ];

    wayland.windowManager.hyprland.settings = {
      "$mod" = cfg.super-key;
      misc.disable_hyprland_logo = true;
    };

    # home.file = mkMerge [
    #   (importFilesToHome ".config/hypr/scripts" "scripts")
    #   (importFilesToHome ".config/hypr/" cfg.style)
    # ];

  };
}