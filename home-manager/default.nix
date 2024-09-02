{ inputs, pkgs, config, ... }:

{
  imports = [
    ./desktop
    ./game-launchers
    ./editors

    # standealone
    ./latex
  ];
}