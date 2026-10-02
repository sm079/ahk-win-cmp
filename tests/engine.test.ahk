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

; ---- names ----------------------------------------------------------------
Check("Name plain", Namer.Name("Build me a Tiny todo-list app, please!"), "tiny-todo-list")
Check("Name maxWords", Namer.Name("one two three four five six", 3), "four-five-six")
Check("Name phrases", Namer.Name("I want a beginner friendly dashboard for PyTorch. Each run rents a "
    . "temporary cloud GPU server and streams training metrics."), "pytorch-cloud-gpu-server")
Check("Name local path", Namer.Name("have a look at D:\src\widget-kit project, refactor it"), "widget-kit")
Check("Name quoted path", Namer.Name('fix "C:\Users\Someone\Start Menu\launcher.ahk" startup lag'), "launcher-startup-lag")
Check("Name repo link", Namer.Name("make a web demo for https://github.com/someone/TinyParser/tree/v1.0.0"), "web-demo-tinyparser")
Check("Name other URLs dropped", Namer.Name("summarize https://example.com/a/b?q=1 nicely"), "summarize-nicely")
Check("Name markdown title", Namer.Name("# Inventory Tracker`n`n## Overview`n`nIt reads barcode scans and "
    . "matches them against a catalog of products, then updates stock levels."), "inventory-tracker")
Check("Name single word", Namer.Name("calculator"), "calculator")
Check("Name all stopwords", SubStr(Namer.Name("make it so"), 1, 8), "project-")

code := ""
Loop 2000
    code .= "    total += price[" A_Index "] * qty;`r`n"
code := "function sum(price, qty) {`r`n" code "}`r`n"
Check("Name code then request"
    , Namer.Name(code "`r`nThis function overflows on big carts. Fix the overflow bug."), "overflows-big-carts")
Check("Name request then fenced code"
    , Namer.Name("Port this parser to Rust:`r`n``````py`r`ndef parse(s):`r`n    return s`r`n``````"), "port-parser-rust")
Check("Name skips logs and lead-ins"
    , Namer.Name("Here is the error:`r`nTraceback (most recent call last):`r`n"
        . '  File "app.py", line 3, in <module>`r`nKeyError: `'id`'`r`n'
        . "PS C:\src> python app.py`r`nwhy does the login crash"), "login-crash")
Check("Name only code", SubStr(Namer.Name("x = 1;`r`ny = 2;"), 1, 8), "project-")

; idf: a word in every earlier description stops being distinctive
text := "dashboard showing weather maps"
Check("Name without corpus", Namer.Name(text, 3), "showing-weather-maps")
Loop 5
    Namer.Learn("another weather project number " A_Index)
Check("Name with corpus", Namer.Name(text, 3), "dashboard-showing-maps")
Namer._docs := 0, Namer._df := Map()

Namer.AddStopwords("Demo")
Check("AddStopwords", Namer.Name("a quick demo of sorting"), "quick-sorting")

Check("IsProse sentence", Namer.IsProse("Fix the overflow bug, please."), true)
Check("IsProse assignment", Namer.IsProse("const total = 5"), false)
Check("IsProse call", Namer.IsProse("print(x) and more words"), false)
Check("IsProse indented", Namer.IsProse("    some indented words here"), false)
Check("IsProse exception", Namer.IsProse("KeyError: 'id'"), false)

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

FileAppend(failures " of " total " failed`n", "*")
ExitApp(failures)
