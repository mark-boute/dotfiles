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

          pkgs = import packages {
            inherit system;
            overlays = [

              # https://github.com/NixOS/nixpkgs/issues/349759
              (self: super: {
                tlp = super.tlp.overrideAttrs (old: {
                  makeFlags = (old.makeFlags or [ ]) ++ [
                    "TLP_ULIB=/lib/udev"
                    "TLP_NMDSP=/lib/NetworkManager/dispatcher.d"
                    "TLP_SYSD=/lib/systemd/system"
                    "TLP_SDSL=/lib/systemd/system-sleep"
                    "TLP_ELOD=/lib/elogind/system-sleep"
                    "TLP_CONFDPR=/share/tlp/deprecated.conf"
                    "TLP_FISHCPL=/share/fish/vendor_completions.d"
                    "TLP_ZSHCPL=/share/zsh/site-functions"
                  ];
                });
              })
              
            #  (final: prev: { # https://nixpk.gs/pr-tracker.html?pr=338836
            #    inherit (import nixpkgs-unstable {inherit system;}) xdg-desktop-portal-hyprland;
            #  })            
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
      # mark
      legion = mkSystem nixpkgs "x86_64-linux" "legion" "mark";
      desktop = mkSystem nixpkgs "x86_64-linux" "desktop" "mark";
      
      # ties
      ties-laptop = mkSystem nixpkgs "x86_64-linux" "ties-laptop" "tiesd";
      
      # marijn
      marijn-laptop = mkSystem nixpkgs "x86_64-linux" "marijn-laptop" "scarletto";
    };
  };
}
