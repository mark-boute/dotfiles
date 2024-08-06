{
  description = "NixOS config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs: 
  let
    mkSystem = packages: system: hostname:
      nixpkgs.lib.nixosSystem {
        specialArgs = { 
          inherit inputs system; 
          pkgs = import packages {
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
              extraSpecialArgs = { inherit inputs; };
              users.mark = ./hosts/${hostname}/home.nix;
            };
          }
        ];
      };
  in
  {
    nixosConfigurations = {
      laptop = mkSystem nixpkgs "x86_64-linux" "laptop";
    };
    # homeConfigurations = {
    #   mark = home-manager.lib.homeManagerConfiguration {
    #     inherit system;
    #     modules = [ ./users/mark/home.nix ];
    # };
  };
}