#Requires AutoHotkey v2.0
#SingleInstance Force

; Windows fires Start menu on Win release if no chord key was seen during
; the hold. GlazeWM consumes chord keys before Windows sees them, so every
; chord looks like a lone Win tap. Send an unassigned vk on Win press to
; preempt the trigger, then re-fire Start manually on detected lone taps.
;
; Both Win keys are hooked because this machine swaps configs: config.yaml
; binds lwin (builtin keyboard), kinesis_config.yaml binds rwin.

global g_WinDownAt := 0
global g_WinChord := false

~LWin::
~RWin::
{
    global g_WinDownAt, g_WinChord
    g_WinDownAt := A_TickCount
    g_WinChord := false
    Send "{Blind}{vkFF}"
    SetTimer(WatchWinChord, 10)
}

~LWin Up::
~RWin Up::
{
    global g_WinDownAt, g_WinChord
    SetTimer(WatchWinChord, 0)
    ; Safe to re-fire LWin from inside an LWin hotkey: Send defaults to level 0
    ; and a hotkey only triggers on input above its own level, so this cannot recurse.
    if (!g_WinChord && (A_TickCount - g_WinDownAt) < 300)
        Send "{LWin}"
}

WatchWinChord() {
    global g_WinChord
    if (g_WinChord)
        return
    static keys := unset
    if !IsSet(keys) {
        keys := []
        Loop 26
            keys.Push(Format("vk{:X}", 0x40 + A_Index))
        Loop 10
            keys.Push(Format("vk{:X}", 0x30 + A_Index - 1))
        for k in ["Enter", "Tab", "Space", "Left", "Right", "Up", "Down", "Escape"]
            keys.Push(k)
    }
    for k in keys {
        if (GetKeyState(k, "P")) {
            g_WinChord := true
            return
        }
    }
}
