{ inputs, pkgs, lib, config, ... }:

with lib; let 
  cfg = config.modules.steam;
in {

  options.modules.steam = { 

    enable = mkEnableOption "steam"; 

    setgamemode = mkOption {
      default = false;
      description = "Enable gamemode. NOTE! This will override the gamemode setting in the optimus-prime module.";
    };

  };

  config = mkIf cfg.enable {

    programs.steam.enable = true;
    programs.steam.gamescopeSession.enable = true;


    # home.packages = with pkgs; [
    #   mangohud
    # ];

  };
}