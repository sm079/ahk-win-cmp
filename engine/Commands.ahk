; ============================================================
;  Commands: what the palette dispatches to
; ============================================================

;  A command is a regex plus a handler. The first pattern that matches the
;  input wins and its handler is called as  handler(m, ctx)  where
;    m   - the RegExMatchInfo (m[1], m["name"], ...)
;    ctx - a CommandContext: ctx.input, ctx.hwnd, ctx.here
;  Input that matches no pattern is looked up in Aliases.

class Commands {
    static List := []

    static Add(pattern, handler) => this.List.Push({ pattern: pattern, handler: handler })

    ; Returns true if a command or an alias handled the input.
    static Dispatch(input, hwnd := 0) {
        ctx := CommandContext(input, hwnd)
        for cmd in this.List {
            if !RegExMatch(input, cmd.pattern, &m)
                continue
            try {
                cmd.handler.Call(m, ctx)
            } catch Error as e {
                MsgBox("Command failed: " cmd.pattern "`n`n" e.Message
                    . (e.Extra != "" ? "`n" e.Extra : ""), "Command Palette", "Icon!")
            }
            return true
        }

        target := Aliases.Lookup(input)
        if (target == "")
            return false
        try {
            OpenTarget(target)
        } catch Error as e {
            MsgBox("Could not open:`n" target "`n`n" e.Message, "Command Palette", "Icon!")
        }
        return true
    }
}

class CommandContext {
    __New(input, hwnd) {
        this.input := input         ; the full text that was entered
        this.hwnd  := hwnd          ; window that was active when the palette opened
    }

    ; Folder shown by that window (Explorer or the Desktop), else "".
    here => FolderOfWindow(this.hwnd)
}

; Exact names (case-insensitive) that open a folder, file, program or URL;
; see OpenTarget() for what a target can be.
class Aliases {
    static Items := Map()

    static Add(name, target) => this.Items[StrLower(name)] := target
    static Lookup(name) => this.Items.Get(StrLower(name), "")
}
