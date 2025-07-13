{ inputs, ... }:

{
  imports = [
    ./desktop
    ./game-launchers
    ./editors
    ./shell
    ./winapps
    
    # standealone
    ./latex
    ./spotify

    # modules
    inputs.catppuccin.homeModules.catppuccin
  ];
}