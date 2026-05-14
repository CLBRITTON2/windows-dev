local wezterm = require 'wezterm'
local act = wezterm.action

return {
  -- Launch WSL as the default shell
  default_prog = {"wsl", "--cd", "~"},
  font = wezterm.font("JetBrainsMono NF"),
  font_size = 16,
  window_background_opacity = 1,
  window_decorations = "RESIZE",
  color_scheme = "rose-pine",
  window_background_opacity = 0.9,
  window_padding = { left = 0, right = 0, top = 0, bottom = 0 },
  enable_kitty_keyboard = true,
  keys = {
    -- Make Ctrl+Enter distinguishable from Enter by sending a CSI-u sequence
    -- that Neovim parses as <C-CR>. Belt-and-braces alongside kitty keyboard.
    { key = 'Enter', mods = 'CTRL', action = act.SendString('\x1b[13;5u') },
  },
}