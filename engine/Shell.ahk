; ============================================================
;  Shell: launching programs, terminals and PowerShell scripts
; ============================================================

;  Scripts are handed to PowerShell with -EncodedCommand, so no quoting
;  layer (cmd.exe, Windows Terminal, the argv parser) can mangle them.
;  Use PsQuote() for any user text placed inside a script.

class Shell {
    static Exe        := "powershell.exe"   ; powershell.exe or pwsh.exe
    static Terminal   := "wt.exe"           ; Windows Terminal; "" = plain console window
    static DefaultDir := A_MyDocuments      ; used when no (existing) directory is given

    ; Interactive shell in `dir`.
    static OpenTerminal(dir := "") {
        dir := this._Dir(dir)
        if (this.Terminal != "")
            Run(QuoteArg(this.Terminal) " -d " this._WtArg(dir), dir)
        else
            Run(QuoteArg(this.Exe) " -NoLogo", dir)
    }

    ; Run a PowerShell script in a visible window that stays open afterwards.
    static Run(script, dir := "") {
        dir := this._Dir(dir)
        line := QuoteArg(this.Exe) " -NoLogo -NoExit -EncodedCommand " this.Encode(script)
        if (this.Terminal != "")
            line := QuoteArg(this.Terminal) " -d " this._WtArg(dir) " " line
        Run(line, dir)
    }

    ; Run a PowerShell script with no window. Returns the process ID.
    static RunHidden(script, dir := "") {
        Run(QuoteArg(this.Exe) " -NoLogo -NoProfile -NonInteractive -EncodedCommand "
            this.Encode(script), this._Dir(dir), "Hide", &pid)
        return pid
    }

    ; Base64 of the UTF-16LE text, as -EncodedCommand expects.
    static Encode(script) {
        buf := Buffer(StrPut(script, "UTF-16"))
        StrPut(script, buf, "UTF-16")
        bytes := buf.Size - 2                           ; drop the null terminator
        flags := 0x40000001                             ; CRYPT_STRING_BASE64 | NOCRLF
        DllCall("crypt32\CryptBinaryToStringW", "ptr", buf, "uint", bytes, "uint", flags
            , "ptr", 0, "uint*", &chars := 0)
        out := Buffer(chars * 2)
        DllCall("crypt32\CryptBinaryToStringW", "ptr", buf, "uint", bytes, "uint", flags
            , "ptr", out, "uint*", &chars)
        b64 := StrGet(out, "UTF-16")
        if (StrLen(b64) > 30000)
            throw ValueError("Script too long for a command line", -2)
        return b64
    }

    static _Dir(dir) => (dir != "" && DirExist(dir)) ? dir : this.DefaultDir

    ; Windows Terminal splits its command line on ";" unless escaped.
    static _WtArg(s) => QuoteArg(StrReplace(s, ";", "\;"))
}

; Start a program with no console window (e.g. a .cmd shim like VS Code's `code`).
LaunchHidden(exe, args*) {
    line := QuoteArg(exe)
    for a in args
        line .= " " QuoteArg(a)
    Run(A_ComSpec ' /s /c "' line '"', , "Hide")
}

; Open a folder, file, URL or command line the way Explorer would.
; "*verb target" uses that shell verb, e.g. "*edit C:\notes.txt".
OpenTarget(target) {
    if DirExist(target) {
        Run(QuoteArg(target))
    } else if FileExist(target) {
        SplitPath(target, , &dir)
        Run(QuoteArg(target), dir)
    } else {
        Run(target)
    }
}
