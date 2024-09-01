{ inputs, pkgs, config, ... }:

{
  imports = [
    ./desktop
    ./game-launchers

    # standealone
    ./latex
  ];
}