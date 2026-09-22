#Requires AutoHotkey v2.0
#SingleInstance Force

; Windows fires Start menu on Win release if no chord key was seen during
; the hold. GlazeWM consumes chord keys before Windows sees them, so every
; chord looks like a lone Win tap. Send an unassigned vk on Win press to
; preempt the trigger, then re-fire Start manually on detected lone taps.
;
; Both Win keys are hooked because the layouts differ: config_laptop.yaml
; binds lwin, config_kinesis.yaml and config_desktop.yaml bind rwin.

global g_WinDownAt := 0
global g_WinChord := false

; GlazeWM starts this script, so exit with it rather than being killed by an image-name taskkill that would take
; every other AutoHotkey script down too.
SetTimer(ExitWhenGlazeWMGone, 5000)

ExitWhenGlazeWMGone() {
    if !ProcessExist("glazewm.exe")
        ExitApp()
}

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
    ; Ctrl+Esc rather than a sent LWin: on a layout that binds lwin, GlazeWM's hook swallows the sent LWin too.
    if (!g_WinChord && (A_TickCount - g_WinDownAt) < 300)
        Send "^{Esc}"
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
