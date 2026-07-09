-- Filetypes treated as prose. Shared source of truth: read by
-- config/autocmds.lua (drives apply_prose_mode: NoNeckPain, spell, wrap,
-- textwidth, ProseNormal winhighlight) and plugins/lualine.lua (drives
-- the right-side segment suppression that keeps the statusline minimal
-- while writing).
--
-- Edit here — nowhere else — when adding/removing a prose filetype so
-- the two consumers stay in lockstep.
--
-- wrap_filetypes get ONLY soft visual wrap (wrap + linebreak + breakindent):
-- long paragraphs fold on screen at the window/pane width and reflow live as
-- the pane is resized, with NO hard line breaks inserted. None of the rest of
-- prose mode (NoNeckPain centering, spell, number-hiding, ProseNormal colors).
-- Used for markdown viewed in a narrow tmux pane.
return {
  filetypes = { tex = true },
  wrap_filetypes = { markdown = true },
}
