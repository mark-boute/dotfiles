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
    
    groups = mkOption {
      default = [];
      description = "extra groups";
    };

    shell = mkOption {
      default = pkgs.bash;
      description = "shell";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      users.users.${cfg.userName} = {
        isNormalUser = true;
        initialPassword = "hello";
        description = cfg.description;
        extraGroups = [] ++ optionals (cfg.sudoUser) [
          "networkmanager"
	        "wheel"
        ] ++ cfg.groups;
        shell = cfg.shell;
      };
    })
    (mkIf (cfg.shell == pkgs.zsh) {
      programs.zsh.enable = true;
      environment.shells = [ pkgs.zsh ];
      system.userActivationScripts.zshrc = "touch .zshrc";
    })
  ];
}
