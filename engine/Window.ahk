; ============================================================
;  Window helpers
; ============================================================

ToggleAlwaysOnTop() {
    if (hwnd := WinExist("A"))
        try WinSetAlwaysOnTop(-1, hwnd)
}

; Make a window more (+step) or less (-step) opaque, on AutoHotkey's 0-255
; scale. It stops at about 12%, so a window can't vanish entirely.
AdjustTransparency(step, hwnd := WinExist("A")) {
    if !hwnd
        return
    try {
        level := NextOpacity(WinGetTransparent(hwnd), step)
        ; "Off" removes the layered style instead of leaving it at 255
        WinSetTransparent(level == 255 ? "Off" : level, hwnd)
        Notify("Opacity " Round(level * 100 / 255) "%", 800)
    }
}

; `current` is WinGetTransparent's result: "" means fully opaque.
NextOpacity(current, step) {
    static minimum := 30
    return Min(255, Max(minimum, (current == "" ? 255 : current) + step))
}

; Show a tooltip for `ms` milliseconds. A newer message restarts the timer
; instead of being hidden early by an older one.
Notify(text, ms := 1800) {
    static hide := () => ToolTip()
    ToolTip(text)
    SetTimer(hide, -ms)
}
