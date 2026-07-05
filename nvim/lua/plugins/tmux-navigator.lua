-- Companion to the tmux-side christoomey/vim-tmux-navigator plugin (loaded via
-- tpm from ~/code/dotfiles/tmux/tmux.conf). With both halves installed,
-- Ctrl-h/j/k/l crosses seamlessly between nvim splits and tmux panes.
--
-- lazy = false + explicit mapping overrides matter here: LazyVim ships default
-- <C-h/j/k/l> window-nav mappings, and if the plugin lazy-loads on keypress
-- LazyVim's defaults win. Loading at startup + setting the mappings in `keys`
-- guarantees ours are the last word.
return {
  "christoomey/vim-tmux-navigator",
  lazy = false,
  init = function()
    -- Disable the plugin's own default mappings; we set them explicitly below.
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Navigate left (tmux/nvim)" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Navigate down (tmux/nvim)" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Navigate up (tmux/nvim)" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (tmux/nvim)" },
    { [[<C-\>]], "<cmd>TmuxNavigatePrevious<cr>", desc = "Navigate previous (tmux/nvim)" },
  },
}
