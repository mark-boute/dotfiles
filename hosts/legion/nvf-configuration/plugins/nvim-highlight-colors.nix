{ pkgs, ... }:
{
  config.vim.lazy.plugins."nvim-highlight-colors" = {
    package = pkgs.vimPlugins.nvim-highlight-colors;
  };
}