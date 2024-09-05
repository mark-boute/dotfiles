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

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... } @ inputs: 
  let
    mkSystem = packages: system: hostname: main-user:
      nixpkgs.lib.nixosSystem {
        specialArgs = { 
          inherit inputs system; 

          pkgs = import packages {
            inherit system;
            overlays = [

              (final: prev: { # https://nixpk.gs/pr-tracker.html?pr=338836
                inherit (import nixpkgs-unstable {inherit system;}) xdg-desktop-portal-hyprland;
              })            
            ];

            config = { allowUnfree = true; };
          };

          pkgs-unstable = import nixpkgs-unstable { 
            inherit system;
            config = { allowUnfree = true; };
          };
        };
        modules = [
          { networking.hostName = hostname; }
          # Base configuration and host specific configuration
          ./modules/system/configuration.nix
          ./hosts/${hostname}/configuration.nix
          
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              extraSpecialArgs = { 
                inherit inputs;
                
                pkgs-unstable = import nixpkgs-unstable { 
                  inherit system;
                  config = { allowUnfree = true; };
                };
              };
              users.${main-user} = ./hosts/${hostname}/home.nix;
            };
          }
        ];
      };
  in
  {
    nixosConfigurations = {
      laptop = mkSystem nixpkgs "x86_64-linux" "laptop" "mark";
      ties-laptop = mkSystem nixpkgs "x86_64-linux" "ties-laptop" "tiesd";
    };
  };
}