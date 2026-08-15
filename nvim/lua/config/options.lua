require("config.remote_clipboard").setup()
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

-- No highlighted current-line bar. Reads as an opaque strip against the
-- translucent nvim window; navigation cues live in the cursor itself.
-- `apply_prose_mode` (autocmds.lua) returns early on bare buffers (empty ft
-- BufEnter), so a per-window override there wouldn't cover unnamed scratch
-- buffers — set globally here instead.
vim.opt.cursorline = false
