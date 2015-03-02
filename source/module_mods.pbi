XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_unrar.pbi"
; XIncludeFile "module_parseLUA.pbi"
XIncludeFile "module_locale.pbi"

DeclareModule mods
  EnableExplicit
  XIncludeFile "module_locale.pbi"
  
  Structure aux
    version$
    author$
    tfnet_author_id$
    tags$
    
    file$
    md5$
    installed.i
    lua$
  EndStructure
  
  Structure author
    name$
    role$
    text$
    steamProfile$
    tfnetId.i
  EndStructure
  
  Structure mod
    id$
    minorVersion.i
    majorVersion.i
    severityAdd$
    severityRemove$
    name$
    description$
    List authors.author()
    List tags$()
    tfnetId.i
    minGameVersion.i
    List dependencies$()
    url$
    
    aux.aux
  EndStructure
  
  Declare init() ; allocate structure, return *mod
  Declare free(id$) ; free *mod structure
  
  Declare new(file$, TF$) ; read mod pack from any location, extract info
  Declare delete(id$)     ; delete mod from library
  
  Declare loadModList(TF$)
  
  Declare generateID(*mod.mod, id$ = "")
  Declare generateLUA(*mod.mod)
  
  Declare InstallThread(*dummy) ; add mod to TF
  Declare RemoveThread(*dummy)  ; remove mod from TF
  
  
EndDeclareModule

Module mods
  Global NewMap *mods.mod()
  
  ;PRIVATE
  
  Procedure.s checkModFileZip(File$) ; check for res/ , return ID If found
    debugger::Add("mods::CheckModFileZip("+File$+")")
    Protected entry$
    If OpenPack(0, File$)
      If ExaminePack(0)
        While NextPackEntry(0)
          entry$ = PackEntryName(0)
          If FindString(entry$, "res/")
            ; found a "res" subfolder, assume this mod is valid 
            ClosePack(0)
            entry$ = GetFilePart(Left(entry$, FindString(entry$, "res/")-2))
            ProcedureReturn entry$
          EndIf
        Wend
      EndIf
      ClosePack(0)
    EndIf
    ProcedureReturn "false"
  EndProcedure
  
  Procedure.s checkModFileRar(File$) ; check for res/ , return ID if found
    debugger::Add("mods::CheckModFileRar("+File$+")")
    Protected rarheader.unrar::RARHeaderDataEx
    Protected hRAR
    Protected Entry$
    
    hRAR = unrar::OpenRar(File$, unrar::#RAR_OM_LIST) ; only list rar files (do not extract)
    If hRAR
      While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS ; read header of file in rar
        CompilerIf #PB_Compiler_Unicode
          Entry$ = PeekS(@rarheader\FileNameW)
        CompilerElse
          Entry$ = PeekS(@rarheader\FileName,#PB_Ascii)
        CompilerEndIf
        If FindString(Entry$, "res\")
          unrar::RARCloseArchive(hRAR)
          ; found a "res" subfolder, assume this mod is valid
          entry$ = GetFilePart(Left(entry$, FindString(entry$, "res\")-2))
          ProcedureReturn entry$ ; entry$ = id, can be empty!
        EndIf
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; skip to next entry in rar
      Wend
      unrar::RARCloseArchive(hRAR)
    EndIf
    ProcedureReturn "false"
  EndProcedure
  
  Procedure.s checkModFile(File$) ; Check mod for a "res" folder! -> Return ID if found
    debugger::Add("mods::CheckModFile("+File$+")")
    Protected extension$, ret$
    
    extension$ = LCase(GetExtensionPart(File$))
    
    ret$ = checkModFileZip(File$)
    If ret$ <> "false" ; either contains ID or is empty if res folder is found
      ProcedureReturn ret$
    EndIf
    
    ret$ = checkModFileRar(File$)
    If ret$ <> "false" ; either contains ID or is empty if res folder is found
      ProcedureReturn ret$
    EndIf
    
    ProcedureReturn "false"
  EndProcedure
  
  Procedure cleanModInfo(*mod.mod)
    debugger::Add("mods::cleanModInfo("+Str(*mod)+")")
    With *mod
      \id$ = ""
      \aux\version$ = ""
      \majorVersion = 0
      \minorVersion = 0
      \name$ = ""
      \description$ = ""
      \aux\author$ = ""
      ClearList(\authors())
      \aux\tags$ = ""
      ClearList(\tags$())
      \tfnetId = 0
      \minGameVersion = 0
      ClearList(\dependencies$())
      \url$ = ""
    
      \aux\file$ = ""
      \aux\installed = 0
      \aux\lua$ = ""
    EndWith
  EndProcedure
  
  Procedure ExtractFilesZip(zip$, List files$(), dir$) ; extracts all Files$() (from all subdirs!) to given directory
    debugger::Add("mods::ExtractFilesZip("+zip$+", Files$(), "+dir$+")")
    Protected deb$ = "mods::ExtractFilesZip() - search for: "
    ForEach Files$() : deb$ + files$()+", " : Next
    debugger::Add(deb$)
    
    Protected zip, Entry$
    dir$ = misc::Path(dir$)
    
    zip = OpenPack(#PB_Any, zip$, #PB_PackerPlugin_Zip)
    If Not zip
      debugger::Add("ExtractFilesZip() - Error opnening zip: "+ZIP$)
      ProcedureReturn #False
    EndIf
    
    If ExaminePack(zip)
      While NextPackEntry(zip)
        Entry$ = PackEntryName(zip)
        
        If FindString(Entry$, "__MACOSX") Or FindString(Entry$, ".DS_Store") Or Left(GetFilePart(Entry$), 2) = "._"
          Continue
        EndIf
        
        ForEach Files$()
          If LCase(Entry$) = LCase(Files$()) Or LCase(Right(Entry$, Len(Files$())+1)) = "/" + LCase(Files$())
            UncompressPackFile(zip, dir$ + Files$())
            DeleteElement(Files$()) ; if file is extracted, delete from list
            Break ; ForEach
          EndIf
        Next
      Wend
    EndIf
    ClosePack(zip)
    ProcedureReturn #True
  EndProcedure

  Procedure ExtractFilesRar(RAR$, List Files$(), dir$) ; extracts all Files$() (from all subdirs!) to given directory
    debugger::Add("ExtractFilesRar("+RAR$+", Files$(), "+dir$+")")
    Protected deb$ = "mods::ExtractFilesZip() - search for: "
    ForEach Files$() : deb$ + files$()+", " : Next
    debugger::Add(deb$)
    
    Protected rarheader.unrar::RARHeaderDataEx
    Protected hRAR, hit
    Protected Entry$
    dir$ = misc::Path(dir$)
    
    hRAR = unrar::OpenRar(RAR$, unrar::#RAR_OM_EXTRACT)
    If Not hRAR
      debugger::Add("ExtractFilesRar() - Error opnening rar: "+RAR$)
      ProcedureReturn #False
    EndIf
    
    While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS
      CompilerIf #PB_Compiler_Unicode
        Entry$ = PeekS(@rarheader\FileNameW)
      CompilerElse
        Entry$ = PeekS(@rarheader\FileName, #PB_Ascii)
      CompilerEndIf
      
      ; filter out Mac OS X bullshit
      If FindString(Entry$, "__MACOSX") Or FindString(Entry$, ".DS_Store") Or Left(GetFilePart(Entry$), 2) = "._"
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; skip these files / entries
        Continue
      EndIf
      
      hit = #False
      ForEach Files$()
        If LCase(Entry$) = LCase(Files$()) Or LCase(Right(Entry$, Len(Files$())+1)) = "\" + LCase(Files$())
          unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #NULL$, dir$ + Files$())
          DeleteElement(Files$()) ; if file is extracted, delete from list
          hit = #True
          Break ; ForEach
        EndIf
      Next
      If Not hit
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$)
      EndIf
      
    Wend
    unrar::RARCloseArchive(hRAR)
    ProcedureReturn #True
  EndProcedure
  
  Procedure parseTFMMini(file$, *mod.mod)
    debugger::Add("mods::parseTFMMini("+file$+", "+Str(*mod)+")")
    
    If FileSize(file$) <= 0
      debugger::Add("mods::parseTFMMini() - ERROR - file {"+file$+"} not found or empty")
      ProcedureReturn #False
    EndIf
    
    OpenPreferences(file$)
    With *mod
      
      \id$ = ReadPreferenceString("id", "")
      \aux\version$ = ReadPreferenceString("version","0")
      \name$ = ReadPreferenceString("name", \name$)
      \aux\author$ = ReadPreferenceString("author", "")
      \aux\tags$ = ReadPreferenceString("category", "")
      
      ClearList(\dependencies$())
      
      PreferenceGroup("online")
      \tfnetId = ReadPreferenceInteger("tfnet_mod_id", 0)
      \aux\tfnet_author_id$ = ReadPreferenceString("tfnet_author_id","")
      \url$ = ReadPreferenceString("url","")
      PreferenceGroup("")
    
      \aux\file$ = ""
      \aux\installed = 0
      \aux\lua$ = ""
      
      ; read dependencies from tfmm.ini
      PreferenceGroup("dependencies")
      If ExaminePreferenceKeys()
        While NextPreferenceKey()
          AddElement(\dependencies$())
          \dependencies$() = PreferenceKeyName()
        Wend
      EndIf 
    EndWith
    ClosePreferences()
    
    ProcedureReturn #True
  EndProcedure
  
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
  
  Procedure parseLUAlocale(file$, locale$, *mod.mod, Map reg_val())
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
        *mod\name$ = parseLUAstring(regexp, lua$)
        FreeRegularExpression(regexp)
      EndIf
    EndIf
    ; replace string for description
    If *mod\description$
      regexp = CreateRegularExpression(#PB_Any, *mod\description$+"\s*=\s*("+string$+")", #PB_RegularExpression_AnyNewLine|#PB_RegularExpression_DotAll)
      If IsRegularExpression(regexp)
        *mod\description$ = parseLUAstring(regexp, lua$)
        FreeRegularExpression(regexp)
      EndIf
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure parseInfoLUA(file$, *mod.mods::mod) ; parse info from lua file$ and save to *mod
    debugger::Add("mods::parseInfoLUA("+file$+", "+Str(*mod.mod)+")")
    
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
    
    ; brute force parsing (bad and unsexy) :(
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
      parseLUAlocale(GetPathPart(file$)+"strings.lua", "en", *mod, reg_val())
      parseLUAlocale(GetPathPart(file$)+"strings.lua", locale::getCurrentLocale(), *mod, reg_val())
    EndIf
    
    Protected deb$
    ForEach *mod\authors()
      debugger::Add("mods::parseInfoLUA() - author: "+*mod\authors()\name$+", "+*mod\authors()\role$+", "+*mod\authors()\text$+", "+*mod\authors()\steamProfile$+", "+Str(*mod\authors()\tfnetId))
    Next
    debugger::Add("mods::parseInfoLUA() - name: "+*mod\name$)
    debugger::Add("mods::parseInfoLUA() - severityAdd: "+*mod\severityAdd$)
    debugger::Add("mods::parseInfoLUA() - severityRemove: "+*mod\severityRemove$)
    debugger::Add("mods::parseInfoLUA() - description: "+*mod\description$)
    debugger::Add("mods::parseInfoLUA() - tfnetId: "+Str(*mod\tfnetId))
    debugger::Add("mods::parseInfoLUA() - minGameVersion: "+Str(*mod\minGameVersion))
    debugger::Add("mods::parseInfoLUA() - url: "+*mod\url$)
    deb$ = "mods::parseInfoLUA() - tags: "
    ForEach *mod\tags$()
      deb$ + *mod\tags$()+", "
    Next
    debugger::Add(deb$)
    deb$ = "mods::parseInfoLUA() - dependencies: "
    ForEach *mod\dependencies$()
      deb$ + *mod\dependencies$()+", "
    Next
    debugger::Add(deb$)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure loadInfo(file$, *mod.mod, id$) ; extract info from mod file$ (tfmm.ini, info.lua, ...)
    debugger::Add("mods::loadInfo("+file$+", "+Str(*mod)+", "+id$+")")
    
    Protected tmpDir$ = GetTemporaryDirectory()
    
    ; clean info
    cleanModInfo(*mod)
    
    ; read standard information
    With *mod
      \aux\file$ = GetFilePart(file$)
      \aux\md5$ = MD5FileFingerprint(file$)
      \name$ = GetFilePart(File$, #PB_FileSystem_NoExtension)
    EndWith
    
    ; extract some files
    DeleteFile(tmpDir$ + "tfmm.ini", #PB_FileSystem_Force)
    DeleteFile(tmpDir$ + "info.lua", #PB_FileSystem_Force)
    DeleteFile(tmpDir$ + "strings.lua", #PB_FileSystem_Force)
    Protected NewList files$()
    AddElement(files$()) : files$() = "tfmm.ini"
    AddElement(files$()) : files$() = "info.lua"
    AddElement(files$()) : files$() = "strings.lua"
    If Not ExtractFilesZip(file$, files$(), tmpDir$)
      If Not ExtractFilesRar(file$, files$(), tmpDir$)
        debugger::Add("mods::GetModInfo() - failed to open {"+file$+"} for extraction")
      EndIf
    EndIf
    
    Protected author$, tfnet_author_id$, tags$
    Protected count.i, i.i
    
    ; read tfmm.ini
    parseTFMMini(tmpDir$ + "tfmm.ini", *mod)
    DeleteFile(tmpDir$ + "tfmm.ini")
    
    ; read info.lua
    parseInfoLUA(tmpDir$ + "info.lua", *mod)
    DeleteFile(tmpDir$ + "info.lua")
    
    ; post processing
    With *mod
      \name$ = ReplaceString(ReplaceString(\name$, "[", "("), "]", ")")
      \majorVersion = Val(StringField(\aux\version$, 1, "."))
      \minorVersion = Val(StringField(\aux\version$, 2, "."))
      If author$
        author$ = ReplaceString(author$, "/", ",")
        count  = CountString(author$, ",") + 1
        For i = 1 To count
          AddElement(\authors())
          \authors()\name$ = Trim(StringField(author$, i, ","))
          If i = 1 : \authors()\role$ = "CREATOR"
          Else : \authors()\role$ = "CO_CREATOR"
          EndIf
          \authors()\tfnetId = Val(Trim(StringField(tfnet_author_id$, i, ",")))
        Next i
      EndIf
      If tags$
        tags$ = ReplaceString(tags$, "/", ",")
        count = CountString(tags$, ",") + 1
        For i = 1 To count
          AddElement(\tags$())
          \tags$() = Trim(StringField(tags$, i, "/"))
        Next i
      EndIf
    EndWith
    
    If Not generateID(*mod, id$)
      ProcedureReturn #False
    EndIf
    generateLUA(*mod)
    
    ProcedureReturn #True
  EndProcedure
  
  
  ;PUBLIC
  
  
  Procedure init()
    Protected *mod.mod
    *mod = AllocateStructure(mod)
    debugger::Add("mods::initMod() - new mod: {"+Str(*mod)+"}")
    ProcedureReturn *mod
  EndProcedure
  
  Procedure free(id$)
    debugger::Add("mods::freeMod("+id$+")")
    Protected *mod.mod
    If FindMapElement(*mods(), id$)
      FreeStructure(*mods())
      DeleteMapElement(*mods())
      ProcedureReturn #True
    EndIf
    
    debugger::Add("mods::freeMod() - ERROR: could not find mod {"+id$+"} in List")
    ProcedureReturn #False
  EndProcedure
  
  Procedure new(file$, TF$) ; add new mod from any location to list of mods and initiate install
    debugger::Add("mods::addMod("+file$+", "+TF$+")")
    Protected *mod.mod, id$
    
    ; first step: check mod
    id$ = CheckModFile(file$)
    If id$ = "false"
      debugger::Add("mods::addMod() - ERROR: check failed, abort")
      ProcedureReturn #False
    EndIf
    
    *mod = init()
    
    ; second step: read information
    If Not loadInfo(file$, *mod, id$)
      debugger::Add("mods::addMod() - ERROR: failed to retrieve info")
      FreeStructure(*mod)
      ProcedureReturn #False
    EndIf
    
    
    ; third step: check if mod with same ID already installed
    Protected sameHash.b = #False, sameID.b = #False
    ForEach *mods()
      If *mods()\aux\md5$ = *mod\aux\md5$
        debugger::Add("mods::addMod() - MD5 check found match!")
        id$ = *mods()\id$
        sameHash = #True
        Break
      EndIf
    Next
    
    If FindMapElement(*mods(),  *mod\id$)
      debugger::Add("mods::addMod() - Another mod with id {"+id$+"} already in list!")
      id$ =  *mod\id$
      sameID = #True
    EndIf
    
    If sameHash
      Protected NewMap strings$()
      ClearMap(strings$())
      strings$("name") = *mods(id$)\name$
      If *mods()\aux\installed
        MessageRequester(locale::l("main","add"), locale::getEx("management","hash_inst",strings$()), #PB_MessageRequester_Ok)
        FreeStructure(*mod)
        debugger::Add("mods::addMod() - cancel new installed, mod already installed")
        ProcedureReturn #True
      Else
        debugger::Add("mods::addMod() - trigger install of previous mod")
        
      EndIf
      
    EndIf
    
    
;     If sameHash ; same hash indicates a duplicate - do not care about name or ID!
;       debugger::Add("same hash indicates a duplicate - do not care about name or ID! - abort installation")
;       If *tmp\active
;         
;       Else
;         If MessageRequester("Error installing '"+*modinfo\name$+"'", "The modification '"+*tmp\name$+"' is already installed."+#CRLF$+"Do you want To activate it now?", #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
;           AddToQueue(#QueueActionActivate, *tmp)
;         EndIf
;       EndIf
;       FreeStructure(*modinfo)
;       ProcedureReturn #True
;     EndIf
;     
;     If (sameName Or sameID) And Not sameHash ; a mod with the same name is installed, but it is not identical (maybe a new version?)
;       tmp$ = "Match with already installed modification found:"+#CRLF$+
;              "Current modification:"+#CRLF$+
;              #TAB$+"ID: "+*tmp\id$+#CRLF$+
;              #TAB$+"Name: "+*tmp\name$+#CRLF$+
;              #TAB$+"Version: "+*tmp\version$+#CRLF$+
;              #TAB$+"Author: "+*tmp\authors$+#CRLF$+
;              #TAB$+"Size: "+misc::Bytes(*tmp\size)+#CRLF$+
;              "New modification:"+#CRLF$+
;              #TAB$+"ID: "+*modinfo\id$+#CRLF$+
;              #TAB$+"Name: "+*modinfo\name$+#CRLF$+
;              #TAB$+"Version: "+*modinfo\version$+#CRLF$+
;              #TAB$+"Author: "+*modinfo\authors$+#CRLF$+
;              #TAB$+"Size: "+misc::Bytes(*modinfo\size)+#CRLF$+
;              "Do you want to replace the old modification with the new one?"
;       If MessageRequester("Error", tmp$, #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
;         ; user does not want to replace
;         debugger::Add("User does not want to replace old mod with new mod. Free new mod: "+Str(*modinfo))
;         FreeStructure(*modinfo)
;         ProcedureReturn #False
;       EndIf
;       ; user wants to replace mod -> deactivate and uninstall old mod
;       
;       If *tmp\active
;         AddToQueue(#QueueActionDeactivate, *tmp)
;       EndIf
;       AddToQueue(#QueueActionUninstall, *tmp)
;       
;       ; after old mod is uninstalled: shedule installation of new mod again!
;       ; TODO make a more efficient way of this process!
;       AddToQueue(#QueueActionNew, 0, File$)
;       FreeStructure(*modinfo)
;       ProcedureReturn #False
;       
;     EndIf
    
    ; fourth step: move mod to internal TFMM mod folder
    ; fifth step: copy files to mods/ folder of Train Fever (init install)
    
  EndProcedure
  
  Procedure loadModList(TF$) ; load all mods in internal modding folder and installed to TF
    
  EndProcedure
  
  Procedure InstallThread(*dummy)
    
  EndProcedure
  
  Procedure RemoveThread(*dummy)
    
  EndProcedure
  
  Procedure delete(id$) ; delete mod from library
    
  EndProcedure
  
  Procedure generateID(*mod.mod, id$ = "")
    debugger::Add("mods::generateID("+Str(*mod)+", "+id$+")")
    Protected author$, name$, version$
    
    If Not *mod
      ProcedureReturn
    EndIf
    
    Static RegExp, RegExp2
    If Not RegExp Or Not RegExp2
      RegExp  = CreateRegularExpression(#PB_Any, "^[a-z0-9]*$") ; non-alphanumeric characters
      RegExp2  = CreateRegularExpression(#PB_Any, "^([a-z0-9]+_){2,}[0-9]+$") ; non-alphanumeric characters
      ; regexp matches all non alphanum characters including spaces etc.
    EndIf
    
    With *mod
      If id$
        debugger::Add("mods::generateID() - passed through id = {"+id$+"}")
        ; this id$ is passed through, extracted from subfolder name
        ; if it is present, check if it is well-defined
        If MatchRegularExpression(RegExp2, id$)
          debugger::Add("mods::generateID() - {"+id$+"} is a valid ID")
          \id$ = id$
          ProcedureReturn #True
        Else
          debugger::Add("mods::generateID() - {"+id$+"} is no valid ID - generate new ID")
        EndIf
      Else
        debugger::Add("mods::generateID() - no ID defined - generate new ID")
      EndIf
      
      
      ; if no id$ was passed through or id was invalid, generate new ID
      
      
      \id$ = LCase(\id$)
      
      ; Check if ID already correct
      If \id$ And MatchRegularExpression(RegExp2, \id$)
        debugger::Add("mods::generateID() - ID {"+\id$+"} is well defined (first)")
        ProcedureReturn #True
      EndIf
      
      ; Check if ID in old format
      author$   = StringField(\id$, 1, ".")
      name$     = StringField(\id$, CountString(\id$, ".")+1, ".")
      version$  = Str(Abs(Val(StringField(\aux\version$, 1, "."))))
      \id$ = author$ + "_" + name$ + "_" + version$
      
      If \id$ And MatchRegularExpression(RegExp2, \id$)
        debugger::Add("mods::generateID() - ID {"+\id$+"} is well defined")
        ProcedureReturn #True
      EndIf
      
      \id$ = ""
      
      debugger::Add("mods::generateID() - generate new ID")
      ; ID = author_mod_version
      LastElement(\authors())
      author$ = ReplaceRegularExpression(RegExp, LCase(\authors()\name$), "") ; remove all non alphanum + make lowercase
      If author$ = ""
        author$ = "unknownauthor"
      EndIf
      name$ = ReplaceRegularExpression(RegExp, LCase(\name$), "") ; remove all non alphanum + make lowercase
      If name$ = ""
        name$ = "unknown"
      EndIf
      version$ = Str(Val(StringField(\aux\version$, 1, "."))) ; first part of version string concatenated by "." as numeric value
      
      \id$ = author$ + "_" + name$ + "_" + version$ ; concatenate id parts
      
      
      If \id$ And MatchRegularExpression(RegExp2, \id$)
        debugger::Add("mods::generateID() - ID {"+\id$+"} is well defined")
        ProcedureReturn #True
      EndIf
    EndWith
    
    debugger::Add("mods::generateID() - ERROR: No ID generated")
    ProcedureReturn #False
  EndProcedure
  
  Procedure generateLUA(*mod.mod)
    Protected lua$
    
    ; severity = "NONE", "WARNING", "CRITICAL"
    ; author role = "CREATOR", "CO_CREATOR", "TESTER", "BASED_ON", "OTHER"
    With *mod
      lua$ = "function data()" + #CRLF$ +
             "return {" + #CRLF$
      lua$ + "  minorVersion = "+Str(\minorVersion)+"," + #CRLF$
      lua$ + "  severityAdd = "+#DQUOTE$+misc::luaEscape(\severityAdd$)+#DQUOTE$+"," + #CRLF$
      lua$ + "  severityRemove = "+#DQUOTE$+misc::luaEscape(\severityRemove$)+#DQUOTE$+"," + #CRLF$
      lua$ + "  name = _("+#DQUOTE$+misc::luaEscape(\name$)+#DQUOTE$+")," + #CRLF$
      lua$ + "  description = _("+#DQUOTE$+" "+#DQUOTE$+")," + #CRLF$
      lua$ + "  authors = {" + #CRLF$
      ForEach \authors()
        lua$ +  "    {" + #CRLF$ +
                "      name = "+#DQUOTE$+""+misc::luaEscape(\authors()\name$)+""+#DQUOTE$+"," + #CRLF$ +
                "      role = "+#DQUOTE$+""+misc::luaEscape(\authors()\role$)+""+#DQUOTE$+"," + #CRLF$ +
                "      text = "+#DQUOTE$+""+#DQUOTE$+"," + #CRLF$ +
                "      steamProfile = "+#DQUOTE$+""+#DQUOTE$+"," + #CRLF$ +
                "      tfnetId = "+Str(\authors()\tfnetId)+"," + #CRLF$ +
                "    }," + #CRLF$
      Next
      lua$ + "  }," + #CRLF$
      lua$ + "  tags = {"
      ForEach \tags$()
        lua$ + #DQUOTE$+misc::luaEscape(\tags$())+#DQUOTE$+", "
      Next
      lua$ + "}," + #CRLF$
      lua$ + "  tfnetId = "+Str(\tfnetId)+"," + #CRLF$
      lua$ + "  minGameVersion = "+Str(\minGameVersion)+"," + #CRLF$
      lua$ + "  dependencies = {"
      ForEach \dependencies$()
        lua$ + #DQUOTE$+\dependencies$()+#DQUOTE$+", "
      Next
      lua$ + "}," + #CRLF$
      lua$ + "  url = "+#DQUOTE$+misc::luaEscape(\url$)+#DQUOTE$+"," + #CRLF$
      lua$ + "}" + #CRLF$ +
           "end"
    EndWith
    
    *mod\aux\lua$ = lua$
    ProcedureReturn #True
  EndProcedure
  
  
EndModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 312
; FirstLine = 73
; Folding = TIAA+
; EnableUnicode
; EnableXP