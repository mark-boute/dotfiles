{ config, pkgs, inputs, lib, ... }:

with lib; let
  cfg = config.modules.neovim;

  toLua = str: "lua << EOF\n" + str + "\nEOF\n";
  toLuaFile = file: "lua < EOF\n" + builtins.readFile file + "\nEOF\n";
in {
  options.modules.neovim = {
    enable = mkEnableOption "neovim";

    makeDefaultEditor = mkOption {
      type = types.bool;
      default = true;
      description = "make neovim the default editor";
    };
    
    setAliasses = mkOption {
      type = types.bool;
      default = true;
      description = "set vi, vim and vimdiff aliasses";
    };
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = cfg.makeDefaultEditor;
      viAlias = cfg.setAliasses;
      vimAlias = cfg.setAliasses;
      vimdiffAlias = cfg.setAliasses;

      extraLuaConfig = ''
        ${builtins.readFile ./options.lua}
      '';

      extraPackages = with pkgs; [
        xclip
        wl-clipboard

        lua-language-server

      ];

      plugins = with pkgs.vimPlugins; [
        vim-nix
        lualine-nvim

        {
          plugin = comment-nvim;
          config = toLua "require(\"Comment\").setup()";
        }

      {
        plugin = (nvim-treesitter.withPlugins (p: [
          p.tree-sitter-nix
          p.tree-sitter-vim
          p.tree-sitter-bash
          p.tree-sitter-lua
          p.tree-sitter-python
          p.tree-sitter-json
        ]));
        config = toLuaFile ./plugins/treesitter.lua;
      }
      ];
    };
  
  };

}