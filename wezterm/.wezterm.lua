local wezterm = require 'wezterm'

return {
  -- Launch WSL as the default shell
  default_prog = {"wsl", "--cd", "~"},
  font = wezterm.font_with_fallback({
  "JetBrains Mono",
  { family = "Symbols Nerd Font Mono", scale = 0.75},
  }),
  font_size = 16,
  window_background_opacity = 1,
  window_decorations = "RESIZE",
  color_scheme = "rose-pine-moon",
  window_background_opacity = 0.75,
  window_padding = { left = 0, right = 0, top = 0, bottom = 0 },
}