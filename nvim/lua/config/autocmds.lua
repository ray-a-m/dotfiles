-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local prose_filetypes = { tex = true, markdown = true }
local nnp_enabled = false

vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
  group = vim.api.nvim_create_augroup("prose_mode", { clear = true }),
  callback = function()
    local is_prose = prose_filetypes[vim.bo.filetype] == true
    local want_scheme = is_prose and "modus_operandi" or "tokyonight"
    if vim.g.colors_name ~= want_scheme then
      vim.cmd.colorscheme(want_scheme)
    end
    if is_prose ~= nnp_enabled then
      vim.schedule(function()
        vim.cmd("NoNeckPain")
        nnp_enabled = is_prose
      end)
    end
  end,
})
