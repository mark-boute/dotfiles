{pkgs, lib, config, ...}:
let
  cfg = config.modules.heroic;
  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.heroic = {
    enable = mkEnableOption "heroic";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      heroic
    ];
  };
}