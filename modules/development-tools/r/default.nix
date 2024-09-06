{ inputs, pkgs, lib, config, ... }:

with lib; let 
  cfg = config.modules.development-tools.r;
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
