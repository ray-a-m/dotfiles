return {
  "nvim-telescope/telescope-bibtex.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  ft = { "tex", "markdown" },
  config = function()
    require("telescope").load_extension("bibtex")
  end,
  keys = {
    { "<leader>cb", "<cmd>Telescope bibtex<cr>", desc = "Search bibliography", ft = "tex" },
  },
}
