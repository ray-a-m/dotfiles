-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local prose_filetypes = { tex = true }

-- NoNeckPain assigns each side window a hl namespace and only writes its own
-- background_group/text_group into it; Normal stays undefined and falls back
-- to terminal default rather than colorscheme Normal, drawing a faint line at
-- the side/main boundary. Inject Normal/NormalNC/WinSeparator into NNP's
-- namespaces (idempotent across NNP re-runs since it never writes Normal in
-- default config).
local function patch_nnp_namespaces()
  local s = _G.NoNeckPain and _G.NoNeckPain.state
  if not s or not s.namespaces then return end
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local groups = {
    "Normal", "NormalNC", "WinSeparator", "VertSplit",
    "EndOfBuffer", "NonText", "LineNr", "SignColumn",
  }
  for _, ns in pairs(s.namespaces) do
    for _, g in ipairs(groups) do
      vim.api.nvim_set_hl(ns, g, normal)
    end
  end
end

-- Prose mode: spatial-only overrides for .tex files. Theme/colors are NOT
-- touched here — the active colorscheme (driven by Omarchy via plugins/theme.lua)
-- applies to both code and prose. To rice prose-specific colors later, do it
-- in a dedicated highlight-override block, not here.
local function apply_prose_mode(buf, event)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local ft = vim.bo[buf].filetype
  -- BufEnter can fire on plugin-created buffers (e.g. NoNeckPain side buffers)
  -- before their filetype is set. Wait for the subsequent FileType event so we
  -- don't disable NoNeckPain based on the transient empty ft right after enable.
  if event == "BufEnter" and ft == "" then return end
  if ft == "no-neck-pain" then
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.api.nvim_set_option_value("statuscolumn", "", { win = win })
      -- Default fillchars vert is │ (a real glyph). Even when WinSeparator's
      -- bg matches Normal, the │ renders in fg = Normal.fg (dark text color),
      -- drawing a faint vertical bar at the side/prose boundary. Replace with
      -- a space so the cell has no foreground rendering.
      vim.api.nvim_set_option_value("fillchars", "vert: ,eob: ", { win = win })
    end
    return
  end
  -- Skip any other scratch/plugin buffer (terminal, file tree, quickfix).
  -- Their re-entry was the original loop.
  if vim.bo[buf].buftype ~= "" then return end

  local is_prose = prose_filetypes[ft] == true

  if is_prose then
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.cursorline = false
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.breakindent = true
    vim.wo.fillchars = "vert: "
    vim.wo.winhighlight = "WinSeparator:Normal"
    vim.wo.statuscolumn = ""
    vim.bo[buf].textwidth = 80
    if vim.b[buf].prose_prev_formatoptions == nil then
      vim.b[buf].prose_prev_formatoptions = vim.bo[buf].formatoptions
    end
    vim.bo[buf].formatoptions = "tcqjn"
    vim.o.laststatus = 3
    vim.b[buf].snacks_indent = false
    vim.opt.showmode = false
    vim.wo.list = false
  else
    vim.wo.number = true
    vim.wo.relativenumber = true
    vim.wo.signcolumn = "yes"
    vim.wo.cursorline = true
    vim.wo.wrap = false
    vim.wo.linebreak = false
    vim.wo.breakindent = false
    vim.wo.fillchars = ""
    vim.wo.winhighlight = ""
    vim.wo.statuscolumn = "%!v:lua.LazyVim.statuscolumn()"
    vim.bo[buf].textwidth = 0
    if vim.b[buf].prose_prev_formatoptions ~= nil then
      vim.bo[buf].formatoptions = vim.b[buf].prose_prev_formatoptions
      vim.b[buf].prose_prev_formatoptions = nil
    end
    vim.o.laststatus = 3
    vim.b[buf].snacks_indent = nil
    vim.opt.showmode = false
    vim.wo.list = true
  end

  -- Auto-enable only. Auto-disable is unsafe: rapid filetype-driven toggling
  -- triggers async teardown races in NoNeckPain (issue #481). Toggle off
  -- manually with <leader>np when leaving prose.
  if not is_prose then return end
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local nnp = _G.NoNeckPain and _G.NoNeckPain.state
    if not (nnp and nnp.enabled) then
      -- pcall guards against enable-time internal races in NoNeckPain.
      local ok, err = pcall(require("no-neck-pain").enable, "prose_mode")
      if not ok then
        vim.notify("no-neck-pain enable failed: " .. tostring(err), vim.log.levels.WARN)
        return
      end
    end
    patch_nnp_namespaces()
  end)
end

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("prose_mode", { clear = true }),
  callback = function(args)
    apply_prose_mode(args.buf, args.event)
  end,
})

-- Blend the cmdline row into the document background so it doesn't render as
-- a dark strip below the statusline. Reads Normal's bg/fg at runtime, so it
-- adapts to whichever colorscheme Omarchy is driving.
local function blend_cmdline_hl()
  vim.schedule(function()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    if not normal.bg then return end
    local hl = { bg = normal.bg, fg = normal.fg }
    for _, group in ipairs({
      "MsgArea", "MsgSeparator",
      "NoiceCmdline", "NoiceCmdlineIcon", "NoiceCmdlinePrompt",
      "NoiceMini", "NoicePopup", "NoicePopupBorder",
      "NoiceSplit", "NoiceSplitBorder",
    }) do
      vim.api.nvim_set_hl(0, group, hl)
    end
  end)
end
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter", "User" }, {
  group = vim.api.nvim_create_augroup("blend_cmdline_hl", { clear = true }),
  pattern = "*",
  callback = blend_cmdline_hl,
})
blend_cmdline_hl()

-- autocmds.lua loads on VeryLazy, after FileType/BufEnter have already fired
-- for a file passed on the command line. Run once for the current buffer so
-- the initial buffer gets the same treatment as later buffer switches.
apply_prose_mode(vim.api.nvim_get_current_buf(), "init")

-- Aerial outline float decorations:
--   * blend float bg into Normal so the panel matches the document
--   * add virt_lines between entries for row spacing (terminal nvim has no
--     per-buffer line-height)
--   * disable aerial's hardcoded WinLeave-closes-float behavior (window.lua's
--     float branch registers a close-on-leave autocmd that close_automatic_events
--     does not cover); we delete those autocmds by their description
local aerial_ns = vim.api.nvim_create_namespace("aerial_decorations")
local AERIAL_VIRT_LINES = { { { " " } } }

local function set_aerial_winhl(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    pcall(vim.api.nvim_set_option_value, "winhighlight",
      "NormalFloat:Normal,FloatBorder:Normal,FloatTitle:Normal,EndOfBuffer:Normal,CursorLine:Visual",
      { win = win })
    -- Force signcolumn on so the active-row glyph (set by refresh_aerial_marker)
    -- has a column to render in. Aerial's float defaults to signcolumn=auto,
    -- which works with extmarks but only when at least one sign exists; setting
    -- yes:1 keeps the column reserved so the layout doesn't jump on update.
    pcall(vim.api.nvim_set_option_value, "signcolumn", "yes:1", { win = win })
  end
end

local function add_aerial_spacing(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, aerial_ns, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(buf)
  for i = 0, line_count - 1 do
    pcall(vim.api.nvim_buf_set_extmark, buf, aerial_ns, i, 0, {
      virt_lines = AERIAL_VIRT_LINES,
    })
  end
end

local function kill_aerial_close_autocmds()
  for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "WinEnter" })) do
    if au.desc and au.desc:find("aerial") then
      pcall(vim.api.nvim_del_autocmd, au.id)
    end
  end
  for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "WinLeave" })) do
    if au.desc and au.desc:find("aerial") then
      pcall(vim.api.nvim_del_autocmd, au.id)
    end
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "aerial",
  group = vim.api.nvim_create_augroup("aerial_decorate", { clear = true }),
  callback = function(args)
    local buf = args.buf
    if vim.b[buf]._aerial_attached then
      kill_aerial_close_autocmds()
      return
    end
    vim.b[buf]._aerial_attached = true
    vim.schedule(function()
      set_aerial_winhl(buf)
      add_aerial_spacing(buf)
      kill_aerial_close_autocmds()
    end)
    vim.api.nvim_buf_attach(buf, false, {
      on_lines = function()
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then
            add_aerial_spacing(buf)
            set_aerial_winhl(buf)
          end
        end)
        return false
      end,
      on_detach = function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.b[buf]._aerial_attached = nil
        end
      end,
    })
  end,
})

-- Belt-and-suspenders: every time we enter the aerial float, scrub any close
-- autocmds aerial may have armed since last check.
vim.api.nvim_create_autocmd("WinEnter", {
  group = vim.api.nvim_create_augroup("aerial_no_close", { clear = true }),
  callback = function()
    if vim.bo.filetype == "aerial" then
      kill_aerial_close_autocmds()
    end
  end,
})

-- Active-item indicator for aerial outline. Aerial flags the closest symbol
-- to the cursor by setting the AerialLine line_hl_group on that row; most
-- colorschemes leave AerialLine undefined, so the cue is invisible by default
-- AND any explicit color we'd set would be hardcoded against the theme.
-- Solution: keep AerialLine transparent, mirror the active row with a glyph
-- in the signcolumn that uses the theme's `Special` highlight — so the
-- indicator's color tracks Omarchy theme switches the same way the rest of
-- the editor does.
local aerial_marker_ns = vim.api.nvim_create_namespace("aerial_marker")
local AERIAL_MARKER_GLYPH = "❯"
local AERIAL_MARKER_HL = "Special"

local function clear_aerial_line_hl()
  vim.api.nvim_set_hl(0, "AerialLine", {})
  vim.api.nvim_set_hl(0, "AerialLineNC", {})
end

-- Compute the active aerial row from the source cursor directly via aerial's
-- window API. Doing it this way (rather than scanning aerial's own AerialLine
-- extmark) avoids a one-event-loop-tick lag that caused ghost-row glitches
-- when paragraph-jumping with { and }. We also run synchronously (no
-- vim.schedule) so the marker repositions in the same frame as the cursor.
-- WinScrolled is intentionally NOT subscribed: aerial moves its own float
-- cursor on every section change, which fires WinScrolled inside aerial and
-- triggered extra clear+set cycles during fast key-repeat. CursorMoved on
-- the source side is sufficient.
local function refresh_aerial_marker()
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_win = vim.api.nvim_get_current_win()

  local ok_util, util = pcall(require, "aerial.util")
  if not ok_util then return end
  -- Cursor in the aerial buffer itself doesn't represent a section change
  -- in the source; skip so the marker doesn't drift while clicking the TOC.
  if util.is_aerial_buffer(cur_buf) then return end

  local source_bufnr, aer_bufnr = util.get_buffers(cur_buf)
  if not aer_bufnr or not vim.api.nvim_buf_is_valid(aer_bufnr) then return end

  local ok_window, window = pcall(require, "aerial.window")
  if not ok_window then return end

  local pos = window.get_position_in_win(source_bufnr, cur_win)
  if not pos or not pos.lnum then return end

  vim.api.nvim_buf_clear_namespace(aer_bufnr, aerial_marker_ns, 0, -1)
  pcall(vim.api.nvim_buf_set_extmark, aer_bufnr, aerial_marker_ns, pos.lnum - 1, 0, {
    sign_text = AERIAL_MARKER_GLYPH,
    sign_hl_group = AERIAL_MARKER_HL,
  })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("aerial_marker_hl", { clear = true }),
  pattern = "*",
  callback = function() vim.schedule(clear_aerial_line_hl) end,
})
clear_aerial_line_hl()

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorHold", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("aerial_marker_refresh", { clear = true }),
  callback = refresh_aerial_marker,
})
