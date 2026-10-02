; ============================================================
;  Palette: a command input window
; ============================================================

;  Every Palette(onSubmit) is its own window, so several can be open at once.
;  onSubmit(text, hwnd) is called with the trimmed input after the palette
;  closes; hwnd is the window that was active when it opened.

class Palette {
    static All := Map()             ; hwnd -> Palette, for every open palette

    ; Shift+Enter / Ctrl+Enter insert a line break in the active palette.
    static __New() {
        if (this != Palette)
            return
        HotIf((*) => Palette.Active())
        Hotkey("+Enter", (*) => Palette.Active().Newline())
        Hotkey("^Enter", (*) => Palette.Active().Newline())
        HotIf()
    }

    static Active() => Palette.All.Get(WinActive("A"), "")

    __New(onSubmit) {
        this.onSubmit := onSubmit
        this.returnTo := WinExist("A")          ; gets focus back afterwards
        ; Opened from another palette: act on the window *that* one came from.
        from := Palette.All.Get(this.returnTo, "")
        this.target := from ? from.target : this.returnTo

        g := Gui("+AlwaysOnTop +Resize +MinSize420x180", "Command Palette")
        g.MarginX := 12, g.MarginY := 12
        g.SetFont("s10", "Consolas")
        ; -WantReturn: Enter presses the default button
        this.edit := g.AddEdit("xm ym w560 h160 +Multi -WantReturn")
        g.SetFont("s9", "Segoe UI")
        this.hint := g.AddText("xm y+8 w560 c808080"
            , "Enter = run     Shift+Enter = new line     Esc = cancel")
        this.runBtn := g.AddButton("xm y+8 w90 h26 Default", "Run")
        this.cancelBtn := g.AddButton("x+8 yp w90 h26", "Cancel")

        this.runBtn.OnEvent("Click", (*) => this.Submit())
        this.cancelBtn.OnEvent("Click", (*) => this.Close())
        g.OnEvent("Close", (*) => this.Close())
        g.OnEvent("Escape", (*) => this.Close())
        g.OnEvent("Size", (g, minMax, w, h) => this.Layout(minMax, w, h))

        this.gui := g
        offset := Palette.All.Count * 30        ; cascade over the ones already open
        Palette.All[g.Hwnd] := this
        g.Show()
        if offset {
            g.GetPos(&x, &y)
            g.Move(x + offset, y + offset)
        }
        this.edit.Focus()
    }

    Newline() => EditPaste("`r`n", this.edit)

    Close() {
        if !this.gui
            return
        Palette.All.Delete(this.gui.Hwnd)
        try this.gui.Destroy()
        this.gui := ""
    }

    Submit() {
        if !this.gui
            return
        text := Trim(this.edit.Value, " `t`r`n")
        this.Close()
        ; Hand focus back explicitly; Windows doesn't reliably reactivate the
        ; previous window when an always-on-top window is destroyed.
        if (this.returnTo && WinExist(this.returnTo))
            try WinActivate(this.returnTo)
        if (text != "")
            this.onSubmit.Call(text, this.target)
    }

    Layout(minMax, w, h) {
        if (minMax == -1 || !this.gui)              ; minimised
            return
        m := 12, hintH := 18, btnH := 26, gap := 8
        editW := w - m * 2
        editH := Max(60, h - m * 2 - hintH - btnH - gap * 2)
        yHint := m + editH + gap
        yBtn  := yHint + hintH + gap
        this.edit.Move(m, m, editW, editH)
        this.hint.Move(m, yHint, editW, hintH)
        this.runBtn.Move(m, yBtn, 90, btnH)
        this.cancelBtn.Move(m + 98, yBtn, 90, btnH)
        WinRedraw(this.gui.Hwnd)
    }
}
