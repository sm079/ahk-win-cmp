#Requires AutoHotkey v2.0
#SingleInstance Force
FileEncoding "UTF-8"

; Engine: generic, no personal paths or programs.
#Include %A_ScriptDir%\engine\Engine.ahk

; Personal configuration in user\ (copy user.example\ to get started).
if !FileExist(A_ScriptDir "\user\settings.ahk") {
    MsgBox("No configuration found.`n`nCopy the user.example folder to a folder named "
        . "user next to main.ahk, then edit the files in it.", "Command Palette", "Icon!")
    ExitApp()
}
#Include *i %A_ScriptDir%\user\settings.ahk
#Include *i %A_ScriptDir%\user\commands.ahk
#Include *i %A_ScriptDir%\user\hotkeys.ahk

A_TrayMenu.Add()
A_TrayMenu.Add("Open script folder", (*) => Run(A_ScriptDir))
