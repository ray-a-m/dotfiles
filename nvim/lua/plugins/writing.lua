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
      -- Machine-specific: centered document width tuned for MacBook Air.
      -- Tune per machine to keep prose readable at the display's column count.
      width = 100,
    },
  },
}
