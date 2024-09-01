{ inputs, pkgs, config, ... }:

{ 
  # IMPORTANT: This is currently not configurable, it should be if more options than just hybrid exist
  # maybe just importing the correct file in configuration.nix could be enough though
  imports = [ 
    ./hybrid.nix
  ];
}