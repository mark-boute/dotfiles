{ ... }:
{

  imports = [
    ./keymaps.nix
    ./lsp-settings.nix
  ];

  config.vim = {
    globals = {
      "mapleader" = " ";
    };

    options = {
      shiftwidth = 4;
      tabstop = 4;
      updatetime = 100;
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