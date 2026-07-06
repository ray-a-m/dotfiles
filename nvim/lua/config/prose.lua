-- Filetypes treated as prose. Shared source of truth: read by
-- config/autocmds.lua (drives apply_prose_mode: NoNeckPain, spell, wrap,
-- textwidth, ProseNormal winhighlight) and plugins/lualine.lua (drives
-- the right-side segment suppression that keeps the statusline minimal
-- while writing).
--
-- Edit here — nowhere else — when adding/removing a prose filetype so
-- the two consumers stay in lockstep.
return {
  filetypes = { tex = true },
}
