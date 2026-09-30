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
    ./obsidian

    # modules
    inputs.catppuccin.homeModules.catppuccin
  ];
}
