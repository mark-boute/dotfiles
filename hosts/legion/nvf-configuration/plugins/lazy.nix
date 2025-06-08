{pkgs, ...}: let
  inherit (pkgs) vimPlugins;
in {
  config.vim.lazy.plugins = {
    nvim-highlight-colors = {
      package = vimPlugins.nvim-highlight-colors;
      setupModule = "nvim-highlight-colors";
      setupOpts = {
        enable_tailwind = true;
      };
    };
  };
}
