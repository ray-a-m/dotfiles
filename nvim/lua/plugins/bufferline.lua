-- LazyVim's bufferline.nvim ships with `always_show_bufferline = true`, so
-- the bar paints (with a close icon, filename, and indent slot) even when
-- only one buffer is open — leaving a one-tab strip floating above the
-- document. Flip to false so the bar appears only when there are 2+ buffers
-- to switch between, matching the "no bar when alone" expectation prose
-- mode already enforces via `showtabline = 1`.
--
-- Also strip the per-buffer and global close icons: this is a keyboard-only
-- workflow, <leader><tab>c handles tab close, <leader>bd handles buffer
-- delete, and the click targets were the visual oddity Raymond flagged.
return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
    opts.options = opts.options or {}
    opts.options.always_show_bufferline = false
    opts.options.show_buffer_close_icons = false
    opts.options.show_close_icon = false
    return opts
  end,
}
