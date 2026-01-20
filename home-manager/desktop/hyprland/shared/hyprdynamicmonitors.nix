{ config, lib, inputs, ... }:

let 
  cfg = config.modules.hyprland.shared.hyprdynamicmonitors; 
  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.hyprland.shared.hyprdynamicmonitors = { 
    enable = mkEnableOption "HyprDynamicMonitors integration";
  };

  imports = [ inputs.hyprdynamicmonitors.homeManagerModules.default ];

  config = mkIf cfg.enable {

    home.hyprdynamicmonitors = {
      enable = true;
    };
  };
}