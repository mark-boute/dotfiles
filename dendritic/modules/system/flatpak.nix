{ inputs, ... }:
{
  flake.modules.nixos.flatpak = { lib, ... }: {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak = {
      enable = true;
      remotes = lib.mkOptionDefault [
        {
          name = "flathub-beta";
          location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
        }
      ];
      # apps are added by hosts/users via services.flatpak.packages (lists merge)
    };
  };
}
