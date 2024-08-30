{ config, lib, pkgs, inputs, ... }:
{ 
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    configure = {
      customRC = lib.fileContents ./init.vim;

      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [ ctrlp ];
        # manually loadable by calling `:packadd $plugin-name`
        opt = [ ];
      };
    };
  };
}