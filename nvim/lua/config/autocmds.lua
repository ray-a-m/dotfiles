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

local function log(msg)
  print("[prose_mode] " .. msg)
end

local function apply_prose_mode(buf, event)
  if not vim.api.nvim_buf_is_valid(buf) then
    log(event .. " buf=" .. buf .. " SKIP invalid")
    return
  end
  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype
  local nnp_pre = _G.NoNeckPain and _G.NoNeckPain.state and _G.NoNeckPain.state.enabled
  log(string.format("%s buf=%d ft=%q bt=%q nnp=%s applying=%s",
    event, buf, ft, bt, tostring(nnp_pre), tostring(applying)))

  if applying then
    log("  -> SKIP applying guard")
    return
  end
  -- BufEnter can fire on plugin-created buffers (e.g. NoNeckPain side buffers)
  -- before their filetype is set. The subsequent FileType event will re-enter
  -- with ft populated; let that pass handle it, so we don't race by disabling
  -- NoNeckPain based on an empty ft immediately after enabling it.
  if event == "BufEnter" and ft == "" then
    log("  -> SKIP BufEnter with empty ft (await FileType)")
    return
  end
  if bt ~= "" then
    log("  -> SKIP non-empty buftype")
    return
  end
  if ft == "no-neck-pain" then
    log("  -> SKIP no-neck-pain ft")
    return
  end

  local is_prose = prose_filetypes[ft] == true
  local want_scheme = is_prose and "modus_operandi" or "tokyonight"
  log(string.format("  is_prose=%s want_scheme=%s current=%s",
    tostring(is_prose), want_scheme, tostring(vim.g.colors_name)))

  applying = true
  if vim.g.colors_name ~= want_scheme then
    vim.cmd.colorscheme(want_scheme)
  end
  applying = false

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      log("  [scheduled] SKIP invalid buf=" .. buf)
      return
    end
    local nnp = _G.NoNeckPain and _G.NoNeckPain.state
    local nnp_on = nnp and nnp.enabled
    log(string.format("  [scheduled] buf=%d is_prose=%s nnp_on=%s",
      buf, tostring(is_prose), tostring(nnp_on)))
    local ok, err
    if is_prose and not nnp_on then
      log("    -> calling enable()")
      ok, err = pcall(require("no-neck-pain").enable, "prose_mode")
    elseif (not is_prose) and nnp_on then
      log("    -> calling disable()")
      ok, err = pcall(require("no-neck-pain").disable)
    else
      log("    -> no-op")
    end
    if ok == false then
      log("    -> FAILED: " .. tostring(err))
      vim.notify("no-neck-pain toggle failed: " .. tostring(err), vim.log.levels.WARN)
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
