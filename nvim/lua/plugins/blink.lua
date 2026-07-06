return {
  "saghen/blink.cmp",
  opts = {
    -- The presets bind insert-mode <C-k> to signature-help toggling, which
    -- would shadow the unified <C-hjkl> pane nav in config/keymaps.lua.
    -- Spell-fix moved to <A-k>; the unbind still stands to protect nav.
    keymap = { ["<C-k>"] = {} },
    completion = {
      menu = {
        auto_show = function(ctx)
          if vim.bo.filetype ~= "tex" then return true end
          local before = ctx.line:sub(1, ctx.cursor[2])
          return before:match("\\%a*[Cc]ite%a*%*?[^{}]*{[^}]*$") ~= nil
        end,
      },
    },
  },
}
