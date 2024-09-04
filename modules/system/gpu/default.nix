{ inputs, pkgs, config, ... }:

{
  imports =
    [ 
      ./nvidia.nix
      ./prime.nix
    ];
}