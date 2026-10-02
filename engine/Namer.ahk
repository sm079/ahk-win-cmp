; ============================================================
;  Namer: a short, deterministic folder name for free text
; ============================================================

;  Made for descriptions that may be one line, or a request around thousands
;  of lines of code and logs. No model and no network; it takes milliseconds.
;
;    1. Keep the prose. Code, logs and fenced blocks only contribute their
;       identifiers (see IsProse).
;    2. Split the prose into candidate phrases at stopwords and punctuation,
;       up to 4 words each (RAKE).
;    3. Score each word by RAKE degree/frequency, boosted by how often it
;       occurs, and weight it by
;         idf       rarer in earlier descriptions = more telling
;         generic   words like "function" or "error" count for little
;         name      PyTorch, GPU, or a word that is also a code identifier
;    4. A phrase scores the sum of its words, with a bonus near the start or
;       end of the prose, where the request usually is.
;    5. The best phrases, plus any that come close, are joined in reading
;       order. A mixed-case name such as PyTorch is always kept.
;
;  Configuration (all optional):
;    Namer.UseCorpus(dir, fileName)  earlier descriptions, dir\*\fileName, as
;                                    the idf corpus; read on first use
;    Namer.AddStopwords(csv)         more words that never appear in a name
;    Namer.AddGeneric(csv)           more words that count for little

class Namer {
    ; Split phrases and are never part of a name: common English function
    ; words, plus the verbs of a request ("please create a ...").
    static Stopwords := Namer._Set("
    (Join,
        a,an,the,and,or,but,nor,if,then,else,so,to,of,in,on,at,by,for,with,from,into,onto,
        about,as,than,via,per,over,under,after,before,while,because,since,until,again,
        within,without,across,instead,is,are,was,were,be,been,being,am,do,does,did,done,
        have,has,had,it,its,this,that,these,those,there,here,what,which,who,whom,whose,
        when,where,why,how,i,me,my,mine,we,us,our,you,your,he,she,they,them,their,his,her,
        please,can,could,would,should,will,shall,may,might,must,want,wants,need,needs,
        like,let,lets,make,create,build,write,help,also,just,very,really,some,any,all,
        each,every,more,most,other,such,only,own,same,too,not,no,yes,ok,okay,thanks,
        thank,hi,hello,hey,etc,eg,ie,new,use,using,used,get,got,try,trying,able,maybe,
        sure,one,two,few,many,much,don't,doesn't,isn't,can't,won't,i'm,it's,that's,
        let's,i've,i'd,i'll,you're,there's,what's
    )")

    ; Kept, but worth little: they describe almost any project.
    static Generic := Namer._Set("
    (Join,
        function,functions,method,methods,class,classes,file,files,folder,code,data,
        value,values,error,errors,bug,bugs,issue,issues,problem,problems,user,users,
        thing,things,something,anything,everything,work,works,working,run,running,
        test,tests,python,javascript,typescript,script,scripts,program,app,apps,
        application,project,projects,tool,tools,simple,simpler,better,good,nice,
        version,line,lines,output,input,result,results,example,feature,features,
        support,stuff,part,time,step,steps,fix,add,change,update,following,below,
        above,return,true,false,null,none,string,int,var,const,let,def,self
    )")

    static _docs := 0                   ; corpus size
    static _df := Map()                 ; stem -> number of corpus documents containing it
    static _corpusDir := ""

    ; Name `text` with up to maxWords kebab-case words.
    static Name(text, maxWords := 4) {
        this._LoadCorpus()
        this._Split(text, &prose, &code, &refs, &title)
        phrases := this._Phrases(prose, &names, &total)
        for ref in refs                         ; repo / model names from links
            for w in ref
                names[w] := 3
        if (phrases.Count == 0) {               ; no prose: use the first line as is
            firstLine := RegExReplace(Trim(text, " `t`r`n"), "s)\R.*")
            phrases := this._Phrases(firstLine, &names, &total)
        }
        if (phrases.Count == 0)
            return "project-" FormatTime(, "yyyyMMdd-HHmmss")

        scores := this._WordScores(phrases, names, this._Identifiers(code))
        RegExReplace(title, "[\pL\pN]+", , &titleWords)
        top := this._TopPhrases(phrases, scores, total, titleWords, 12)
        return this._Pick(phrases, top, scores, names, refs, total, maxWords)
    }

    ; Use dir\*\fileName (earlier project descriptions) as the idf corpus.
    static UseCorpus(dir, fileName) {
        this._corpusDir := [dir, fileName]
    }

    static AddStopwords(csv) => this._Add(this.Stopwords, csv)
    static AddGeneric(csv) => this._Add(this.Generic, csv)

    ; Add one document to the corpus.
    static Learn(text) {
        this._Split(text, &prose, &code)
        seen := Map(), pos := 1
        while (pos := RegExMatch(prose, "[\pL\pN]+", &t, pos)) {
            seen[this._Stem(StrLower(t[0]))] := true
            pos += t.Len
        }
        for stem in seen
            this._df[stem] := this._df.Get(stem, 0) + 1
        this._docs++
    }

    ; Heuristic: does this single line read like a sentence rather than code?
    static IsProse(line) {
        if RegExMatch(line, "^(\t| {4})")                       ; indented
            return false
        line := Trim(line)
        if RegExMatch(line, "[:;{}\[(]$"                        ; lead-in, statement, block
            . "|^(//|/\*|\*|#|<|--|>>>|\$ |PS [A-Z]:|@)"         ; comment, markup, prompt
            . "|^[\w.]*(Error|Exception|Warning)\b"              ; exception message
            . "|^\[?(ERROR|WARN|INFO|DEBUG|TRACE|FATAL)\b"       ; log line
            . "|\s=\s|==|=>|->|::|\w\(|\);|^\w+\s*=")            ; assignment, call
            return false
        nonSpace := StrLen(RegExReplace(line, "\s"))
        letters  := StrLen(RegExReplace(line, "[^\pL]"))
        RegExReplace(line, "\pL{2,}", , &words)
        return words >= 2 && letters >= 0.75 * nonSpace
    }

    ; ---- steps -------------------------------------------------------------

    ; Prose lines and the rest. In prose, links to a repo or model become its
    ; name (`refs` gets their words), other URLs go, and paths are cut to their
    ; last part. A "# Title" first line and "## Section" headings are prose.
    static _Split(text, &prose, &code, &refs := "", &title := "") {
        static url := "i)\b[a-z][a-z0-9+.-]*://[^\s<>()\x22']*"
        prose := "", code := "", refs := [], title := "", fenced := false, first := true
        Loop Parse, text, "`n", "`r" {
            raw := A_LoopField
            if RegExMatch(raw, "^\s*(\x60{3}|~{3})") {              ; ``` or ~~~
                fenced := !fenced
                continue
            }
            if (first && RegExMatch(raw, "^#\s+\K\S.*", &t))
                title := t[0]
            heading := (first && title != "") || RegExMatch(raw, "^#{2,6}\s+\S")
            first := first && Trim(raw) == ""
            bare := Trim(RegExReplace(raw, url))
            if fenced || !(heading || this.IsProse(bare) || (bare == "" && Trim(raw) != "")) {
                code .= raw "`n"
                continue
            }
            line := RegExReplace(raw, "^#+\s+"), pos := 1
            while (pos := RegExMatch(line, url, &u, pos)) {
                name := this._UrlName(u[0])
                line := SubStr(line, 1, pos - 1) " " name " " SubStr(line, pos + u.Len)
                pos += StrLen(name) + 2
                if (name != "")
                    refs.Push(this._LowerWords(name))
            }
            line := RegExReplace(line, "\x22[A-Za-z]:\\[^\x22]*\\([^\x22\\]+)\x22", "$1")  ; "C:\a b\c" -> c
            line := RegExReplace(line, "[^\s\\/\x22']*[\\/]+(?=[^\s\\/])")                ; a\b\c -> c
            line := RegExReplace(line, "i)\b([\w-]+)\.(ahk|py|js|ts|tsx|jsx|md|txt|json|ya?ml|toml|"
                . "html?|css|ps1|bat|cmd|sh|exe|dll|c|h|cpp|hpp|cs|go|rs|java|kt|rb|php|"
                . "png|jpe?g|gif|svg|pdf|csv|xlsx?|docx?|zip)\b", "$1")                    ; x.py -> x
            prose .= Trim(line) "`n"
        }
    }

    ; Repo or package name in a GitHub / Hugging Face / npm / PyPI link, else "".
    static _UrlName(url) {
        if !RegExMatch(url, "i)^[a-z][a-z0-9+.-]*://(?:www\.)?([^/?#:]+)[^/]*/?([^?#]*)", &u)
            return ""
        seg := StrSplit(Trim(u[2], "/"), "/")
        switch StrLower(u[1]) {
            case "github.com", "gitlab.com", "bitbucket.org", "codeberg.org":
                i := 2
            case "huggingface.co":
                i := (seg.Length && RegExMatch(seg[1], "i)^(spaces|datasets)$")) ? 3 : 2
            case "npmjs.com", "pypi.org", "crates.io":
                i := 2
            default:
                return ""
        }
        return (seg.Length >= i) ? RegExReplace(seg[i], "i)\.git$") : ""
    }

    static _LowerWords(s) {
        words := []
        for w in StrSplit(RegExReplace(StrLower(s), "[^\pL\pN]+", " "), " ")
            if (w != "")
                words.Push(w)
        return words
    }

    ; Candidate phrases: runs of up to 4 non-stopwords, split by stopwords,
    ; punctuation and line breaks. Returns Map(phrase -> {words, count, first,
    ; last}); positions count words. `names` gets the name-like words.
    static _Phrases(prose, &names, &total) {
        phrases := Map(), names := Map(), total := 0, run := [], runAt := 0
        Flush() {
            if !run.Length
                return
            key := ""
            for w in run
                key .= (key == "" ? "" : " ") w
            if !phrases.Has(key)
                phrases[key] := { words: run, count: 0, first: runAt, last: runAt }
            p := phrases[key], p.count += 1, p.last := runAt
            run := []
        }

        pos := 1
        while (pos := RegExMatch(prose, "[\pL\pN]+(?:['\x{2019}]\pL+)?|\n|[^\pL\pN\s_-]", &t, pos)) {
            pos += t.Len
            tok := t[0]
            if !RegExMatch(tok, "^[\pL\pN]") {          ; punctuation or line break
                Flush()
                continue
            }
            total++
            w := RegExReplace(StrLower(tok), "['\x{2019}]s$")
            if (StrLen(w) < 2 || IsDigit(w) || this.Stopwords.Has(w)) {
                Flush()
                continue
            }
            if RegExMatch(tok, "^.+\p{Lu}") && RegExMatch(tok, "\p{Ll}")
                names[w] := 3                           ; PyTorch, WebGPU, iPhone
            else if RegExMatch(tok, "^\p{Lu}{2,}\d*$")
                names[w] := Max(names.Get(w, 0), 1.5)   ; GPU, API
            if !run.Length
                runAt := total
            run.Push(w)
            if (run.Length == 4)
                Flush()
        }
        Flush()
        return phrases
    }

    ; Words (split from camelCase / snake_case) of the identifiers in code.
    ; Only the first and last 100 KB are read.
    static _Identifiers(code) {
        if (StrLen(code) > 200000)
            code := SubStr(code, 1, 100000) SubStr(code, -100000)
        words := Map(), seen := Map(), pos := 1
        while (pos := RegExMatch(code, "[A-Za-z_][A-Za-z0-9_]{2,}", &t, pos)) {
            pos += t.Len
            if seen.Has(t[0])
                continue
            seen[t[0]] := true
            id := RegExReplace(t[0], "([a-z0-9])([A-Z])", "$1 $2")
            id := RegExReplace(id, "([A-Z]+)([A-Z][a-z])", "$1 $2")
            for w in StrSplit(StrLower(StrReplace(id, "_", " ")), " ")
                if (StrLen(w) > 1)
                    words[this._Stem(w)] := true
        }
        return words
    }

    ; Map(stem -> score), see the top of this file.
    static _WordScores(phrases, names, idents) {
        freq := Map(), deg := Map(), boost := Map()
        for , p in phrases
            for w in p.words {
                s := this._Stem(w)
                freq[s] := freq.Get(s, 0) + p.count
                deg[s] := deg.Get(s, 0) + p.words.Length * p.count
                b := names.Get(w, idents.Has(s) ? 1.25 : 1)
                boost[s] := Max(boost.Get(s, 1), b)
                if this.Generic.Has(w)
                    boost[s] := boost[s] * 0.3
            }
        scores := Map()
        for s, f in freq
            scores[s] := deg[s] / f * (1 + Ln(f)) * this._Idf(s) * boost[s]
        return scores
    }

    ; The k best phrases, best first.
    static _TopPhrases(phrases, scores, total, titleWords, k) {
        top := []
        for , p in phrases {
            score := 0
            for w in p.words
                score += scores[this._Stem(w)]
            if (p.first <= titleWords)              ; in a "# Title" first line
                score *= 3
            if (p.first <= 40)
                score *= 1.5
            if (p.last > total - 40)
                score *= 1.3
            p.score := score
            i := top.Length
            while (i >= 1 && top[i].score < score)
                i--
            if (i < k)
                top.InsertAt(i + 1, p)
            if (top.Length > k)
                top.Pop()
        }
        return top
    }

    static _Pick(phrases, top, scores, names, refs, total, maxWords) {
        chosen := [], used := Map(), n := 0

        ; Keep the strongest name, a linked repo or model or a mixed-case word
        ; such as PyTorch, even if its phrase scores lower; but only one that
        ; appears near the start or end, and leave room for one more word.
        cands := refs.Clone()
        for w, b in names
            if (b == 3)
                cands.Push([w])
        brand := "", best := 0, brandAt := 0
        for c in cands {
            at := 0x7FFFFFFF, last := 0
            for , p in phrases
                for w in p.words
                    if (w == c[1])
                        at := Min(at, p.first), last := Max(last, p.last)
            if (at > 40 && last <= total - 40)
                continue
            score := 0
            for w in c
                score += scores.Get(this._Stem(w), 0)
            if (score > best)
                brand := c, best := score, brandAt := at
        }
        if brand {
            words := []
            for w in brand
                if (A_Index < maxWords && !used.Has(this._Stem(w)))
                    words.Push(w), used[this._Stem(w)] := true
            chosen.Push({ words: words, first: brandAt })
            n := words.Length
        }

        for p in top {
            if (n >= maxWords || (n >= 2 && p.score < 0.4 * top[1].score))
                break
            fresh := []
            for w in this._TrimGeneric(p.words)
                if !used.Has(this._Stem(w))
                    fresh.Push(w)
            if !fresh.Length
                continue
            if (n + fresh.Length > maxWords) {
                if (n >= 2)
                    continue
                fresh := this._Best(fresh, maxWords - n, scores)
            }
            for w in fresh
                used[this._Stem(w)] := true
            chosen.Push({ words: fresh, first: p.first })
            n += fresh.Length
        }

        ; Reading order.
        Loop chosen.Length - 1 {
            i := A_Index + 1, c := chosen[i]
            while (i > 1 && chosen[i - 1].first > c.first)
                chosen[i] := chosen[i - 1], i--
            chosen[i] := c
        }
        slug := ""
        for c in chosen
            for w in c.words
                slug .= (slug == "" ? "" : "-") RegExReplace(w, "[^a-z0-9]+", "-")
        return Trim(RegExReplace(slug, "-+", "-"), "-")
    }

    ; Drop generic words from the ends of a phrase ("todo list app" -> "todo
    ; list"); a phrase of only generic words yields nothing.
    static _TrimGeneric(words) {
        a := 1, b := words.Length
        while (a <= b && this.Generic.Has(words[a]))
            a++
        while (b >= a && this.Generic.Has(words[b]))
            b--
        out := []
        Loop b - a + 1
            out.Push(words[a + A_Index - 1])
        return out
    }

    ; The k best-scoring words, in their original order.
    static _Best(words, k, scores) {
        words := words.Clone()
        while (words.Length > k) {
            low := 1
            for w in words
                if (scores[this._Stem(w)] < scores[this._Stem(words[low])])
                    low := A_Index
            words.RemoveAt(low)
        }
        return words
    }

    static _LoadCorpus() {
        if !this._corpusDir
            return
        dir := this._corpusDir[1], fileName := this._corpusDir[2]
        this._corpusDir := ""
        Loop Files, dir "\*", "D"
            if FileExist(f := A_LoopFilePath "\" fileName)
                try this.Learn(FileRead(f, "UTF-8"))
    }

    static _Idf(stem) => Ln((this._docs + 1) / (this._df.Get(stem, 0) + 1)) + 1

    ; Crude plural/tense folding so "workflow" and "workflows" count together.
    static _Stem(w) => StrLen(w) > 4 ? RegExReplace(w, "(ies|es|s|ing|ed)$") : w

    static _Set(csv) => Namer._Add(Map(), csv)

    static _Add(set, csv) {
        for w in StrSplit(csv, ",", " `t`r`n")
            if (w != "")
                set[StrLower(w)] := true
        return set
    }
}
