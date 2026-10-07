; Engine self-test. Run from PowerShell or cmd:
;   AutoHotkey64.exe /ErrorStdOut tests\engine.test.ahk > results.txt
; Prints PASS/FAIL lines and exits with the number of failures.
#Requires AutoHotkey v2.0
#NoTrayIcon
#Warn All, StdOut
#Warn LocalSameAsGlobal, Off   ; the test body below runs at global scope
FileEncoding "UTF-8"
; Report an uncaught error and exit, instead of waiting on an error dialog.
OnError((e, *) => (FileAppend("ERROR " e.Message " (line " e.Line ")`n", "*"), ExitApp(99)))

#Include %A_ScriptDir%\..\engine\Engine.ahk

global failures := 0, total := 0
Check(name, actual, expected) {
    global failures, total
    total++
    ok := (actual == expected)
    if !ok
        failures++
    FileAppend((ok ? "PASS " : "FAIL ") name
        . (ok ? "" : "`n     got:      [" actual "]`n     expected: [" expected "]") "`n", "*")
}

; ---- quoting --------------------------------------------------------------
Check("QuoteArg plain", QuoteArg("abc"), "abc")
Check("QuoteArg spaces", QuoteArg("a b"), '"a b"')
Check("QuoteArg trailing backslash", QuoteArg("C:\My Dir\"), '"C:\My Dir\\"')
Check("QuoteArg embedded quote", QuoteArg('say "hi"'), '"say \"hi\""')
Check("QuoteArg empty", QuoteArg(""), '""')
Check("PsQuote", PsQuote("it's"), "'it''s'")
Check("PsQuote smart quote", PsQuote("it" Chr(0x2019) "s"), "'it" Chr(0x2019) Chr(0x2019) "s'")
Check("PsQuoteWords", PsQuoteWords("  a&b`n c "), "'a&b' 'c'")
Check("UriEncode", UriEncode("a b/é"), "a%20b%2F%C3%A9")
Check("Encode", Shell.Encode("echo hi"), "ZQBjAGgAbwAgAGgAaQA=")

; ---- file names -----------------------------------------------------------
Check("SanitizeFileName", SanitizeFileName("  a:b/c?`n d. "), "abc d")
dir := A_Temp "\ahk-test-" A_TickCount
DirCreate(dir)
Check("UniqueDir taken", UniqueDir(dir), dir "_01")
DirCreate(dir "_01")
Check("UniqueDir taken twice", UniqueDir(dir), dir "_02")
DirDelete(dir "_01")
DirDelete(dir)
Check("UniqueDir free", UniqueDir(dir), dir)

; ---- commands -------------------------------------------------------------
global ran := []
Commands.Add("^hello (?<who>\w+)$", (m, ctx) => ran.Push("hello " m["who"] " " ctx.input))
Commands.Add("^hello", (m, ctx) => ran.Push("second"))
Aliases.Add("hello world", "unused")
Check("Dispatch first match wins", Commands.Dispatch("hello bob") && ran.Length == 1 && ran[1], "hello bob hello bob")
Check("Dispatch unknown", Commands.Dispatch("nothing matches this"), false)
Check("CommandContext here (no window)", CommandContext("x", 0).here, "")

Aliases.Add("Dl", "C:\Data\Down loads")
Check("alias case-insensitive", Aliases.Lookup("dL"), "C:\Data\Down loads")
Check("alias missing", Aliases.Lookup("nope"), "")

; ---- windows --------------------------------------------------------------
Check("NextOpacity from opaque", NextOpacity("", -25), 230)
Check("NextOpacity up", NextOpacity(100, 25), 125)
Check("NextOpacity caps at opaque", NextOpacity(240, 25), 255)
Check("NextOpacity floor", NextOpacity(40, -25), 30)

FileAppend(failures " of " total " failed`n", "*")
ExitApp(failures)
