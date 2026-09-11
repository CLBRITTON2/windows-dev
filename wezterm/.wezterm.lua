local wezterm = require 'wezterm'
local act = wezterm.action

return {
  -- Launch WSL as the default shell
  default_prog = {"wsl", "--cd", "~"},
  font = wezterm.font("JetBrainsMono NF"),
  font_size = 16,
  window_decorations = "RESIZE",
  color_scheme = "rose-pine",
  window_background_opacity = 0.9,
  window_padding = { left = 8, right = 8, top = 8, bottom = 8 },
  default_cursor_style = "BlinkingBlock",
  keys = {
    -- Make Ctrl+Enter distinguishable from Enter by sending a CSI-u sequence
    -- that Neovim parses as <C-CR>. Do not re-enable enable_kitty_keyboard for this:
    -- a TUI that exits without popping the protocol stack leaves shifted keys
    -- emitting CSI-u, which readline and plain WSL shells do not parse.
    { key = 'Enter', mods = 'CTRL', action = act.SendString('\x1b[13;5u') },
  },
}