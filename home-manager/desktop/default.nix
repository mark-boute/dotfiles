{ inputs, pkgs, config, ... }:

{
  imports = [
    ./hyprland
    ./eww
    ./gnome-settings
  ];
}