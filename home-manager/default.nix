{ inputs, pkgs, config, ... }:

{
  imports = [
    ./desktop
    ./game-launchers
    ./editors
    ./shell

    # standealone
    ./latex
  ];
}