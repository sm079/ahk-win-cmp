; ============================================================
;  Text helpers: quoting, file names, URLs (no dependencies)
; ============================================================

CollapseWhitespace(s) => Trim(RegExReplace(s, "\s+", " "))

Truncate(s, maxLen) => (StrLen(s) > maxLen) ? SubStr(s, 1, maxLen - 3) "..." : s

; PowerShell single-quoted literal. PowerShell also treats the typographic
; single quotes as quote characters, so those are doubled too.
PsQuote(s) => "'" RegExReplace(s, "(['\x{2018}\x{2019}\x{201A}\x{201B}])", "$1$1") "'"

; Each whitespace-separated word as its own PowerShell literal.
PsQuoteWords(s) {
    out := ""
    for w in StrSplit(CollapseWhitespace(s), " ")
        if (w != "")
            out .= (out == "" ? "" : " ") PsQuote(w)
    return out
}

; Quote one argument for a Windows command line (CommandLineToArgvW rules).
QuoteArg(s) {
    if (s != "" && !RegExMatch(s, '[\s"]'))
        return s
    s := RegExReplace(s, '(\\*)"', '$1$1\"')     ; backslashes before a quote double up
    s := RegExReplace(s, '(\\+)$', '$1$1')       ; ...and so do trailing ones
    return '"' s '"'
}

; Percent-encode everything except ASCII letters and digits, as UTF-8.
UriEncode(s) {
    buf := Buffer(StrPut(s, "UTF-8"))
    StrPut(s, buf, "UTF-8")
    out := ""
    Loop buf.Size - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        out .= (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
            ? Chr(b) : Format("%{:02X}", b)
    }
    return out
}

; Remove characters that are illegal in Windows file names (keeps spaces).
SanitizeFileName(s) => Trim(RegExReplace(CollapseWhitespace(s), '[\\/:*?"<>|]'), " .")

; `path` if it doesn't exist yet, otherwise the first free  path_01, path_02, ...
UniqueDir(path) {
    if !FileExist(path)
        return path
    i := 1
    while FileExist(path Format("_{:02}", i))
        i++
    return path Format("_{:02}", i)
}
