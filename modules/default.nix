{ inputs, pkgs, config, ... }:

{
  imports =
    [ 
     # system
     ./system/configuration.nix
     ./optimus-prime

     # editor
     ./neovim

     # system programs
     ./steam
    ];
}