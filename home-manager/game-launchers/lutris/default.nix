{pkgs, lib, config, ...}:

with lib; let
  cfg = config.modules.lutris;
in {
  options.modules.lutris = {
    enable = mkEnableOption "lutris";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      lutris
    ];
  };
}
