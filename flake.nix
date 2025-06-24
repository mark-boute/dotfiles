{
  description = "NixOS config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {  # dekstop toolkit for Hyprland
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {  # neovim configuration framework
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {  # Firefox-based modern browser
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    winapps = {  # Windows applications on NixOS
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {  # secrets management
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.hyprlang.follows = "hyprland/hyprlang";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    ...
  } @ inputs: let
    mkSystem = packages: system: hostname: main-user:
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit self inputs system hostname main-user;

          nixpkgs.config.allowUnfree = true;

          # pkgs = import packages {
          #   inherit system;
          #   overlays = [
          #   #  (final: prev: { # https://nixpk.gs/pr-tracker.html?pr=338836
          #   #    inherit (import nixpkgs-unstable {inherit system;}) xdg-desktop-portal-hyprland;
          #   #  })
          #   ];

          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
        };

        modules = [
          {networking.hostName = hostname;}
          ./modules # options.modules.*
          ./overlays # options.overlays.*
          ./lib # mainly just some functions

          # Base configuration and host specific configuration and overlays
          ./modules/system/configuration.nix # imported here instead of in ./modules/default.nix for readability
          ./hosts/${hostname}/configuration.nix
          ./overlays/hosts/${hostname}

          inputs.sops-nix.nixosModules.sops
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              sharedModules = [
                inputs.sops-nix.homeManagerModules.sops
              ];
              extraSpecialArgs = {
                inherit inputs main-user;

                pkgs-unstable = import nixpkgs-unstable {
                  inherit system;
                  config = {
                    allowUnfree = true;
                  };
                };
              };
              users.${main-user} = ./hosts/${hostname}/home.nix;
            };
          }
        ];
      };
  in {
    packages."x86_64-linux".neovim-mark =
      (inputs.nvf.lib.neovimConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [./hosts/legion/nvf-configuration];
      }).neovim;

    nixosConfigurations = {
      # mark
      legion = mkSystem nixpkgs "x86_64-linux" "legion" "mark";

      # ties
      ties-laptop = mkSystem nixpkgs "x86_64-linux" "ties-laptop" "tiesd";

      # marijn
      marijn-laptop = mkSystem nixpkgs "x86_64-linux" "marijn-laptop" "scarletto";
    };
  };
}
