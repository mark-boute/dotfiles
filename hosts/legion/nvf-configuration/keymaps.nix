{...}: {
  config.vim = {
    binds.whichKey.enable = true;
    keymaps = [
      {
        key = "<leader>cd";
        mode = "n";
        action = "<cmd>Oil<CR>";
        silent = true;
        desc = "Show current directory";
      }

      # Telescope keymaps
      {
        key = "<leader>ff";
        mode = "n";
        action = "<cmd>Telescope find_files<CR>";
        silent = true;
        desc = "Find files";
      }
      {
        key = "<leader>fg";
        mode = "n";
        action = "<cmd>Telescope live_grep<CR>";
        silent = true;
        desc = "Live grep";
      }
      {
        key = "<leader>fb";
        mode = "n";
        action = "<cmd>Telescope buffers<CR>";
        silent = true;
        desc = "List buffers";
      }
      {
        key = "<leader>fh";
        mode = "n";
        action = "<cmd>Telescope help_tags<CR>";
        silent = true;
        desc = "Help tags";
      }

      # Harpoon within Telescope
      {
        key = "<leader>fl";
        mode = "n";
        lua = true;
        action = "function() require('telescope_functions').toggle_telescope(require('harpoon'):list()) end";
        silent = true;
        desc = "Open Harpoonlist in Telescope";
      }

      # Minimap
      {
        key = "<leader>m";
        mode = "n";
        action = "<cmd>Minimap<CR>";
        silent = true;
        desc = "toggle minimap";
      }
    ];
  };
}
