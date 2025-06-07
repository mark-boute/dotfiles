{ pkgs, ... }:
{
  config.vim = {
    globals = {
      "mapleader" = " ";
    };

    options = {
      shiftwidth = 4;
      tabstop = 4;
      updatetime = 100;
    };

    keymaps = [
      {
        key = "<leader>cd";
        mode = "n";
        action = "<cmd>Ex<CR>";
        silent = true;
        desc = "Show current directory";
      }
    ];

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

    lsp = {
      enable = true;
      formatOnSave = true;

    };

    languages = {
      enableFormat = true;
      enableTreesitter = true;

      nix.enable = true;

      haskell.enable = false;
      java.enable = true;
      python = {
        enable = true;
        lsp.enable = true;
        format = {
          enable = true;
          type = "ruff";
        };
      };
      
      markdown = {
        enable = true;
        extensions.markview-nvim.enable = true;
        format.enable = true;
      };

      ts.enable = true;
      html.enable = true;
      css.enable = true;
      tailwind.enable = true;
    };
  };
}