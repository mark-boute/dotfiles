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
    
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... } @ inputs: 
  let
    mkSystem = packages: system: hostname: main-user:
      nixpkgs.lib.nixosSystem {
        specialArgs = { 
          inherit inputs system; 

          nixpkgs.config.allowUnfree = true;

          # pkgs = import packages {
          #   inherit system;
          #   overlays = [              
          #   #  (final: prev: { # https://nixpk.gs/pr-tracker.html?pr=338836
          #   #    inherit (import nixpkgs-unstable {inherit system;}) xdg-desktop-portal-hyprland;
          #   #  })            
          #   ];

          #   config = { allowUnfree = true; };
          # };

          pkgs-unstable = import nixpkgs-unstable { 
            inherit system;
            config = { allowUnfree = true; };
          };
        };
        modules = [
          { networking.hostName = hostname; }
          ./modules  # options.modules.*
          ./overlays # options.overlays.*
          ./lib      # mainly just some functions

          # Base configuration and host specific configuration and overlays
          ./modules/system/configuration.nix  # imported here instead of in ./modules/default.nix for readability
          ./hosts/${hostname}/configuration.nix
          ./overlays/hosts/${hostname}
          
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
      # mark
      legion = mkSystem nixpkgs "x86_64-linux" "legion" "mark";
      
      # ties
      ties-laptop = mkSystem nixpkgs "x86_64-linux" "ties-laptop" "tiesd";
      
      # marijn
      marijn-laptop = mkSystem nixpkgs "x86_64-linux" "marijn-laptop" "scarletto";
    };
  };
}
