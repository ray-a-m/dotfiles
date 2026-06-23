-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Don't hide LaTeX commands (LazyVim default is 3)
vim.opt.conceallevel = 0

-- Set before vimtex loads so matchparen stays off from the first buffer
vim.g.vimtex_matchparen_enabled = 0

vim.opt.timeoutlen = 300

vim.opt.cmdheight = 1

-- Override LazyVim's default `clipboard = "unnamedplus"`. On Wayland, that
-- routes every register-touch through `wl-copy`/`wl-paste` synchronously,
-- and intermittent compositor latency surfaces as periodic 100–300ms typing
-- hangs (profile showed `provider#clipboard#Call` as the dominant cost).
-- Cross to the system clipboard explicitly with `"+y` / `"+p`.
vim.opt.clipboard = ""
