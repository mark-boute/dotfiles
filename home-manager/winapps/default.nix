{ config, main-user, lib, ... }:

let 
  cfg = config.modules.winapps; 
  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.winapps = { 
    enable = mkEnableOption "Winapps configuration file";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      winapps = {
        sopsFile = ../../secrets/${main-user}/winapps.env;
        format = "dotenv";
      };
    };

    home.file."winapps-config-file" = {
      target = ".config/winapps/winapps.conf";
      source = config.lib.file.mkOutOfStoreSymlink config.sops.secrets.winapps.path;      
    };
  };
}