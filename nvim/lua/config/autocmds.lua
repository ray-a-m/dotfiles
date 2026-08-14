-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local prose = require("config.prose")
local prose_filetypes = prose.filetypes
local wrap_filetypes = prose.wrap_filetypes

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
    vim.wo.spell = true
    vim.bo[buf].spelllang = "en_us"
    vim.wo.fillchars = "vert: ,eob: "
    vim.wo.winhighlight = "WinSeparator:Normal,Normal:ProseNormal,NormalNC:ProseNormal"
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
    -- 1 (not 0) so prose mode still surfaces the tab strip when >1 tab is open.
    -- A single-tab prose buffer stays bar-free; opening a second tab reveals titles.
    vim.o.showtabline = 1
  else
    vim.wo.number = true
    vim.wo.relativenumber = true
    vim.wo.signcolumn = "yes"
    vim.wo.cursorline = false
    vim.wo.wrap = false
    vim.wo.linebreak = false
    vim.wo.breakindent = false
    vim.wo.spell = false
    vim.wo.fillchars = ""
    vim.wo.winhighlight = ""
    vim.wo.statuscolumn = "%!v:lua.LazyVim.statuscolumn()"
    -- Wrap-only filetypes (markdown): soft visual wrap that reflows to the
    -- window (pane) width — a paragraph stays one logical line but folds on
    -- screen at word boundaries, tracking the pane as it's resized. NO hard
    -- wrap (textwidth stays 0, no `t` in formatoptions), so no real newlines
    -- are inserted. None of the rest of prose mode (NoNeckPain, spell,
    -- number-hiding, colors) applies.
    if wrap_filetypes[ft] then
      vim.wo.wrap = true
      vim.wo.linebreak = true
      vim.wo.breakindent = true
    end
    vim.bo[buf].textwidth = 0
    if vim.b[buf].prose_prev_formatoptions ~= nil then
      vim.bo[buf].formatoptions = vim.b[buf].prose_prev_formatoptions
      vim.b[buf].prose_prev_formatoptions = nil
    end
    vim.o.laststatus = 3
    vim.b[buf].snacks_indent = nil
    vim.opt.showmode = false
    vim.wo.list = true
    vim.o.showtabline = 2
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

-- Vim auto-compiles spell/*.add → .add.spl only on `zg`/`zw` writes from inside
-- vim. External edits (bulk-seeding from a script, syncing dotfiles across
-- machines) leave the .spl stale or missing, and the wordlist silently has no
-- effect. Recompile once at startup if .add is newer than .spl (or .spl absent).
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("spell_recompile", { clear = true }),
  once = true,
  callback = function()
    local add = vim.fn.expand("~/.config/nvim/spell/en.utf-8.add")
    if vim.fn.filereadable(add) == 0 then return end
    local spl = add .. ".spl"
    local add_mtime = vim.fn.getftime(add)
    local spl_mtime = vim.fn.getftime(spl)
    if add_mtime > spl_mtime then
      vim.schedule(function() pcall(vim.cmd, "silent mkspell! " .. vim.fn.fnameescape(add)) end)
    end
  end,
})

-- Match nvim's Normal bg to the kitty bg (sourced from the active Omarchy
-- theme's colors.toml). Kitty's 14px window_padding_width (kitty.conf) paints
-- the theme's `background` color, while the colorscheme (catppuccin-latte for
-- mornye) ships a slightly different shade — Raymond brightened colors.toml's
-- background for legibility at ~80% window opacity, but didn't shift the nvim
-- colorscheme. The mismatch renders as a visible inner "frame" between the
-- Hyprland border and the buffer content. Reading colors.toml at runtime keeps
-- this theme-agnostic across `omarchy-theme-set` swaps.
local function read_theme_bg()
  -- Omarchy 4 keeps the built theme under ~/.local/state; pre-Quattro used
  -- ~/.config. Try both so this works across the upgrade.
  local f
  for _, path in ipairs({
    vim.fn.expand("~/.local/state/omarchy/current/theme/colors.toml"),
    vim.fn.expand("~/.config/omarchy/current/theme/colors.toml"),
  }) do
    f = io.open(path, "r")
    if f then break end
  end
  if not f then return nil end
  for line in f:lines() do
    local hex = line:match('^%s*background%s*=%s*"#?(%x+)"')
    if hex and (#hex == 6 or #hex == 8) then
      f:close()
      return tonumber(hex:sub(1, 6), 16)
    end
  end
  f:close()
  return nil
end
-- Prose-mode foreground override. Kitty's `background_opacity` only applies
-- to cells using the default background — since match_normal_to_theme_bg
-- aligns nvim's Normal.bg with kitty's bg, prose text falls into that bucket
-- and goes translucent. Over dark wallpaper patches the catppuccin-latte
-- text fg (#4c4f69) loses contrast. The ProseNormal group below carries the
-- same bg (so nothing else changes) but a darker fg, and apply_prose_mode
-- maps Normal/NormalNC onto it via winhighlight for tex only.
local function define_prose_normal(bg)
  vim.api.nvim_set_hl(0, "ProseNormal", {
    bg = bg,
    -- Pure black: prose reads as ink on page. Catppuccin-latte's default
    -- `#4c4f69` is a bluish-gray that goes washy over translucent bg patches;
    -- the prior `#0a0d18` was a half-step that still read as dark gray.
    fg = 0x000000,
  })
end
local function match_normal_to_theme_bg()
  vim.schedule(function()
    local bg = read_theme_bg()
    if not bg then return end
    local cur = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    cur.bg = bg
    vim.api.nvim_set_hl(0, "Normal", cur)
    define_prose_normal(bg)
    -- Mirror onto NormalNC so unfocused windows don't repaint with a darker
    -- shade. catppuccin-latte (and most schemes) ship NormalNC slightly darker
    -- to highlight the active window — but with the explorer/aerial floats
    -- already signaling focus, the bg shift on the document is just visual
    -- noise. Keep both identical.
    local nc = vim.api.nvim_get_hl(0, { name = "NormalNC", link = false })
    nc.bg = bg
    vim.api.nvim_set_hl(0, "NormalNC", nc)
  end)
end
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("match_normal_to_theme_bg", { clear = true }),
  pattern = "*",
  callback = match_normal_to_theme_bg,
})
match_normal_to_theme_bg()

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

-- Blend snacks picker windows into Normal. Snacks's `SnacksPicker` group links
-- to NormalFloat, which on Omarchy-driven themes is a few shades darker than
-- Normal — making picker windows draw as visible panels instead of transparent
-- overlays on the NoNeckPain pad. SnacksPickerInput/List/Box all link back to
-- SnacksPicker (per snacks/picker/util/highlight.lua:winhl), so one override
-- cascades to every picker chrome window.
--
-- Cannot be set via the source's `win.{input,list}.wo.winhighlight`: snacks's
-- `Snacks.win.resolve(user, defaults)` (win.lua:223) has defaults override user
-- when winhighlight conflicts, so the picker rebuilds its winhighlight from the
-- highlight-group names. Re-linking the names is the only path that works.
local function blend_snacks_picker_hl()
  vim.schedule(function()
    vim.api.nvim_set_hl(0, "SnacksPicker", { link = "Normal" })
  end)
end
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("blend_snacks_picker_hl", { clear = true }),
  pattern = "*",
  callback = blend_snacks_picker_hl,
})
blend_snacks_picker_hl()

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

-- Aerial buffer-local nav keys: <C-j> drops into the explorer below, <C-l>
-- jumps to the main document. Buffer-local so they don't bleed elsewhere.
-- <C-l> needs an explicit binding because vim's wincmd-l from aerial's float
-- routes through the NoNeckPain left pad first, costing two presses.
local function focus_main_doc()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative == "" and vim.bo[buf].filetype ~= "no-neck-pain" then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end
vim.api.nvim_create_autocmd("FileType", {
  pattern = "aerial",
  group = vim.api.nvim_create_augroup("aerial_nav_keys", { clear = true }),
  callback = function(args)
    vim.keymap.set("n", "<C-j>", function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_picker_list" then
          vim.api.nvim_set_current_win(win)
          return
        end
      end
      pcall(vim.cmd, "wincmd j")
    end, { buffer = args.buf, desc = "Focus snacks explorer below" })
    vim.keymap.set("n", "<C-l>", focus_main_doc,
      { buffer = args.buf, desc = "Focus main document" })
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

-- Aerial-window-visible guard: when aerial's float is closed, get_buffers
-- still returns a valid aer_bufnr (aerial caches the symbol buffer), so
-- without this check the expensive get_position_in_win + extmark work
-- runs on every CursorMoved for no visible payoff.
local function aerial_window_visible()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "aerial" then
      return true
    end
  end
  return false
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
  if not aerial_window_visible() then return end

  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_win = vim.api.nvim_get_current_win()

  local ok_util, util = pcall(require, "aerial.util")
  if not ok_util then return end
  -- Cursor in the aerial buffer itself doesn't represent a section change
  -- in the source; skip so the marker doesn't drift while clicking the TOC.
  if util.is_aerial_buffer(cur_buf) then return end

  -- Row-cache guard: CursorMoved fires for column-only motion too (h/l/w/f/$),
  -- which can't change the active section. Skip unless the row actually moved.
  local row = vim.api.nvim_win_get_cursor(cur_win)[1]
  if vim.w[cur_win].aerial_marker_last_row == row then return end
  vim.w[cur_win].aerial_marker_last_row = row

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

-- Aerial float geometry is computed in plugins/aerial.lua's `float.override`
-- callback, which only runs at open time. On window resize NoNeckPain rebalances
-- its side pads correctly but the aerial float keeps its old width — the result
-- is a TOC that doesn't track the new column count, shifting the prose buffer
-- visually relative to it. Close + reopen so the override re-runs with fresh
-- vim.o.columns. Deferred so NoNeckPain's own VimResized handler can finish
-- rebalancing first (aerial reads NNP's pad width to derive its own).
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("aerial_resize", { clear = true }),
  callback = function()
    local aerial_open = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "aerial" then
        aerial_open = true
        break
      end
    end
    if not aerial_open then return end
    pcall(vim.cmd, "AerialClose")
    vim.defer_fn(function()
      if prose_filetypes[vim.bo.filetype] then
        pcall(vim.cmd, "AerialOpen")
      end
    end, 50)
  end,
})

-- `:Clipclear` — flush the system clipboard. Use when keystroke lag /
-- slow `p` / slow `:reg` creep in after copying a long passage out to an
-- AI or large yank inside nvim. With `clipboard=unnamedplus`, every nvim
-- op re-shuffles the clipboard content via wl-copy, so a stale large
-- selection compounds the cost. Clears at two layers:
--   * nvim's `+` and `*` registers (windows into the system clipboard)
--   * wl-clipboard's clipboard and primary selections (so clipboard
--     managers like cliphist drop the entry too)
-- Named registers (a-z), macros, numbered registers, search history,
-- and the unnamed register `""` are deliberately left intact.
--
-- Capitalized first letter because nvim user commands MUST start with
-- uppercase. cnoreabbrev below lets `:clipclear` typed lowercase still
-- expand to `:Clipclear`, parallel to the `:Texclear` pattern.
vim.api.nvim_create_user_command("Clipclear", function()
  vim.fn.setreg("+", "")
  vim.fn.setreg("*", "")
  vim.fn.system({ "wl-copy", "--clear" })
  vim.fn.system({ "wl-copy", "--primary", "--clear" })
  vim.notify("clipboard cleared", vim.log.levels.INFO)
end, { desc = "Flush system clipboard (recover from yank-induced sluggishness)" })
vim.cmd("cnoreabbrev clipclear Clipclear")
