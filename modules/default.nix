{ inputs, pkgs, config, ... }:

{
  imports =
    [ 
     # system
    ./system

    # development tools
    ./development-tools

     # editor
     ./neovim

     # system programs
     ./steam
    ];
}