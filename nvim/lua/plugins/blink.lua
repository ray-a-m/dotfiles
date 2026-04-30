return {
  "saghen/blink.cmp",
  opts = {
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
