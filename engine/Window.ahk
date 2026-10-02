; ============================================================
;  Window helpers
; ============================================================

ToggleAlwaysOnTop() {
    if (hwnd := WinExist("A"))
        try WinSetAlwaysOnTop(-1, hwnd)
}

; Show a tooltip for `ms` milliseconds. A newer message restarts the timer
; instead of being hidden early by an older one.
Notify(text, ms := 1800) {
    static hide := () => ToolTip()
    ToolTip(text)
    SetTimer(hide, -ms)
}
