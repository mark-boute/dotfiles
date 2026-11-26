{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.development = { config, pkgs, ... }: {
    home-manager.sharedModules = [ homeManager.development ];

    environment.systemPackages = with pkgs; [
      nixfmt
      uv
      dotnetCorePackages.sdk_10_0
    ];

    virtualisation.docker.enable = true;
    virtualisation.docker.enableOnBoot = true;
    users.users.${config.my.user.name}.extraGroups = [ "docker" ];
  };

  flake.modules.homeManager.development = { pkgs, ... }: {
    home.packages = with pkgs; [
      nixd
      nix-inspect

      # cora dependencies
      z3
      jdk21
      gradle
    ];

    home.sessionVariables.JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
  };
}
