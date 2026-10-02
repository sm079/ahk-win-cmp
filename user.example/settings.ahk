; Personal settings: plain AutoHotkey. Copy user.example\ to user\ and edit
; the files there; user\ is not tracked by git.
;
; API keys: don't put them in these files. Store them as Windows user
; environment variables (e.g.  setx SOME_API_KEY "..." ) and every program
; started from the palette inherits them. Restart the script afterwards.

Shell.Exe        := "powershell.exe"        ; or "pwsh.exe"
Shell.Terminal   := "wt.exe"                ; "" = plain console window
Shell.DefaultDir := A_MyDocuments           ; terminals open here when there's no folder

ReloadOnChange(A_ScriptDir)                 ; reload when a .ahk file here is saved

; Your own values, used by user\commands.ahk.
global Settings := {
    ProjectsDir: A_MyDocuments "\Projects",
    VSCode:      "code"
}
