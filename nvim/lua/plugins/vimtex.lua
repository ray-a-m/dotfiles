return {
  "lervag/vimtex",
  lazy = false,
  init = function()
    vim.g.vimtex_view_method = vim.fn.has("macunix") == 1 and "skim" or "zathura"
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_compiler_latexmk = {
      aux_dir = "",
      out_dir = "",
      callback = 1,
      continuous = 1,
      executable = "latexmk",
      hooks = {},
      options = {
        "-verbose",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
      },
    }
    vim.g.vimtex_quickfix_mode = 0
    vim.g.vimtex_mappings_disable = { ["n"] = { "K" } }
    -- Highlighting delegated to the treesitter `latex` parser. Vimtex's
    -- regex syntax engine bogs down on long single-line paragraphs (e.g.
    -- the 1.5k–2.7k-char prose lines in older body.tex files), causing
    -- per-keystroke lag and uneven highlighting. TS handles long lines
    -- without breaking a sweat.
    vim.g.vimtex_syntax_enabled = 0

    -- `:Compile` — one-shot save + start continuous latexmk + open viewer.
    -- Idempotent: re-running while compilation is already live just refreshes
    -- the viewer rather than toggling latexmk off (which is what bare
    -- :VimtexCompile would do). View call is deferred so the first invocation
    -- on a fresh buffer has time to produce a PDF before zathura opens.
    vim.api.nvim_create_user_command("Compile", function()
      vim.cmd("write")
      local ok, running = pcall(vim.fn["vimtex#compiler#is_running"])
      if not ok or running == 0 then
        pcall(vim.cmd, "VimtexCompile")
      end
      vim.defer_fn(function() pcall(vim.cmd, "VimtexView") end, 250)
    end, { desc = "Save, compile, and view PDF (LaTeX)" })

    vim.keymap.set("n", "<leader>lc", "<cmd>Compile<cr>",
      { desc = "LaTeX: save + compile + view" })

    -- `:Texclear` — recovery for wedged latexmk state. Stops the current
    -- continuous compile, runs `latexmk -c` to remove stale aux/fdb/bcf/etc
    -- (PDF kept so the open viewer doesn't lose its file), then restarts
    -- :Compile. Use when builds fail with stale-aux symptoms: runaway
    -- argument on a contentsline, biber's "malformed bcf", or latexmk's
    -- "Nothing to do" with a cached error.
    --
    -- Capitalized first letter because nvim user commands MUST start with
    -- uppercase. cnoreabbrev below lets `:texclear` typed lowercase still
    -- expand to `:Texclear`, preserving muscle memory.
    vim.api.nvim_create_user_command("Texclear", function()
      if vim.bo.filetype ~= "tex" then
        vim.notify(":Texclear only runs from a tex buffer", vim.log.levels.WARN)
        return
      end
      pcall(vim.cmd, "VimtexStop")
      pcall(vim.cmd, "VimtexClean")
      vim.defer_fn(function() pcall(vim.cmd, "Compile") end, 100)
    end, { desc = "LaTeX: clear stale build artifacts and restart compile" })
    vim.cmd("cnoreabbrev texclear Texclear")
  end,
}
