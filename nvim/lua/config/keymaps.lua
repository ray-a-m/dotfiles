-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set({ "n", "i", "v" }, "<LeftDrag>", "<Nop>")
vim.keymap.set({ "n", "i", "v" }, "<LeftRelease>", "<Nop>")

-- <C-h>: prefer left-edge floats (aerial outline, snacks explorer) over the
-- NoNeckPain pad that nvim's wincmd would otherwise dump us into. Without
-- this, hitting <C-h> from the main doc moves focus to NNP's empty left pad
-- and the terminal cursor visually disappears into the unrendered buffer.
-- Fallback is the stock <C-w>h.
local function nav_left()
  local left_floats = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" and cfg.focusable ~= false then
      local col = type(cfg.col) == "table" and cfg.col[false] or cfg.col or 0
      if col == 0 then table.insert(left_floats, win) end
    end
  end
  -- Prefer the picker's list window (the explorer rebinds hjkl there for
  -- file navigation — see picker/config/sources.lua) over the input. Landing
  -- in input forces the user to insert-mode-type to filter, which isn't what
  -- they want when summoning the explorer for navigation.
  for _, win in ipairs(left_floats) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_picker_list" then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  if #left_floats > 0 then
    vim.api.nvim_set_current_win(left_floats[1])
    return
  end
  pcall(vim.cmd, "wincmd h")
end
vim.keymap.set("n", "<C-h>", nav_left, { desc = "Window left (floats preferred)" })

-- <C-l>: skip NoNeckPain right pad (empty buffer used only for centering).
-- Without this, <C-l> from the prose buffer lands in the empty pad and the
-- cursor visually disappears. No-op when the only neighbor on the right is
-- the pad.
local function nav_right()
  local target_nr = vim.fn.winnr("l")
  if target_nr == vim.fn.winnr() then return end
  local target_win = vim.fn.win_getid(target_nr)
  if not target_win or target_win == 0 then return end
  local target_buf = vim.api.nvim_win_get_buf(target_win)
  if vim.bo[target_buf].filetype == "no-neck-pain" then return end
  vim.api.nvim_set_current_win(target_win)
end
vim.keymap.set("n", "<C-l>", nav_right, { desc = "Window right (skip NNP pad)" })

-- Close current tab. Extends LazyVim's <leader><tab>… subgroup (which also
-- ships `d` for delete-tab, `n` for new, `o` for close-others) with `c` so
-- close-tab discovers via which-key alongside its siblings.
vim.keymap.set("n", "<leader><tab>c", "<cmd>tabclose<cr>", { desc = "Close Tab" })
