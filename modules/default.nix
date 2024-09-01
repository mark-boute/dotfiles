{ inputs, pkgs, config, ... }:

{
  imports =
    [ 
     # system
     ./system/configuration.nix
     ./optimus-prime/default.nix

     # editor
     ./neovim
    ];
}