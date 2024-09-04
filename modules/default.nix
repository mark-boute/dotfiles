{ inputs, pkgs, config, ... }:

{
  imports =
    [ 
     # system
    ./system

     # editor
     ./neovim

     # system programs
     ./steam
    ];
}