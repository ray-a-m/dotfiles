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
    vim.g.vimtex_syntax_conceal_disable = 1

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
  end,
}
