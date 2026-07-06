-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set({ "n", "i", "v" }, "<LeftDrag>", "<Nop>")
vim.keymap.set({ "n", "i", "v" }, "<LeftRelease>", "<Nop>")

-- <C-h>/<C-j>/<C-k>/<C-l>: unified window+pane nav in n/i/v/t.
--   <C-h>: prefer left-edge floats (aerial, snacks explorer). Else
--          TmuxNavigateLeft = wincmd h, else forward to tmux.
--   <C-l>: real nvim right-neighbor if not the NNP centering pad.
--          If it is the pad, bypass the plugin (which would wincmd into
--          the pad) and call `tmux select-pane -R` directly.
--   <C-j>/<C-k>: plain TmuxNavigate — no float or NNP wrinkles vertically.
-- Insert/visual use `<Cmd>` to preserve mode; terminal mode uses the
-- canonical `<C-\><C-n>` idiom to leave terminal-job mode first.
-- Registered here (not in plugins/tmux-navigator.lua) because config/keymaps.lua
-- loads on VeryLazy AFTER LazyVim's system defaults (`<C-h>` = `<C-w>h`) —
-- keys-spec + VimEnter approaches lost the race in normal mode.
local function nav_left()
  local left_floats = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" and cfg.focusable ~= false then
      local col = type(cfg.col) == "table" and cfg.col[false] or cfg.col or 0
      if col == 0 then table.insert(left_floats, win) end
    end
  end
  for _, win in ipairs(left_floats) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_picker_list" then
      vim.api.nvim_set_current_win(win); return
    end
  end
  if #left_floats > 0 then vim.api.nvim_set_current_win(left_floats[1]); return end
  vim.cmd("TmuxNavigateLeft")
end
local function nav_right()
  local cur = vim.fn.winnr()
  local target_nr = vim.fn.winnr("l")
  if target_nr ~= cur then
    local target_win = vim.fn.win_getid(target_nr)
    if target_win and target_win ~= 0 then
      local target_buf = vim.api.nvim_win_get_buf(target_win)
      if vim.bo[target_buf].filetype ~= "no-neck-pain" then
        vim.api.nvim_set_current_win(target_win); return
      end
      -- Right neighbor IS the NNP pad. Skip the plugin's `wincmd l`
      -- (which would land in the pad) and forward straight to tmux.
      if vim.env.TMUX then
        vim.fn.system({ "tmux", "select-pane", "-R" })
        return
      end
    end
  end
  vim.cmd("TmuxNavigateRight")
end
local nvi = { "n", "v", "i" }
-- Move-line-up rebound from LazyVim's default <A-k> to <A-s>, so <A-k> can
-- host insert-mode spell-fix (below) without ambiguity. Uses the same three
-- commands LazyVim ships (n/i/v variants at ~/.local/share/nvim/lazy/LazyVim
-- /lua/lazyvim/config/keymaps.lua:27-31). Also disables the old <A-k>=move
-- bindings in n/v so <A-k> is unambiguously spell-fix-only.
vim.keymap.set("n", "<A-s>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move line up" })
vim.keymap.set("i", "<A-s>", "<esc><cmd>m .-2<cr>==gi",                        { desc = "Move line up" })
vim.keymap.set("v", "<A-s>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move line up" })
vim.keymap.set({ "n", "v" }, "<A-k>", "<Nop>", { desc = "(moved to <A-s>)" })

vim.keymap.set(nvi, "<C-h>",   nav_left,                        { desc = "Nav left (float→nvim→tmux)" })
vim.keymap.set(nvi, "<C-j>",   "<cmd>TmuxNavigateDown<cr>",     { desc = "Nav down (nvim→tmux)" })
vim.keymap.set(nvi, "<C-k>",   "<cmd>TmuxNavigateUp<cr>",       { desc = "Nav up (nvim→tmux)" })
vim.keymap.set(nvi, "<C-l>",   nav_right,                       { desc = "Nav right (skip NNP→tmux)" })
vim.keymap.set(nvi, [[<C-\>]], "<cmd>TmuxNavigatePrevious<cr>", { desc = "Nav previous (nvim/tmux)" })
-- Terminal-mode: all four use the canonical `<C-\><C-n>` leave-terminal-job
-- idiom then the plugin's nav command. The float-preference and NNP-skip
-- logic in nav_left/nav_right is only meaningful in editor buffers — from
-- a terminal buffer, plain TmuxNavigate* is the right primitive.
vim.keymap.set("t", "<C-h>",   [[<C-\><C-n><cmd>TmuxNavigateLeft<cr>]],  { desc = "Nav left" })
vim.keymap.set("t", "<C-j>",   [[<C-\><C-n><cmd>TmuxNavigateDown<cr>]],  { desc = "Nav down" })
vim.keymap.set("t", "<C-k>",   [[<C-\><C-n><cmd>TmuxNavigateUp<cr>]],    { desc = "Nav up" })
vim.keymap.set("t", "<C-l>",   [[<C-\><C-n><cmd>TmuxNavigateRight<cr>]], { desc = "Nav right" })

-- Close current tab. Extends LazyVim's <leader><tab>… subgroup (which also
-- ships `d` for delete-tab, `n` for new, `o` for close-others) with `c` so
-- close-tab discovers via which-key alongside its siblings.
vim.keymap.set("n", "<leader><tab>c", "<cmd>tabclose<cr>", { desc = "Close Tab" })

-- Insert-mode <A-k>: fix the nearest preceding spelling error without
-- leaving the typing flow. [s jumps to the misspelling, 1z= takes the top
-- suggestion, `] lands at the end of the corrected word, a resumes insert.
-- The <C-g>u's split undo so a bad autocorrect is a single `u` away.
-- Moved off <C-k> so it doesn't collide with the insert-mode nav binding
-- above (which promises unified <C-hjkl> pane nav in n/i/v/t).
vim.keymap.set("i", "<A-k>", "<C-g>u<Esc>[s1z=`]a<C-g>u", { desc = "Fix last spelling error" })
