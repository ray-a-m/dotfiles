-- Loads the tmux-side christoomey/vim-tmux-navigator plugin (via tpm from
-- ~/code/dotfiles/tmux/tmux.conf) so `:TmuxNavigateLeft/Down/Up/Right/Previous`
-- commands are available. All keymap binding happens in config/keymaps.lua —
-- registering here fought LazyVim's default `<C-h/j/k/l>` = `<C-w>_` in normal
-- mode; keymaps.lua fires on VeryLazy AFTER LazyVim's defaults, so it wins
-- cleanly.
return {
  "christoomey/vim-tmux-navigator",
  lazy = false,
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
}
