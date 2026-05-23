return {
  "hasansujon786/super-kanban.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = "SuperKanban",
  opts = {
    markdown = {
      list_heading = "h2",
      -- Starting columns for new boards. admin.md doesn't use this (its
      -- columns are read from the file); only matters if you ever
      -- `:SuperKanban create <new-file>`. Done lives in the archive.
      default_template = {
        "## Months\n",
        "## Weeks\n",
        "## Days\n",
        "## Today\n",
      },
    },
    -- Navigate the board with bare hjkl (defaults are <C-hjkl>).
    -- Trade-off: lose hjkl as in-card cursor motion in normal mode; cards are
    -- single-line titles so it doesn't bite. Multi-line note popup (<CR> to
    -- open) keeps normal vim motion. <C-hjkl> moves cards (was <A-hjkl>).
    mappings = {
      ["<A-h>"] = false,
      ["<A-j>"] = false,
      ["<A-k>"] = false,
      ["<A-l>"] = false,
      ["h"] = "jump_left",
      ["j"] = "jump_down",
      ["k"] = "jump_up",
      ["l"] = "jump_right",
      ["<C-h>"] = "move_left",
      ["<C-j>"] = "move_down",
      ["<C-k>"] = "move_up",
      ["<C-l>"] = "move_right",
      ["<C-f>"] = "create_card_after",
      ["<C-r>"] = "rename_list",
      -- <C-d> archives rather than toggling a checkbox: marking done means
      -- the card disappears from the active board into the markdown's
      -- Archive section. Delete (gD, default) is preserved for cards that
      -- should leave no trace.
      ["<C-d>"] = "archive_card",
    },
  },
  config = function(_, opts)
    local card_module = require("super-kanban.ui.card")
    local list_module = require("super-kanban.ui.list")
    local board_module = require("super-kanban.ui.board")

    -- Capture the resolved config table (defaults deep-merged with our opts)
    -- so the centering patch below can read list/board dimensions without
    -- re-implementing the merge. list_module.setup gets the same shared
    -- config reference as every other ui submodule.
    local resolved_config
    local original_list_module_setup = list_module.setup
    list_module.setup = function(conf)
      resolved_config = conf
      return original_list_module_setup(conf)
    end

    require("super-kanban").setup(opts)

    -- Upstream nil-guard workarounds. super-kanban (alpha as of 2026-05)
    -- dereferences card.visible_index in two hot paths without checking
    -- for nil, but a freshly-created card has visible_index=nil until
    -- it's rendered. The very common "create card, then navigate or
    -- create another" sequences crash. Wrap each call site to coerce
    -- nil to a sane fallback (the absolute index, which is always set).
    -- If upstream patches these, the wrappers become redundant no-ops.
    local function ensure_visible_index(c)
      if c and c.visible_index == nil then
        c.visible_index = (type(c.index) == "number" and c.index > 0) and c.index or 1
      end
    end

    -- card.lua:351 — jump_horizontal
    local original_jump_horizontal = card_module.jump_horizontal
    card_module.jump_horizontal = function(self, direction)
      ensure_visible_index(self)
      return original_jump_horizontal(self, direction)
    end

    -- list.lua:362 / :365 — create_card 'after' / 'before'
    local original_create_card = list_module.create_card
    list_module.create_card = function(self, placement, current_card)
      ensure_visible_index(current_card)
      return original_create_card(self, placement, current_card)
    end

    -- Wave's default Visual (waveBlue1) is too close in luminance to the
    -- bg, so banners don't register without an override.
    local function apply_kanban_banners()
      vim.api.nvim_set_hl(0, "SuperKanbanListWinbar", { bg = "#2d4f67", fg = "#dcd7ba", bold = true })
      vim.api.nvim_set_hl(0, "SuperKanbanListWinbarEdge", { fg = "#2d4f67", bg = "NONE" })
    end
    apply_kanban_banners()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("super-kanban-banner", { clear = true }),
      callback = apply_kanban_banners,
    })

    -- Aesthetic chrome strip. super-kanban renders two cosmetic pieces
    -- with no opt-out: (a) the board's top winbar with filename and
    -- ← N / N → scroll arrows, (b) each column's bottom footer with
    -- green ↑N / ↓N card-scroll arrows. Override the two
    -- update_scroll_info methods to keep the internal counters but skip
    -- the cosmetic writes. The initial board winbar is set once by
    -- snacks.win at mount before our override can intercept, so a
    -- FileType autocmd clears it on first display. The column titles
    -- at the *top* of each column are kept — they're the useful labels.
    list_module.update_scroll_info = function(self, top, bottom, total)
      self.scroll_info.top = top > 0 and top or 0
      self.scroll_info.bot = bottom > 0 and bottom or 0
      self:update_winbar(total)
    end
    board_module.update_scroll_info = function(self, first, last)
      self.scroll_info.first = first > 0 and first or 0
      self.scroll_info.last = last > 0 and last or 0
    end
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("super-kanban-aesthetic", { clear = true }),
      pattern = "superkanban_board",
      callback = function(args)
        local buf = args.buf
        vim.schedule(function()
          local win = vim.fn.bufwinid(buf)
          if win ~= -1 and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_option_value("winbar", "", { win = win })
          end
        end)
      end,
    })

-- Center the list cluster inside the board. Default behavior anchors
    -- lists at the left edge (config.board.padding.left = 8); a wide-only
    -- terminal leaves an oversized right gutter when few lists are open.
    -- Override the two col-write call sites in list.lua to compute a
    -- centering offset from the live board width and visible list count.
    -- Falls back to default left-anchoring when lists overflow the board.
    local LIST_GAP = 3
    local DEFAULT_PADDING_LEFT = 8
    local function compute_col(self, visual_index)
      local board = self.ctx and self.ctx.board
      local board_win = board and board.win and board.win.win
      local list_w = (resolved_config and resolved_config.list and resolved_config.list.width) or 32
      if not (board_win and vim.api.nvim_win_is_valid(board_win)) or not self.ctx.lists then
        return DEFAULT_PADDING_LEFT + (list_w + LIST_GAP) * (visual_index - 1)
      end
      local board_width = vim.api.nvim_win_get_width(board_win)
      local total_span = #self.ctx.lists * (list_w + LIST_GAP) - LIST_GAP
      local pad = (total_span <= board_width)
          and math.max(DEFAULT_PADDING_LEFT, math.floor((board_width - total_span) / 2))
        or DEFAULT_PADDING_LEFT
      return pad + (list_w + LIST_GAP) * (visual_index - 1)
    end

    -- list.lua:60 — initial col on mount. Wrap original; mutate opts.col
    -- after creation but before list:mount calls self.win:show().
    local original_list_setup_win = list_module.setup_win
    list_module.setup_win = function(self)
      original_list_setup_win(self)
      if self.win and self.win.opts then
        self.win.opts.col = compute_col(self, self.index)
      end
    end

    -- list.lua:205 — rewrites col on every scroll/reposition. Full
    -- replacement (rather than wrap-and-mutate) so snacks redraws once
    -- at the centered position instead of twice.
    list_module.update_visible_position = function(self, new_visible_index)
      if type(new_visible_index) == "number" and new_visible_index > 0 then
        self.win.opts.col = compute_col(self, new_visible_index)
        if self:closed() then
          self.win:show()
        end
        self.visible_index = new_visible_index
        self.win:update()
        self:update_scroll_info(
          self.scroll_info.top,
          self.scroll_info.bot - 1,
          #self.ctx.lists[self.index].cards
        )
      else
        self:exit()
      end
    end

    -- Persistence is wired only inside super-kanban's board:on_exit(),
    -- which fires on WinClosed of the floating board window. That's
    -- prompt and reliable when you press `q`, but a hard close (kitty
    -- terminating via SUPER+Q, SIGTERM during nvim shutdown) doesn't
    -- run the WinClosed handler in time, so unsaved edits get dropped.
    -- Force on_exit at VimLeavePre so any nvim exit path flushes the
    -- board back to admin.md before the process is gone.
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("super-kanban-flush", { clear = true }),
      callback = function()
        local sk = require("super-kanban")
        if sk.is_opned and sk._ctx and sk._ctx.board then
          pcall(function()
            sk._ctx.board:on_exit()
          end)
        end
      end,
    })
  end,
}
