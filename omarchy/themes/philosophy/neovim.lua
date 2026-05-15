-- Nvim colorscheme for the `philosophy` theme.
--
-- Synced 2026-05-15 (third iteration) to use kanagawa-lotus — the LIGHT
-- variant of kanagawa. Its bg is `#f2ecbc` (parchment), matching the
-- colors.toml that drives every templated app. The whole stack now sits
-- on parchment, including nvim. See RICING.md Session-3b for the full
-- pivot trail (aether → kanagawa-wave → kanagawa-lotus).

return {
  { "rebelot/kanagawa.nvim", priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa-lotus",
    },
  },
}
