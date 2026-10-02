; Personal palette commands. First matching pattern wins; anything that
; matches nothing is looked up in the aliases below.
; Handlers are called as  handler(m, ctx)  - see engine\Commands.ahk.

; .              terminal in the folder of the window you came from
Commands.Add("^\.$", (m, ctx) => Shell.OpenTerminal(ctx.here))

; c <name>       create/open  ProjectsDir\<name>  in VS Code
Commands.Add("is)^c\s+(?<name>.+)$", OpenProject)

; gs             git status of the current folder, in a terminal
Commands.Add("^gs$", (m, ctx) => Shell.Run("git status", ctx.here))

; g <words>      web search
Commands.Add("is)^g\s+(?<q>.+)$", (m, ctx) => OpenTarget("https://duckduckgo.com/?q=" UriEncode(m["q"])))


; ---- Aliases: exact name -> folder / file / program / URL ----------------

Aliases.Add("doc",     A_MyDocuments)
Aliases.Add("dl",      EnvGet("USERPROFILE") "\Downloads")
Aliases.Add("np",      "notepad.exe")
Aliases.Add("startup", A_Startup)
Aliases.Add("cmd",     "*edit " QuoteArg(A_LineFile))          ; this file, in the editor


OpenProject(m, ctx) {
    name := SanitizeFileName(m["name"])
    if (name == "") {
        Notify("Invalid project name")
        return
    }
    path := Settings.ProjectsDir "\" name
    Notify((DirExist(path) ? "Opening: " : "Created: ") path)
    DirCreate(path)
    LaunchHidden(Settings.VSCode, path)
}
