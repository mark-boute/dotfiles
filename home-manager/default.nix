{ inputs, pkgs, config, ... }:

{
  imports = [ 
    ./hyprland
     
    # gui
    ./eww

    # writing and editing
    ./latex
  ];
}