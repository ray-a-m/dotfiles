return {
  "okuuva/auto-save.nvim",
  event = { "InsertLeave", "TextChanged" },
  opts = {
    debounce_delay = 1000,
    condition = function(buf)
      local filetype = vim.bo[buf].filetype
      return filetype == "tex" or filetype == "bib" or filetype == "markdown"
    end,
  },
}
