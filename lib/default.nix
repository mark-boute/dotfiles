{ inputs, pkgs, config, ... }:

{
  imports =
    [ 
      # ./homeImport.nix
      ./main-user.nix
    ];
}