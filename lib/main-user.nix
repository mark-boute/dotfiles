{ lib, config, pkgs, ... }:

with lib; let
  cfg = config.main-user;
in
{
  options.main-user = {
    enable = mkEnableOption "enable user module";
    
    sudoUser = mkOption {
      type = types.bool;
      default = false;
      description = "adds user to wheel and networkmanager groups";
    };

    userName = mkOption {
      default = "mainuser";
      description = "username";
    };

    description = mkOption {
      default = "Main User";
      description = "description";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.userName} = {
      isNormalUser = true;
      initialPassword = "hello";
      description = cfg.description;
      extraGroups = [] ++ optionals (cfg.sudoUser) [
        "networkmanager"
	      "wheel"
      ];
    };
  };
}
