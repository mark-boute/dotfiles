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
    system = "x86_64-linux";
    # hosts = import ./hosts;  # TODO is this the right way to import the hosts? Might need a hosts/default.nix file  
    pkgs = inputs.nixpkgs.legacyPackages.${system};

    mkSystem = pkgs: system: hostname:
      pkgs.lib.nixosSystem {
        system = system;
        specialArgs = { inherit inputs; };
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
      laptop = mkSystem inputs.nixpkgs "x86_64-linux" "laptop";
    };
    # homeConfigurations = {
    #   mark = home-manager.lib.homeManagerConfiguration {
    #     inherit system;
    #     modules = [ ./users/mark/home.nix ];
    # };
  };
}
