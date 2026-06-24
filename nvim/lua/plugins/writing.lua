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
      { "<leader>nf", "<cmd>Fix<cr>", desc = "Re-flow LaTeX prose (:Fix)" },
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
    init = function()
      -- :Fix — re-flow LaTeX prose paragraphs back to width 95 after editing
      -- decay. formatoptions=t only rewraps the current line as you type, so
      -- paragraphs drift into ragged staircases after mid-paragraph edits.
      -- :Fix pipes the buffer through `tex-rewrap` (dotfiles/bin/tex-rewrap,
      -- installed to /usr/local/bin via install.sh). Atomic-command list,
      -- pass-through rules, and width default are all documented in that
      -- script's header — single source of truth.
      vim.api.nvim_create_user_command("Fix", function(opts)
        if vim.bo.filetype ~= "tex" then
          vim.notify(":Fix only supports tex files", vim.log.levels.WARN)
          return
        end
        if vim.fn.executable("tex-rewrap") == 0 then
          vim.notify("tex-rewrap not on PATH (run install.sh from dotfiles)", vim.log.levels.ERROR)
          return
        end
        local view = vim.fn.winsaveview()
        local range = opts.range == 0 and "%" or (opts.line1 .. "," .. opts.line2)
        vim.cmd("silent " .. range .. "!tex-rewrap")
        vim.fn.winrestview(view)
      end, {
        desc = "Re-flow LaTeX prose (:Fix)",
        range = true,
      })
    end,
  },
}
