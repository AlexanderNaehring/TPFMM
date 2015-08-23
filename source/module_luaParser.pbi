XIncludeFile "module_debugger.pbi"
XIncludeFile "module_mods.h.pbi"

DeclareModule luaParser
  EnableExplicit
  
  Declare parseInfoLUA(file$, *mod.mods::mod)
  
EndDeclareModule


Module luaParser
  
  Procedure.s parseLUAstring(regexp, lua$)
    Protected s$, r$, i.i
    ExamineRegularExpression(regexp, lua$)
    If NextRegularExpressionMatch(regexp)
      For i = 1 To CountRegularExpressionGroups(regexp)
        s$ = RegularExpressionGroup(regexp, i)
        If s$
          r$ = s$
        EndIf
      Next
    EndIf
    ProcedureReturn r$
  EndProcedure
  
  Procedure.d parseLUAnumber(regexp, lua$)
    Protected s$, r.d
    ExamineRegularExpression(regexp, lua$)
    If NextRegularExpressionMatch(regexp)
      s$ = RegularExpressionGroup(regexp, CountRegularExpressionGroups(regexp)-1)
      r = ValD(s$)
    EndIf
    
    ProcedureReturn r
  EndProcedure
  
  Procedure parseLUAlocale(file$, locale$, *mod.mods::mod, Map reg_val())
    debugger::Add("parseLUAlocale("+file$+", "+locale$+", "+Str(*mod)+")")
    Protected file.i, lua$
    Protected string$
    
    ; TODO use parser module and global string, regexp, etc...
    string$ = "(.+?)"
    string$ = "(\[\["+string$+"\]\])|('"+string$+"')|("+#DQUOTE$+string$+#DQUOTE$+")"
    string$ = "(_\(("+string$+")\))|("+string$+")"
    
    file = ReadFile(#PB_Any, file$)
    If Not file
      debugger::Add("parseLUAlocale() - ERROR - could not read {"+file$+"}")
      ProcedureReturn #False
    EndIf
    
    lua$ = ReadString(file, #PB_File_IgnoreEOL|#PB_UTF8)
    CloseFile(file)
    
    ; remove comments
    lua$ = ReplaceRegularExpression(reg_val("comments1"), lua$, "")
    lua$ = ReplaceRegularExpression(reg_val("comments2"), lua$, "")
    
    ; try matching string to "function data() return { ... } end" and extract return value
    ExamineRegularExpression(reg_val("data"), lua$)
    If Not NextRegularExpressionMatch(reg_val("data")) ; only expect one match -> read onlyfirst match
      debugger::Add("parseLUAlocale() - ERROR - could not match reg_data")
      ProcedureReturn #False 
    EndIf
    
    lua$ = Trim(RegularExpressionGroup(reg_val("data"), 1)) ; read only group defined in regexp which should contain definition
    If lua$ = ""
      debugger::Add("parseLUAlocale() - ERROR - no data found")
      ProcedureReturn #False
    EndIf
    
    Protected reg_locale
    reg_locale = CreateRegularExpression(#PB_Any, locale$ + "\s*=\s*\{\s*(.*?)\s*\}", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
    
    If Not IsRegularExpression(reg_locale)
      debugger::Add("parseLUAlocale() - ERROR - could not initialize regexp for {"+locale$+"}")
      ProcedureReturn #False
    EndIf
    
    ExamineRegularExpression(reg_locale, lua$)
    If Not NextRegularExpressionMatch(reg_locale) ; only expect one match -> read onlyfirst match
      debugger::Add("parseLUAlocale() - ERROR - cannot find a match for locale {"+locale$+"}")
      ProcedureReturn #False 
    EndIf
    lua$ = Trim(RegularExpressionGroup(reg_locale, 1))
    
    
    Protected regexp
    ; TODO escape characters?
    ; replace string for name
    If *mod\name$
      regexp = CreateRegularExpression(#PB_Any, *mod\name$+"\s*=\s*("+string$+")", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      If IsRegularExpression(regexp)
        If MatchRegularExpression(regexp, lua$)
          *mod\name$ = parseLUAstring(regexp, lua$)
        EndIf
        FreeRegularExpression(regexp)
      EndIf
    EndIf
    ; replace string for description
    If *mod\description$
      regexp = CreateRegularExpression(#PB_Any, *mod\description$+"\s*=\s*("+string$+")", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      If IsRegularExpression(regexp)
        If MatchRegularExpression(regexp, lua$)
          *mod\description$ = parseLUAstring(regexp, lua$)
        EndIf
      EndIf
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure parseInfoLUA(file$, *mod.mods::mod) ; parse info from lua file$ and save to *mod
    debugger::Add("mods::parseInfoLUA("+file$+", "+Str(*mod)+")")
    
    Protected file.i, lua$, i.i
    Static NewMap reg_val()
    Static number$, string$, severity$
;     Static whitespace$, number$, statement$, statements$, variable$, string$, exstring$
    
    If FileSize(file$) <= 0
      debugger::Add("mods::parseInfoLUA() - ERROR: file {"+file$+"} not found or empty")
      ProcedureReturn #False
    EndIf
    
    file = ReadFile(#PB_Any, file$)
    If Not file
      debugger::Add("mods::parseInfoLUA() - ERROR: cannot read file {"+file$+"}!")
      ProcedureReturn #False
    EndIf
    
    lua$ = ReadString(file, #PB_File_IgnoreEOL|#PB_UTF8)
    CloseFile(file)
    
    ; SCANNER
    ; init regular expressions
    If Not reg_val("data")
      debugger::Add("mods::parseInfoLUA() - generate regexp")
      number$ = "([+-]?(\d+\.?\d*|\.\d+))"
      string$ = "(.+?)"
;       string$ = "(\[\["+string$+"\]\])|('"+string$+"')|("+#DQUOTE$+string$+#DQUOTE$+")"
      string$ = "('"+string$+"')|("+#DQUOTE$+string$+#DQUOTE$+")" ; no multiline strings!
      string$ = "(_\(("+string$+")\))|("+string$+")"
      
      ; extract return data
      reg_val("data")             = CreateRegularExpression(#PB_Any, "function\s+Data\s*\(\s*\)\s*Return\s*\{\s*(.*?)\s*\}\s*End", #PB_RegularExpression_NoCase|#PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll|#PB_RegularExpression_MultiLine)
     ; remove all comments: one line comment -- , multi line comment --[[ ... ]] and multiple levels: --[===[ --[[ ]] ]===]
      reg_val("comments1")        = CreateRegularExpression(#PB_Any, "(--\[(=*)\[.*?\]\2\])", #PB_RegularExpression_NoCase|#PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll|#PB_RegularExpression_MultiLine)
      reg_val("comments2")        = CreateRegularExpression(#PB_Any, "(--(.*?)$)", #PB_RegularExpression_NoCase|#PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll|#PB_RegularExpression_MultiLine)
       ; values
      reg_val("minorVersion")     = CreateRegularExpression(#PB_Any, "minorVersion\s*=\s*("+number$+")") ; , #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      reg_val("severityAdd")      = CreateRegularExpression(#PB_Any, "severityAdd\s*=\s*("+string$+")")
      reg_val("severityRemove")   = CreateRegularExpression(#PB_Any, "severityRemove\s*=\s*("+string$+")")
      reg_val("name")             = CreateRegularExpression(#PB_Any, "name\s*=\s*("+string$+")")
      reg_val("role")             = CreateRegularExpression(#PB_Any, "role\s*=\s*("+string$+")")
      reg_val("text")             = CreateRegularExpression(#PB_Any, "text\s*=\s*("+string$+")")
      reg_val("steamProfile")     = CreateRegularExpression(#PB_Any, "steamProfile\s*=\s*("+string$+")")
      reg_val("description")      = CreateRegularExpression(#PB_Any, "description\s*=\s*("+string$+")")
      reg_val("authors")          = CreateRegularExpression(#PB_Any, "authors\s*=\s*\{(\s*(\{.*?\}\s*,*\s*)*?\s*)\}", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      reg_val("authors2")         = CreateRegularExpression(#PB_Any, "authors\s*=\s*\{\s*(.*?)\s*\}", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      reg_val("author")           = CreateRegularExpression(#PB_Any, "\{.*?\}", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      reg_val("tags")             = CreateRegularExpression(#PB_Any, "tags\s*=\s*\{(.*?)\}", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      reg_val("string")           = CreateRegularExpression(#PB_Any, string$)
      reg_val("tfnetId")          = CreateRegularExpression(#PB_Any, "tfnetId\s*=\s*("+number$+")")
      reg_val("minGameVersion")   = CreateRegularExpression(#PB_Any, "minGameVersion\s*=\s*("+number$+")")
      reg_val("dependencies")     = CreateRegularExpression(#PB_Any, "dependencies\s*=\s*(\{(.*?)\})", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      reg_val("url")              = CreateRegularExpression(#PB_Any, "url\s*=\s*("+string$+")")
      
      ForEach reg_val()
        If Not IsRegularExpression(reg_val())
          debugger::Add("mods::parseInfoLUA() - ERROR - regexp {"+MapKey(reg_val())+"} not initialized")
          ProcedureReturn #False
        EndIf
      Next
    EndIf
    
    ; remove comments
    lua$ = ReplaceRegularExpression(reg_val("comments1"), lua$, "")
    lua$ = ReplaceRegularExpression(reg_val("comments2"), lua$, "")
    
    ; try matching string to "function data() return { ... } end" and extract return value
    ExamineRegularExpression(reg_val("data"), lua$)
    If Not NextRegularExpressionMatch(reg_val()) ; only expect one match -> read onlyfirst match
      debugger::Add("mods::parseInfoLUA() - ERROR: no match found (reg_data)")
      ProcedureReturn #False 
    EndIf
    
    lua$ = Trim(RegularExpressionGroup(reg_val(), 1)) ; read only group defined in regexp which should contain definition
    If lua$ = ""
      debugger::Add("mods::parseInfoLUA() - ERROR: empty data (reg_data -> group 1)")
      ProcedureReturn #False 
    EndIf
    
    ; bad and unsexy :(
    ; first: all tables (author, tags, dependencies
    Protected authors$, author$, s$, s.d, tmp.i, tmp$
    
    ; extract authors
    ExamineRegularExpression(reg_val("authors"), lua$)
    If NextRegularExpressionMatch(reg_val())
      authors$ = RegularExpressionGroup(reg_val(), 1)
    Else
      ExamineRegularExpression(reg_val("authors2"), lua$)
      If NextRegularExpressionMatch(reg_val())
        authors$ = RegularExpressionGroup(reg_val(), 1)
      EndIf
    EndIf
    ;remove authors from parsing string (in order to not interfere with other "name" and "tfnetId"
    lua$ = ReplaceRegularExpression(reg_val(), lua$, "")
    
    ; authors
    ExamineRegularExpression(reg_val("author"), authors$)
    tmp = #False
    While NextRegularExpressionMatch(reg_val("author"))
      author$ = RegularExpressionMatchString(reg_val("author"))
      If author$
        If Not tmp  ; if a new author is found -> one time clean possible old list
          ClearList(*mod\authors())
          tmp = #True
        EndIf
        AddElement(*mod\authors())
        ; name:
        s$ = parseLUAstring(reg_val("name"), author$)
        If s$
          *mod\authors()\name$ = s$
        EndIf
        s$ = parseLUAstring(reg_val("role"), author$)
        If s$
          *mod\authors()\role$ = s$
        EndIf
        s$ = parseLUAstring(reg_val("text"), author$)
        If s$
          *mod\authors()\text$ = s$
        EndIf
        s$ = parseLUAstring(reg_val("steamProfile"), author$)
        If s$
          *mod\authors()\steamProfile$ = s$
        EndIf
        s = parseLUAnumber(reg_val("tfnetId"), author$)
        If s
          *mod\authors()\tfnetId = s
        EndIf
      EndIf
    Wend
    
    ; name
    s$ = parseLUAstring(reg_val("name"), lua$)
    If s$
      *mod\name$ = s$
    EndIf
    s$ = parseLUAstring(reg_val("severityAdd"), lua$)
    If s$
      *mod\severityAdd$ = s$
    EndIf
    s$ = parseLUAstring(reg_val("severityRemove"), lua$)
    If s$
      *mod\severityRemove$ = s$
    EndIf
    s$ = parseLUAstring(reg_val("description"), lua$)
    If s$
      *mod\description$ = s$
    EndIf
    s$ = parseLUAstring(reg_val("url"), lua$)
    If s$
      *mod\url$ = s$
    EndIf
    
    s = parseLUAnumber(reg_val("minorVersion"), lua$)
    If s
      *mod\minorVersion = s
    EndIf
    s = parseLUAnumber(reg_val("tfnetId"), lua$)
    If s
      *mod\tfnetId = s
    EndIf
    s = parseLUAnumber(reg_val("minGameVersion"), lua$)
    If s
      *mod\minGameVersion = s
    EndIf
    
    ; tags = {"vehicle", "bus", },
    ExamineRegularExpression(reg_val("tags"), lua$)
    If NextRegularExpressionMatch(reg_val())
      tmp$ = RegularExpressionGroup(reg_val(), 1)
      If tmp$
        ExamineRegularExpression(reg_val("string"), tmp$)
        tmp = #False
        While NextRegularExpressionMatch(reg_val())
          If Not tmp  ; if a new tag is found -> one time clean possible old list from tfmm.ini
            ClearList(*mod\tags$())
            tmp = #True
          EndIf
          AddElement(*mod\tags$())
          For i = 1 To CountRegularExpressionGroups(reg_val())
            s$ = RegularExpressionGroup(reg_val(), i)
            If s$:
              *mod\tags$() = s$
            EndIf
          Next
        Wend
      EndIf
    EndIf
    
    ; dependencies = {"mod_1", "mod_2", },
    ExamineRegularExpression(reg_val("dependencies"), lua$)
    If NextRegularExpressionMatch(reg_val())
      tmp$ = RegularExpressionGroup(reg_val(), 1)
      If tmp$
        ExamineRegularExpression(reg_val("string"), tmp$)
        tmp = #False
        While NextRegularExpressionMatch(reg_val())
          If Not tmp  ; if a new tag is found -> one time clean possible old list from tfmm.ini
            ClearList(*mod\dependencies$())
            tmp = #True
          EndIf
          AddElement(*mod\dependencies$())
          For i = 1 To CountRegularExpressionGroups(reg_val())
            s$ = RegularExpressionGroup(reg_val(), i)
            If s$:
              *mod\dependencies$() = s$
            EndIf
          Next
        Wend
      EndIf
    EndIf
    
    ; last step: open strings.lua if present and replace strings
    If FileSize(GetPathPart(file$)+"strings.lua") > 0
      If Not parseLUAlocale(GetPathPart(file$)+"strings.lua", locale::getCurrentLocale(), *mod, reg_val())
        If locale::getCurrentLocale() <> "en"
          parseLUAlocale(GetPathPart(file$)+"strings.lua", "en", *mod, reg_val())
        EndIf
      EndIf
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  
EndModule
