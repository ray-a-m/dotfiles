-- Track Omarchy's active theme. The active-theme symlink at
-- ~/.config/omarchy/current/theme/neovim.lua returns a LazyVim plugin spec
-- (theme plugin + LazyVim opts.colorscheme). When `omarchy-theme-set X` runs,
-- that file changes; the spec is re-read on next nvim launch, or in-session
-- via :Lazy reload (handled by the omarchy-theme-hotreload plugin).
--
-- Fallback: on macOS or any non-Omarchy machine, use LazyVim's default
-- (Tokyo Night Night) so the install doesn't blow up.

local omarchy_theme = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
local chunk = loadfile(omarchy_theme)
if chunk then
  local ok, spec = pcall(chunk)
  if ok and spec then return spec end
end

return {
  { "folke/tokyonight.nvim", priority = 1000 },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight-night" } },
}
