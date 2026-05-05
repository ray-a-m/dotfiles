-- Re-export the omarchy-nvim "all-themes" spec when running on Omarchy.
-- Pre-registers every Omarchy theme plugin (lazy = true), so any colorscheme
-- :Lazy reload picks after a theme switch is already installed and ready.
-- No-op on non-Omarchy machines (theme.lua's fallback handles those).

local omarchy_path = "/usr/share/omarchy-nvim/config/lua/plugins/all-themes.lua"
local chunk = loadfile(omarchy_path)
if chunk then
  local ok, spec = pcall(chunk)
  if ok and spec then return spec end
end
return {}
