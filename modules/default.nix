{ ... }:

{
  imports =
    [ 
     # system
    ./system
    ./winapps

    # secrets
    ./sops

    # development tools
    ./development-tools

     # editor
     ./neovim

     # system programs
     ./steam
    ];
}