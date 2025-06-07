{ pkgs, lib, config, ... }:

let 
  cfg = config.modules.development-tools.r;
  inherit (lib) mkEnableOption mkIf optionals;
in {

  options.modules.development-tools.r = { 
    enable = mkEnableOption "r"; 

    rstudio = mkEnableOption "rstudio"; 
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      R
      # chromium 
      pandoc
      rPackages.pagedown
      rPackages.ggplot2
      rPackages.dplyr
      rPackages.xts
    ] ++ optionals cfg.rstudio [ rstudio ];

  };
}
