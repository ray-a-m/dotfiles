-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Don't hide LaTeX commands (LazyVim default is 3)
vim.opt.conceallevel = 0

-- Set before vimtex loads so matchparen stays off from the first buffer
vim.g.vimtex_matchparen_enabled = 0

vim.opt.fillchars:append({ vert = " " })
vim.opt.timeoutlen = 300
vim.opt.display = "lastline"
