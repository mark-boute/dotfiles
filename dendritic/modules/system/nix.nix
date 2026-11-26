{ inputs, ... }:
{
  flake.modules.nixos.nix = {
    imports = [ inputs.nix-index-database.nixosModules.default ];

    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
        download-buffer-size = 524288000; # 500 MiB
        trusted-users = [ "@wheel" ];
      };
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    };

    nixpkgs.config.allowUnfree = true;
  };
}
