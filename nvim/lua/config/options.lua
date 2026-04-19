-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Better soft-wrap for prose
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true

-- Prose writing defaults
vim.opt.spell = false  -- enable per-filetype if wanted
vim.opt.conceallevel = 0  -- don't hide LaTeX commands

vim.g.vimtex_matchparen_enabled = 0
