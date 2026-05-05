-- Re-export the omarchy-nvim hotreload plugin. Listens for `User LazyReload`
-- and re-applies the colorscheme defined in plugins.theme — which is the
-- omarchy-driven spec, so `omarchy-theme-set X` followed by `:Lazy reload`
-- inside nvim picks up the new theme without restarting.
-- No-op on non-Omarchy machines.

local omarchy_path = "/usr/share/omarchy-nvim/config/lua/plugins/omarchy-theme-hotreload.lua"
local chunk = loadfile(omarchy_path)
if chunk then
  local ok, spec = pcall(chunk)
  if ok and spec then return spec end
end
return {}
