#Requires AutoHotkey v2.0

; Turns the display off (WM_SYSCOMMAND, SC_MONITORPOWER, 2) so a Modern Standby machine drops into its own standby.
; SetSuspendState forces the legacy suspend path, which left the cursor invisible after resume on the laptop.
SendMessage(0x0112, 0xF170, 2, , "Program Manager")
