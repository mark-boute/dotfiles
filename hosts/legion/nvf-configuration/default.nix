{pkgs, ...}: {
  imports = [
    ./plugins
    ./nvim/lua

    ./keymaps.nix
    ./lsp-settings.nix
  ];

  config.vim = {
    extraPackages = with pkgs;
      [
        ripgrep
      ]
      ++ (with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars
      ])
      ++ [
        # pkgs from inputs
      ];

    additionalRuntimePaths = [./nvim];

    globals = {
      "mapleader" = " ";
    };

    git = {
      enable = true;
      vim-fugitive.enable = true;
    };
    minimap.minimap-vim.enable = true;

    navigation.harpoon.enable = true;

    clipboard = {
      enable = true;
      providers.wl-copy.enable = true;
    };

    options = {
      shiftwidth = 4;
      tabstop = 4;
      updatetime = 100;
      termguicolors = true;
    };

    theme = {
      enable = true;
      name = "nord";
      style = "dark";
    };

    visuals = {
      nvim-scrollbar.enable = true;
      nvim-web-devicons.enable = true;
      highlight-undo.enable = true;
    };

    statusline.lualine = {
      enable = true;
    };

    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;
  };
}
