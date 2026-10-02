; ============================================================
;  Explorer: which folder is a window showing?
; ============================================================

; Folder shown by the given window: the active tab of an Explorer window,
; or the Desktop. Returns "" for anything else (and for virtual folders
; such as "This PC" that have no file system path).
FolderOfWindow(hwnd) {
    if !hwnd || !WinExist(hwnd)
        return ""
    cls := WinGetClass(hwnd)
    if (cls == "Progman" || cls == "WorkerW")
        return A_Desktop
    if (cls != "CabinetWClass" && cls != "ExploreWClass")
        return ""

    ; Windows 11 Explorer has tabs that all share the top-level hwnd; the
    ; first ShellTabWindowClass control is the one currently shown.
    activeTab := 0
    try activeTab := ControlGetHwnd("ShellTabWindowClass1", hwnd)

    static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
    for win in ComObject("Shell.Application").Windows {
        try {
            if (win.hwnd != hwnd)
                continue
            if activeTab {
                browser := ComObjQuery(win, IID_IShellBrowser, IID_IShellBrowser)
                ComCall(3, browser, "uint*", &tab := 0)     ; IOleWindow::GetWindow
                if (tab != activeTab)
                    continue
            }
            path := win.Document.Folder.Self.Path
            return DirExist(path) ? path : ""
        }
    }
    return ""
}
