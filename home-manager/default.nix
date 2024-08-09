{ inputs, pkgs, config, ... }:

{
  imports = [ 
    ./hyprland
     
    # gui
    ./eww
  ];
}