#Requires AutoHotkey v2.0
#SingleInstance Force

; Windows fires Start menu on Win release if no chord key was seen during
; the hold. GlazeWM consumes chord keys before Windows sees them, so every
; chord looks like a lone Win tap. Send an unassigned vk on RWin press to
; preempt the trigger, then re-fire Start manually on detected lone taps.

global g_RWinDownAt := 0
global g_RWinChord := false

~RWin::
{
    global g_RWinDownAt, g_RWinChord
    g_RWinDownAt := A_TickCount
    g_RWinChord := false
    Send "{Blind}{vkFF}"
    SetTimer(WatchRWinChord, 10)
}

~RWin Up::
{
    global g_RWinDownAt, g_RWinChord
    SetTimer(WatchRWinChord, 0)
    if (!g_RWinChord && (A_TickCount - g_RWinDownAt) < 300)
        Send "{LWin}"
}

WatchRWinChord() {
    global g_RWinChord
    if (g_RWinChord)
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
            g_RWinChord := true
            return
        }
    }
}
