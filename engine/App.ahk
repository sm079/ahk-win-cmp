; ============================================================
;  App: the palette entry point and auto-reload
; ============================================================

; Open a new palette and dispatch whatever is entered. Calling it while a
; palette is open opens another one.
OpenPalette() => Palette(RunPaletteInput)

RunPaletteInput(text, hwnd) {
    if !Commands.Dispatch(text, hwnd)
        Notify("Unknown command: " Truncate(CollapseWhitespace(text), 80), 2500)
}

; Reload when any .ahk file under `dir` is added, removed or saved. A broken
; edit leaves this instance running (AutoHotkey only replaces it once the
; new one loads), and the stamp is updated first so it isn't retried.
ReloadOnChange(dir) {
    stamp := _FilesStamp(dir)
    SetTimer(Check, 1000)
    Check() {
        if ((now := _FilesStamp(dir)) != stamp) {
            stamp := now
            Reload()
        }
    }
}

_FilesStamp(dir) {
    s := ""
    Loop Files, dir "\*.ahk", "R"
        s .= A_LoopFilePath "|" A_LoopFileTimeModified "|" A_LoopFileSize "`n"
    return s
}
