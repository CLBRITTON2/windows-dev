#Requires AutoHotkey v2.0
#SingleInstance Force

; Windows Terminal's adjustOpacity only sets a value, so this tracks each window to make ctrl+o a toggle. It
; sends the ctrl+shift+f11 (opacity 100) and ctrl+shift+f12 (opacity 90) bindings in settings.json.

global g_Solid := Map()

#HotIf WinActive("ahk_exe WindowsTerminal.exe")
^o::
{
    window := WinExist("A")
    g_Solid[window] := !g_Solid.Get(window, false)
    if g_Solid[window]
        Send "^+{F11}"
    else
        Send "^+{F12}"
}
