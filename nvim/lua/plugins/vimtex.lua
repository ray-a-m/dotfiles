return {
  "lervag/vimtex",
  lazy = false,
  init = function()
    vim.g.vimtex_view_method = "skim"
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
  end,
}
