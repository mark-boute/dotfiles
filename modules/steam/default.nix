{ inputs, pkgs, lib, config, ... }:

with lib; let 
  cfg = config.modules.steam;
in {

  options.modules.steam = { 

    enable = mkEnableOption "steam"; 

    setgamemode = mkOption {
      default = false;
      type = types.bool;
      description = "Enable gamemode. NOTE! This will override the gamemode setting in the optimus-prime module.";
    };

    addmangohud = mkOption {
      default = false;
      type = types.bool;
      description = "Add mangohud to the systemPackages.";
    };

    addprotonup = mkOption {
      default = false;
      type = types.bool;
      description = "Add protonup to the systemPackages.";
    };
  };

  config = mkMerge [
    ( mkIf cfg.enable {

      programs.steam.enable = true;
      programs.steam.gamescopeSession.enable = true;

      environment.systemPackages = with pkgs; [ 

      ] ++ optionals cfg.addmangohud [ mangohud ]
        ++ optionals cfg.addprotonup [ protonup ];

    })
    # seperate module for gamemode to allow for safe override
    ( mkIf (cfg.enable && cfg.setgamemode) {
      programs.gamemode.enable = true;
    })
    # seperate module for protonup session variable to allow for safe override
    ( mkIf (cfg.enable && cfg.addprotonup) {
      environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATH = "\${HOME}/.steam/root/compatibilitytools.d";
    })
  ];
}