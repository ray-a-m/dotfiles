-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local prose_filetypes = { tex = true }
local applying_colorscheme = false

local function apply_prose_mode(buf, event)
  if applying_colorscheme then return end
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

  applying_colorscheme = true
  if vim.g.colors_name ~= want_scheme then
    vim.cmd.colorscheme(want_scheme)
  end
  applying_colorscheme = false

  if is_prose then
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.cursorline = false
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.breakindent = true
    vim.wo.fillchars = "vert: "
    vim.bo[buf].textwidth = 80
    if vim.b[buf].prose_prev_formatoptions == nil then
      vim.b[buf].prose_prev_formatoptions = vim.bo[buf].formatoptions
    end
    vim.bo[buf].formatoptions = "tcqjn"
    vim.o.laststatus = 0
    vim.b[buf].snacks_indent = false
    vim.opt.showmode = true
    vim.wo.list = false
    io.write("\27]12;#000000\7")
  else
    vim.wo.number = true
    vim.wo.relativenumber = true
    vim.wo.signcolumn = "yes"
    vim.wo.cursorline = true
    vim.wo.wrap = false
    vim.wo.linebreak = false
    vim.wo.breakindent = false
    vim.wo.fillchars = ""
    vim.bo[buf].textwidth = 0
    if vim.b[buf].prose_prev_formatoptions ~= nil then
      vim.bo[buf].formatoptions = vim.b[buf].prose_prev_formatoptions
      vim.b[buf].prose_prev_formatoptions = nil
    end
    vim.o.laststatus = 3
    vim.b[buf].snacks_indent = nil
    vim.opt.showmode = false
    vim.wo.list = true
    io.write("\27]112\7")
  end

  -- Auto-enable only. Auto-disable is unsafe: rapid filetype-driven toggling
  -- triggers async teardown races in NoNeckPain (issue #481). Toggle off
  -- manually with <leader>np when leaving prose.
  if not is_prose then return end
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local nnp = _G.NoNeckPain and _G.NoNeckPain.state
    if nnp and nnp.enabled then return end
    -- pcall guards against enable-time internal races in NoNeckPain.
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
