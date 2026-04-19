-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local prose_filetypes = { tex = true, markdown = true }
local applying = false

local function apply_prose_mode(buf, event)
  if applying then return end
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local ft = vim.bo[buf].filetype
  -- BufEnter can fire on plugin-created buffers (e.g. NoNeckPain side buffers)
  -- before their filetype is set. Wait for the subsequent FileType event so we
  -- don't disable NoNeckPain based on the transient empty ft right after enable.
  if event == "BufEnter" and ft == "" then return end
  -- Skip NoNeckPain side buffers and any other scratch/plugin buffer
  -- (terminal, file tree, quickfix). Their re-entry was the original loop.
  if vim.bo[buf].buftype ~= "" then return end
  if ft == "no-neck-pain" then return end

  local is_prose = prose_filetypes[ft] == true
  local want_scheme = is_prose and "modus_operandi" or "tokyonight"

  applying = true
  if vim.g.colors_name ~= want_scheme then
    vim.cmd.colorscheme(want_scheme)
  end
  applying = false

  -- Only auto-enable; never auto-disable. NoNeckPain's disable() runs async
  -- teardown that can crash on get_side_id after refresh_tabs nils the active
  -- tab entry (state.lua:324). The plugin author has flagged rapid
  -- filetype-driven toggling as unsupported (issue #481). Toggle off manually
  -- with <leader>np when leaving prose.
  if not is_prose then return end
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local nnp = _G.NoNeckPain and _G.NoNeckPain.state
    if nnp and nnp.enabled then return end
    local ok, err = pcall(require("no-neck-pain").enable, "prose_mode")
    if not ok then
      vim.notify("no-neck-pain enable failed: " .. tostring(err), vim.log.levels.WARN)
    end
  end)
end

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("prose_mode", { clear = true }),
  callback = function(args)
    apply_prose_mode(args.buf, args.event)
  end,
})

-- autocmds.lua loads on VeryLazy, after FileType/BufEnter have already fired
-- for a file passed on the command line. Run once for the current buffer so
-- the initial buffer gets the same treatment as later buffer switches.
apply_prose_mode(vim.api.nvim_get_current_buf(), "init")
