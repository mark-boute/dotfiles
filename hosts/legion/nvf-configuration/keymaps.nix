{ ... }:
{
  config.vim.keymaps = [
    {
      key = "<leader>cd";
      mode = "n";
      action = "<cmd>Ex<CR>";
      silent = true;
      desc = "Show current directory";
    }
  ];
}