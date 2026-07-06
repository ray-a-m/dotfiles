return {
  "stevearc/aerial.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  cmd = { "AerialToggle", "AerialOpen", "AerialClose" },
  ft = { "tex" },
  keys = {
    { "<leader>o", "<cmd>AerialToggle<cr>", desc = "Paper outline (Aerial)" },
  },
  opts = {
    layout = {
      default_direction = "float",
      placement = "edge",
    },
    float = {
      border = "none",
      relative = "editor",
      -- Top-left float, sized to fit inside no-neck-pain's left pad. Width
      -- derives from NNP's `width = 100` setting (writing.lua), capped so it
      -- doesn't sprawl on ultrawide monitors. Height fits the symbol count
      -- (each item renders as 2 rows because of the virt_lines spacing added
      -- by autocmds.lua), so there's no dead space below the last entry.
      -- plugins/snacks-explorer.lua reads this float's geometry and parks
      -- itself directly underneath.
      override = function(conf, source_winid)
        conf.anchor = "NW"
        conf.row = 0
        conf.col = 0
        -- Aerial defaults to zindex=125 (window.lua:149), which sits *above*
        -- snacks pickers (zindex ~52) and other on-demand floats. That means
        -- <leader><space> (find files) and similar pop-up overlays get hidden
        -- behind the outline. Drop aerial to 40 — visible over normal buffers
        -- but yields to any modal/picker overlay.
        conf.zindex = 40

        local nnp_width = 100
        local pad = math.floor((vim.o.columns - nnp_width) / 2)
        conf.width = math.max(math.min(pad - 2, 80), 40)

        local src_buf = source_winid and vim.api.nvim_win_get_buf(source_winid)
          or vim.api.nvim_get_current_buf()
        -- Count only visible (post-filter_kind) symbols. aerial's public
        -- num_symbols hardcodes skip_hidden=false, which would overcount once
        -- non-Method kinds are filtered out below.
        local count = 12
        local ok, data = pcall(require, "aerial.data")
        if ok and data.has_symbols(src_buf) then
          local d = data.get_or_create(src_buf)
          local n = d:count({ skip_hidden = true })
          if type(n) == "number" and n > 0 then count = n end
        end
        local rows = count * 2 + 1
        conf.height = math.max(math.min(rows, vim.o.lines - 6), 6)

        return conf
      end,
    },
    attach_mode = "global",
    open_automatic = function(bufnr)
      return vim.bo[bufnr].filetype == "tex"
    end,
    backends = { "treesitter", "lsp", "man" },
    -- Structural symbols only. Aerial's latex query emits sections as "Method"
    -- (\title/\author = "Field", environments = "Class"). Restrict to Method
    -- so bibliography/label commands don't clutter the outline.
    filter_kind = { "Method" },
    -- Aerial's latex query captures `(curly_group (text) @name)`, which grabs
    -- only the first `text` child and stops at inline math (`$…$`). Re-extract
    -- the full curly_group via the symbol node so titles with math survive.
    post_parse_symbol = function(bufnr, item, ctx)
      if item.kind ~= "Method" then return end
      local section_node = ctx.match and ctx.match.symbol and ctx.match.symbol.node
      if not section_node then return end
      local ok, fields = pcall(section_node.field, section_node, "text")
      if not ok or not fields or not fields[1] then return end
      local raw = vim.treesitter.get_node_text(fields[1], bufnr)
      if type(raw) ~= "string" then return end
      raw = raw:gsub("^%s*{", ""):gsub("}%s*$", "")
      raw = raw:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if raw ~= "" then item.name = raw end
    end,
    show_guides = true,
    guides = {
      mid_item = "├───",
      last_item = "└───",
      nested_top = "│   ",
      whitespace = "    ",
    },
    autojump = false,
    close_on_select = false,
    close_automatic_events = {},
    highlight_on_jump = 150,
  },
  -- Sticky source under `attach_mode = "global"`. Aerial's default behavior is
  -- to re-target the panel to whatever buffer gets focused — fine when moving
  -- between papers (different body.tex files), but useless when peeking at a
  -- wrapper (paper.tex with just `\input{body.tex}`) or a non-section file
  -- (refs.bib, README.md). Monkey-patch `open_aerial_in_win` to skip the
  -- re-target when the target buffer has zero visible symbols, so aerial
  -- stays pinned to the last file that actually had structure.
  config = function(_, opts)
    require("aerial").setup(opts)
    local aerial_window = require("aerial.window")
    local aerial_data = require("aerial.data")
    local orig = aerial_window.open_aerial_in_win
    aerial_window.open_aerial_in_win = function(src_buf, src_win, winid)
      local target = (src_buf == nil or src_buf == 0)
        and vim.api.nvim_get_current_buf() or src_buf
      if vim.api.nvim_buf_is_valid(target) then
        local visible = 0
        if aerial_data.has_symbols(target) then
          visible = aerial_data.get_or_create(target):count({ skip_hidden = true })
        end
        if visible == 0 then return end
      end
      return orig(src_buf, src_win, winid)
    end
  end,
}
