{ config, lib, main-user, ... }:

let 
  cfg = config.modules.sops; 
  inherit (lib) mkEnableOption mkIf;
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