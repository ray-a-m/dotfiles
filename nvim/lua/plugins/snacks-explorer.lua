-- Snacks file explorer: top-left floating panel paired with Aerial's
-- bottom-left float (plugins/aerial.lua). Both render over NoNeckPain's
-- left pad so the prose document stays centered.
--
-- Bypasses the stock `sidebar` preset by providing an explicit `layout.layout`
-- table (see ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/config/init.lua:225):
-- when layout[1] exists, snacks skips preset resolution entirely.

-- Background blending of the explorer (SnacksPicker → Normal) lives in
-- config/autocmds.lua: snacks's win.resolve clobbers user-provided
-- `wo.winhighlight` with its hardcoded defaults, so per-source overrides have
-- no effect. The highlight-group override is the only path that sticks.
--
-- Geometry: aerial sits top-left, content-sized (plugins/aerial.lua). The
-- explorer parks itself directly under aerial's bottom edge, matching aerial's
-- width — computed at picker-open time via the `config` callback below since
-- it has to read aerial's current window. If aerial isn't open, the explorer
-- falls back to its default row=0 position.

local function aerial_geometry()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "aerial" then
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg and cfg.relative ~= "" then
        return {
          row = (type(cfg.row) == "table" and cfg.row[false]) or cfg.row or 0,
          col = (type(cfg.col) == "table" and cfg.col[false]) or cfg.col or 0,
          width = cfg.width or 48,
          height = cfg.height or 0,
        }
      end
    end
  end
  return nil
end

-- <C-k> inside the explorer jumps to the aerial outline above. This overrides
-- snacks's default `<c-k> = list_up` (defaults.lua:252) — list navigation
-- still works via plain k in normal mode and via the picker's other bindings.
local function focus_aerial()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "aerial" then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          layout = {
            preview = false,
            -- Hide the filter input. hjkl navigation is enough and a visible
            -- search row in a left-side panel is just chrome. Snacks's layout
            -- skips hidden windows when allocating box space (layout.lua:198
            -- → `needs_layout`), so the list expands to fill.
            hidden = { "input" },
            -- Defaults are overwritten by `config` whenever aerial is open;
            -- they're the fallback for "no aerial" (e.g. explorer summoned
            -- from a non-prose buffer).
            layout = {
              box = "vertical",
              backdrop = false,
              relative = "editor",
              row = 0,
              col = 0,
              width = 48,
              height = 0.5,
              border = "none",
              { win = "input", height = 1, border = "bottom" },
              { win = "list", border = "none" },
            },
            config = function(layout)
              local geom = aerial_geometry()
              if not geom then return layout end
              local top = geom.row + geom.height
              layout.layout.row = top
              layout.layout.col = geom.col
              layout.layout.width = geom.width
              -- Fill from below aerial to just above the global statusline.
              layout.layout.height = math.max(vim.o.lines - top - 2, 6)
              return layout
            end,
          },
          win = {
            input = {
              keys = {
                ["<c-k>"] = { focus_aerial, mode = { "i", "n" } },
              },
            },
            list = {
              keys = {
                ["<c-k>"] = { focus_aerial, mode = "n" },
              },
            },
          },
        },
      },
    },
  },
}
