{pkgs, lib, config, ...}:

let
  cfg = config.modules.lutris;
  inherit (lib) mkEnableOption mkIf;
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
