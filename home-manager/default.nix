{ inputs, ... }:

{
  imports = [
    ./desktop
    ./game-launchers
    ./editors
    ./shell
    
    # standealone
    ./latex
    ./spotify

    # modules
    inputs.catppuccin.homeModules.catppuccin
  ];
}
