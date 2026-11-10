{ config, ... }:
{
  flake.modules.nixos.networking = { pkgs, ... }: {
    home-manager.sharedModules = [ config.flake.modules.homeManager.networking ];

    networking.networkmanager = {
      enable = true;
      settings = {
        device."wifi.scan-rand-mac-address" = "no";
        connection."wifi.cloned-mac-address" = "permanent";
      };
      plugins = [ pkgs.networkmanager-openvpn ]; # EduVPN
    };

    services.cloudflare-warp.enable = true;
  };

  flake.modules.homeManager.networking = { pkgs, ... }: {
    home.packages = [ pkgs.eduvpn-client ];
  };
}
