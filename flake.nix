{
  description = "NixOS config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-unstable-small.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs: 
  let
    mkSystem = packages: system: hostname: main-user:
      nixpkgs.lib.nixosSystem {
        specialArgs = { 
          inherit inputs system; 
          pkgs = import packages {
            inherit system;

            overlays = [
              (final: prev: { # https://nixpk.gs/pr-tracker.html?pr=338836
                inherit (import inputs.nixos-unstable-small {inherit system;}) xdg-desktop-portal-hyprland;
              })            
            ];

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
              extraSpecialArgs = { inherit inputs; };
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