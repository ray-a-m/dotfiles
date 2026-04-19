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
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "markdown" },
        callback = function()
          vim.cmd("NoNeckPain")
        end,
      })
    end,
    opts = {
      width = 120,
    },
  },
}
