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

local function apply_prose_mode(buf)
  if applying then return end
  if not vim.api.nvim_buf_is_valid(buf) then return end
  -- Skip NoNeckPain side buffers and any other scratch/plugin buffer
  -- (terminal, file tree, quickfix). Their re-entry was the original loop.
  if vim.bo[buf].buftype ~= "" then return end
  if vim.bo[buf].filetype == "no-neck-pain" then return end

  local is_prose = prose_filetypes[vim.bo[buf].filetype] == true
  local want_scheme = is_prose and "modus_operandi" or "tokyonight"

  applying = true
  if vim.g.colors_name ~= want_scheme then
    vim.cmd.colorscheme(want_scheme)
  end
  applying = false

  -- Defer NoNeckPain toggling past the current event tick; re-check state
  -- inside the closure because the plugin's own scheduled handlers may run
  -- in between and mutate per-tab state.
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local nnp = _G.NoNeckPain and _G.NoNeckPain.state
    local nnp_on = nnp and nnp.enabled
    local ok, err
    if is_prose and not nnp_on then
      ok, err = pcall(require("no-neck-pain").enable, "prose_mode")
    elseif (not is_prose) and nnp_on then
      ok, err = pcall(require("no-neck-pain").disable)
    end
    if ok == false then
      vim.notify("no-neck-pain toggle failed: " .. tostring(err), vim.log.levels.WARN)
    end
  end)
end

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("prose_mode", { clear = true }),
  callback = function(args)
    apply_prose_mode(args.buf)
  end,
})

-- autocmds.lua loads on VeryLazy, after FileType/BufEnter have already fired
-- for a file passed on the command line. Run once for the current buffer so
-- the initial buffer gets the same treatment as later buffer switches.
apply_prose_mode(vim.api.nvim_get_current_buf())
