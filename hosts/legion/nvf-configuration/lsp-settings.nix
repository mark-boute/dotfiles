{ ... }:
{
  config.vim = {
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