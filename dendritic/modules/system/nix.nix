{ inputs, ... }:
{
  flake.modules.nixos.nix = {
    imports = [ inputs.nix-index-database.nixosModules.default ];

    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
        download-buffer-size = 524288000; # 500 MiB
        trusted-users = [ "@wheel" ];

        substituters = [ "https://hyprland.cachix.org" "https://cache.nixos-cuda.org" ];
        trusted-substituters = [ "https://hyprland.cachix.org" "https://cache.nixos-cuda.org" ];
        trusted-public-keys = [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" # ollama-cuda etc.
        ];
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
