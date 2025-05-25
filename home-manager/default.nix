{ inputs, pkgs, config, ... }:

{
  imports = [
    ./desktop
    ./game-launchers
    ./editors
    ./shell
    ./winapps
    
    # standealone
    ./latex
  ];
}