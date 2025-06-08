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
    assistant.copilot.enable = true;

    minimap.minimap-vim.enable = true;
    autopairs.nvim-autopairs.enable = true;
    navigation.harpoon.enable = true;

    utility.oil-nvim.enable = true;
    filetree.nvimTree = {
      enable = true;
    };

    clipboard = {
      enable = true;
      providers.wl-copy.enable = true;
    };

    options = {
      tabstop = 4;
      shiftwidth = 0;
      updatetime = 100;
      termguicolors = true;
    };

    theme = {
      enable = true;
      name = "onedark";
      style = "warmer";
    };

    mini = {
      icons.enable = true;
    };

    visuals = {
      nvim-scrollbar.enable = true;
      nvim-web-devicons.enable = true;
      highlight-undo.enable = true;
    };

    statusline.lualine = {
      enable = true;
      theme = "onedark";
    };

    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;
  };
}
