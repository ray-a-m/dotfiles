-- Quiet markdown diagnostics. LazyVim's markdown extra wires markdownlint-cli2
-- through nvim-lint, which fires constant style nits ("trailing whitespace",
-- "consecutive blank lines", "list style", …) that aren't useful for prose
-- drafting. Disable the linter; marksman LSP stays on for genuine warnings
-- (broken refs, malformed tables) — those still surface.
--
-- Also disable render-markdown.nvim. Its job is to add visual chrome (heading
-- bars, code-block backdrops, bullet icons, conceal-driven rendering), which
-- is the opposite of prose mode's "raw text over wallpaper" feel. With it on,
-- markdown buffers paint a solid backdrop that hides the Hyprland blur and
-- breaks parity with the tex prose look.
return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = {}
      opts.linters_by_ft["markdown.mdx"] = {}
      return opts
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = false,
  },
}
