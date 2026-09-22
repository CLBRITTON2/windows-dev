#Requires AutoHotkey v2.0

; Not rundll32 powrprof.dll,SetSuspendState: rundll32 passes it garbage arguments, so it hibernates whenever
; hibernation is enabled.
DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
