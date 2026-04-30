return {
  "stevearc/aerial.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  cmd = { "AerialToggle", "AerialOpen", "AerialClose" },
  ft = { "tex" },
  keys = {
    { "<leader>o", "<cmd>AerialToggle<cr>", desc = "Paper outline (Aerial)" },
  },
  opts = {
    layout = {
      default_direction = "float",
      placement = "edge",
    },
    float = {
      border = "none",
      relative = "editor",
      override = function(conf, _source_winid)
        conf.anchor = "NW"
        conf.row = 0
        conf.col = 0
        conf.width = 48
        conf.height = vim.o.lines - 2
        return conf
      end,
    },
    attach_mode = "global",
    open_automatic = function(bufnr)
      return vim.bo[bufnr].filetype == "tex"
    end,
    backends = { "treesitter", "lsp", "markdown", "man" },
    filter_kind = false,
    show_guides = true,
    guides = {
      mid_item = "├───",
      last_item = "└───",
      nested_top = "│   ",
      whitespace = "    ",
    },
    autojump = false,
    close_on_select = false,
    close_automatic_events = {},
    highlight_on_jump = 150,
  },
}
