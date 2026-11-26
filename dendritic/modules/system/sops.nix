{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  # secrets/<user>/<user>-secrets.yaml, decrypted with the user's age key
  flake.modules.nixos.sops =
    { config, ... }:
    let
      user = config.my.user.name;
    in
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      home-manager.sharedModules = [ homeManager.sops ];
      sops = {
        defaultSopsFile = ../../secrets + "/${user}/${user}-secrets.yaml";
        defaultSopsFormat = "yaml";
        age.keyFile = "/home/${user}/.config/sops/age/keys.txt";
      };
    };

  flake.modules.homeManager.sops = { osConfig, ... }: {
    imports = [ inputs.sops-nix.homeManagerModules.sops ];
    sops = {
      inherit (osConfig.sops) defaultSopsFile defaultSopsFormat;
      age.keyFile = osConfig.sops.age.keyFile;
    };
  };
}
