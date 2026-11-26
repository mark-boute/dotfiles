{ inputs, ... }:
{
  # Aspects that have a home side add it via home-manager.sharedModules,
  # so importing the NixOS aspect is enough to get both halves.
  flake.modules.nixos.home-manager = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      backupFileExtension = "backup";
      useUserPackages = true;
      useGlobalPkgs = true;
    };
  };
}
