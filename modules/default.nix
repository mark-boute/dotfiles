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

     # system programs
     ./steam
    ];
}