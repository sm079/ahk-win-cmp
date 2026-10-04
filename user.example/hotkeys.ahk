; Personal hotkeys, in plain AutoHotkey syntax.
; ! = Alt, ^ = Ctrl, + = Shift, # = Win

!c::OpenPalette()               ; command palette; press again for another one
^Space::ToggleAlwaysOnTop()
^!=::AdjustTransparency(+25)     ; Ctrl+Alt+= / Ctrl+Alt+- = active window opacity
^!-::AdjustTransparency(-25)
!LButton::RButton               ; Alt+click = right-click
