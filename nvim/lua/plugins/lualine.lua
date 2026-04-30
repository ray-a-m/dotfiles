return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections.lualine_y = {}
      opts.sections.lualine_z = {}

      local prose_filetypes = { tex = true }
      for _, comp in ipairs(opts.sections.lualine_x or {}) do
        local prev = comp.cond
        comp.cond = function()
          if prose_filetypes[vim.bo.filetype] then return false end
          return prev == nil or prev()
        end
      end
      return opts
    end,
  },
}
