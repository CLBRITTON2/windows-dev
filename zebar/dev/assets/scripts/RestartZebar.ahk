#Requires AutoHotkey v2.0
#SingleInstance Force

RunWait("taskkill /F /IM zebar.exe", , "Hide")
Sleep(1000)
Run("zebar", , "Hide")
ExitApp()
