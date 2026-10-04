; Personal hotkeys, in plain AutoHotkey syntax.
; ! = Alt, ^ = Ctrl, + = Shift, # = Win

!c::OpenPalette()               ; command palette; press again for another one
^Space::ToggleAlwaysOnTop()
^!WheelUp::AdjustTransparency(+25)  ; Ctrl+Alt+wheel = active window opacity
^!WheelDown::AdjustTransparency(-25)
!LButton::RButton               ; Alt+click = right-click
