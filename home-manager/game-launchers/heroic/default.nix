{pkgs, lib, config, ...}:
with lib; let
  cfg = config.modules.heroic;
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