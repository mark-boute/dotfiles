{ inputs, pkgs, config, ... }:

{
  imports = [ 
    ./hyprland
     
    # gui
    ./eww

    # writing
    ./latex
  ];
}