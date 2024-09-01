{ lib, config, pkgs, ... }:

with lib; let
  cfg = config.main-user;
in
{
  options.main-user = {
    enable = lib.mkEnableOption "enable user module";
    
    sudoUser = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "adds user to wheel and networkmanager groups";
    };

    userName = lib.mkOption {
      default = "mainuser";
      description = "username";
    };

    description = lib.mkOption {
      default = "Main User";
      description = "description";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.userName} = {
      isNormalUser = true;
      initialPassword = "hello";
      description = cfg.description;
      extraGroups = [] ++ lib.optionals (cfg.sudoUser) [
        "networkmanager"
	      "wheel"
      ];
    };
  };
}
