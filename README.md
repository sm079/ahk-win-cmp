# ahk-generic

A small AutoHotkey v2 command palette and hotkey toolkit. The engine is
generic: every path, program, hotkey and command lives in your own config
folder, `user\`, which git ignores. Config is plain AutoHotkey, not a
settings format, so anything the language can do, your config can do.

## Setup

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Copy `user.example\` to `user\` and edit the files in it.
3. Run `main.ahk`. To start it with Windows, put a shortcut to it in
   `shell:startup`.

## Layout

```
main.ahk            entry point: loads the engine, then your config
engine\             generic code, no personal data
  Engine.ahk        includes the rest (the parts don't include each other)
  Palette.ahk       the command input window
  Commands.ahk      command registry, command context, aliases
  Shell.ahk         terminals, PowerShell scripts, opening files
  Namer.ahk         folder names from free text (no model, see below)
  Explorer.ahk      folder shown by an Explorer window / the Desktop
  App.ahk           palette entry point, reload on save
  Window.ahk        always-on-top, tooltips
  Text.ahk          quoting, URL encoding, file names
user.example\       template for user\
  settings.ahk      shell options, your paths and programs
  hotkeys.ahk       hotkeys, in AutoHotkey's own syntax
  commands.ahk      palette commands and aliases
tests\              engine self-test
```

## Palette

Press the palette hotkey (`Alt+C` in the example), type a command and press
Enter. Shift+Enter adds a line break; Esc cancels. Pressing the hotkey while
a palette is open opens another one, so you can start a second command while
writing a long first one. Each palette remembers the window it was opened
from.

Input is matched against the patterns in `user\commands.ahk` in order. If
none matches, it is looked up in the aliases.

### Adding commands

```ahk
; regex, then a handler called as handler(m, ctx)
Commands.Add("^\.$", (m, ctx) => Shell.OpenTerminal(ctx.here))
Commands.Add("is)^yt\s+(?<urls>.+)$", (m, ctx) => Shell.Run("yt-dlp " PsQuoteWords(m["urls"]), Settings.MusicDir))
```

`m` is the regex match (`m[1]`, `m["name"]`). `ctx.input` is the full text,
`ctx.hwnd` the window that was active when the palette opened, and
`ctx.here` the folder that window shows (Explorer or the Desktop), or `""`.

`Shell.Run(script, dir)` runs a PowerShell script in a terminal,
`Shell.RunHidden(script, dir)` runs it with no window, `Shell.OpenTerminal(dir)`
opens a shell, `OpenTarget(target)` opens a folder, file or URL, and
`LaunchHidden(exe, args*)` starts a program without a console window.

Scripts reach PowerShell through `-EncodedCommand`, so cmd.exe, Windows
Terminal and argument parsing can't mangle them. Always quote user text with
`PsQuote()` (or `PsQuoteWords()` for a list).

### Aliases

Exact names (case-insensitive) that open a folder, file, program or URL:

```ahk
tools := "D:\Tools"
Aliases.Add("tl", tools)
Aliases.Add("ed", tools "\editor\editor.exe")
Aliases.Add("cmd", "*edit " QuoteArg(A_LineFile))   ; "*verb target" uses a shell verb
```

## Settings and secrets

`user\settings.ahk` sets engine options directly (`Shell.Terminal := "wt.exe"`)
and keeps your own values in a `Settings` object for your commands.
`ReloadOnChange(A_ScriptDir)` reloads the script whenever a `.ahk` file in
the project is saved; a file with an error is reported and the running
version keeps working.

Don't put API keys in these files. Store them as Windows user environment
variables (`setx SOME_API_KEY "..."`); every program started from the
palette inherits them. Restart the script after changing one.

## Folder names from descriptions

`Namer.Name(text)` turns a description into a short folder name such as
`pytorch-cloud-gpu-server`. It is deterministic, needs no model or network,
and handles a request pasted before or after thousands of lines of code in
milliseconds:

1. Only the prose is used. Fenced blocks, indented lines, code-like lines,
   logs, stack traces and lead-ins ending in `:` are skipped. A `# Title`
   on the first line counts, with a strong bonus.
2. Links to GitHub, Hugging Face, npm or PyPI become the repo or package
   name. Other URLs are dropped, and paths are cut to their last part.
3. The prose is split into candidate phrases at stopwords and punctuation
   (RAKE). Each word is scored by RAKE degree/frequency, boosted by how
   often it occurs and weighted by:
   - idf: how rare it is in your earlier descriptions;
   - a penalty for generic words (`function`, `error`, `app`);
   - a bonus for names (`PyTorch`, `GPU`) and words that are also code
     identifiers;
   - a bonus near the start or end of the prose, where the request usually is.
4. The best phrases are joined in reading order. A linked repo or a
   mixed-case name near the start or end is always kept.

`Namer.UseCorpus(dir, "NOTES.md")` uses `dir\*\NOTES.md` as the idf corpus;
it is read the first time a name is needed. The built-in word lists are
standard English stopwords and generic programming words; add your own with
`Namer.AddStopwords("...")` and `Namer.AddGeneric("...")` in
`user\settings.ahk`. `UniqueDir(path)` adds `_01`,
`_02`, ... when a folder of that name already exists.

## Tests

From PowerShell or cmd:

```
AutoHotkey64.exe /ErrorStdOut tests\engine.test.ahk > results.txt
```

This prints PASS/FAIL lines, and the exit code is the number of failures.
AutoHotkey is a GUI program, so redirect its output to a file to see it.
From Git Bash, prefix the command with `MSYS_NO_PATHCONV=1`, or Bash turns
`/ErrorStdOut` into a path.
