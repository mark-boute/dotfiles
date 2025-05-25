{ config, lib, main-user, ... }:

with lib; let 
  cfg = config.modules.sops; 

in {
  options.modules.sops = { 
    enable = mkEnableOption "SOPS";
  };

  config = mkIf cfg.enable {
    sops = {
      defaultSopsFile = ../../secrets/${main-user}/${main-user}-secrets.yaml;
      defaultSopsFormat = "yaml";
      age.keyFile = "/home/${main-user}/.config/sops/age/keys.txt";
    };
  };    
}