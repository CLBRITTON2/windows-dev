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
    global g_WinDownAt
    g_WinDownAt := A_TickCount
    Send "{Blind}{vkFF}"
}

~LWin Up::
~RWin Up::
{
    global g_WinDownAt
    ; A_PriorKey ignores script-sent input (the vkFF above), so it names the Win key itself only when nothing else was
    ; pressed during the hold. Polling physical key state instead misread a lone tap as a chord.
    winKey := SubStr(A_ThisHotkey, 2, 4)
    ; Ctrl+Esc rather than a sent LWin: on a layout that binds lwin, GlazeWM's hook swallows the sent LWin too.
    if (A_PriorKey = winKey && (A_TickCount - g_WinDownAt) < 300)
        Send "^{Esc}"
}
