return {
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      { "<leader>z", "<cmd>ZenMode<cr>", desc = "Toggle Zen Mode" },
    },
    opts = {
      window = {
        width = 90,
        options = {
          number = false,
          relativenumber = false,
        },
      },
    },
  },
  {
    "shortcuts/no-neck-pain.nvim",
    cmd = "NoNeckPain",
    keys = {
      { "<leader>np", "<cmd>NoNeckPain<cr>", desc = "Toggle No Neck Pain (center buffer)" },
    },
    opts = {
      width = 110,
      integrations = {
        VimtexTOC = {
          position = "left",
          reopen = false,
        },
      },
    },
    config = function(_, opts)
      require("no-neck-pain.util.constants").INTEGRATIONS.VimtexTOC = {
        fileTypePattern = "vimtex-toc",
        close = "VimtexTocClose",
        open = "VimtexTocOpen",
      }
      require("no-neck-pain").setup(opts)
    end,
  },
}
