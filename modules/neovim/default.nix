{ config, lib, pkgs, pkgs-unstable, inputs, ... }:
{ 
  programs.neovim = {
    enable = true;
    package = pkgs-unstable.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    configure = {
      customRC = lib.fileContents ./init.vim;

      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [ 
          ctrlp
          nvim-tree-lua
        ];
        # manually loadable by calling `:packadd $plugin-name`
        opt = [ ];
      };
    };
  };
}