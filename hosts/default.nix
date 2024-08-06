{ inputs, pkgs, config, ... }:

{
  imports =
    [ 
     # system
     ./laptop/configuration.nix
    ];
}