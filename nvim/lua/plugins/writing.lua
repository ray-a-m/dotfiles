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
      --
      -- Visible-text-column note: NoNeckPain reserves ~5 cols inside `width`
      -- for margin/cursor space, so the effective wrap point in the buffer
      -- is ~95, not 100. As-you-type hard-wrap (autocmds.lua `textwidth = 80`)
      -- is well under that and never soft-wraps. For one-shot rewraps of
      -- pre-existing long-paragraph files (e.g. retro-wrapping a paper's
      -- body.tex), target ≤95 — lines at exactly 100 will soft-wrap their
      -- last word onto a display-only line, looking like orphan words.
      width = 100,
    },
  },
}
