XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_unrar.pbi"
; XIncludeFile "module_parseLUA.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_queue.pbi"

XIncludeFile "module_mods_h.pbi"

Module mods
  Global NewMap *mods.mod()
  Global changed.i ; report variable if mod states have changed
  Global library.i ; library gadget
  
  ;PRIVATE
  
  Procedure checkID(id$)
    debugger::Add("mods::checkID("+id$+")")
    Static regexp
    If Not IsRegularExpression(regexp)
      regexp = CreateRegularExpression(#PB_Any, "^([a-z0-9]+_){2,}[0-9]+$")
    EndIf
    
    ProcedureReturn MatchRegularExpression(regexp, id$)
  EndProcedure
  
  Procedure.s checkModFileZip(File$) ; check for res/ , return ID If found
    debugger::Add("mods::CheckModFileZip("+File$+")")
    Protected entry$, pack
    
    If FileSize(File$) <= 0
      debugger::Add("mods::checkModFileZip() - ERROR - {"+File$+"} not found")
      ProcedureReturn "false"
    EndIf
    
    pack = OpenPack(#PB_Any, File$, #PB_PackerPlugin_Zip)
    If pack
      If ExaminePack(pack)
        While NextPackEntry(pack)
          entry$ = PackEntryName(pack)
          entry$ = misc::Path(GetPathPart(entry$), "/")+GetFilePart(entry$)
          debugger::Add("mods::checkModFileZip() - {"+entry$+"}")
          If FindString(entry$, "res/") ; found a "res" subfolder, assume this mod is valid 
            ClosePack(pack)
            entry$ = GetFilePart(Left(entry$, FindString(entry$, "res/")-2)) ; entry = folder name (id)
            debugger::Add("mods::checkModFileZip() - found res/ - return {"+entry$+"}")
            ProcedureReturn entry$
          EndIf
          If GetFilePart(entry$) =  "info.lua" ; found info.lua, asume mod is valid
            ClosePack(pack)
            entry$ = GetFilePart(Left(entry$, FindString(entry$, "info.lua")-2)) ; entry = folder name (id)
            debugger::Add("mods::checkModFileZip() - found info.lua - return {"+entry$+"}")
            ProcedureReturn entry$
          EndIf
        Wend
      EndIf
      ClosePack(pack)
    Else
      debugger::Add("mods::checkModFileZip() - ERROR - cannot open pack {"+File$+"}")
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
        
        debugger::Add("mods::checkModFileRar() - {"+entry$+"}")
        If FindString(Entry$, "res\")
          unrar::RARCloseArchive(hRAR) ; found a "res" subfolder, assume this mod is valid
          entry$ = GetFilePart(Left(entry$, FindString(entry$, "res\")-2)) ; entry$ = parent folder = id
          debugger::Add("mods::checkModFileRar() - found res\ - return {"+entry$+"}")
          ProcedureReturn entry$ ; entry$ = id, can be empty!
        EndIf
        If GetFilePart(Entry$) =  "info.lua"
          unrar::RARCloseArchive(hRAR) ; found info.lua subfolder, assume this mod is valid
          entry$ = GetFilePart(Left(entry$, FindString(entry$, "info.lua")-2)) ; entry$ = parent folder = id
          debugger::Add("mods::checkModFileRar() - found info.lua - return {"+entry$+"}")
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
      \aux\authors$ = ""
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
        entry$ = PackEntryName(zip)
        If FindString(Entry$, "__MACOSX") Or FindString(Entry$, ".DS_Store") Or Left(GetFilePart(Entry$), 2) = "._"
          Continue
        EndIf
        
        entry$ = GetFilePart(entry$)
        ForEach Files$()
          If LCase(Entry$) = LCase(Files$())
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
        entry$ = GetFilePart(entry$)
        If LCase(entry$) = LCase(Files$())
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
      \aux\authors$ = ReadPreferenceString("author", "")
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
    
    ; Post Processing
    Protected count.i, i.i
    With *mod
      \name$ = ReplaceString(ReplaceString(\name$, "[", "("), "]", ")")
      \majorVersion = Val(StringField(\aux\version$, 1, "."))
      \minorVersion = Val(StringField(\aux\version$, 2, "."))
      If \aux\authors$
        \aux\authors$ = ReplaceString(\aux\authors$, "/", ",")
        count  = CountString(\aux\authors$, ",") + 1
        For i = 1 To count
          AddElement(\authors())
          \authors()\name$ = Trim(StringField(\aux\authors$, i, ","))
          If i = 1 : \authors()\role$ = "CREATOR"
          Else : \authors()\role$ = "CO_CREATOR"
          EndIf
          \authors()\tfnetId = Val(Trim(StringField(\aux\tfnet_author_id$, i, ",")))
        Next i
      EndIf
      If \aux\tags$
        \aux\tags$ = ReplaceString(\aux\tags$, "/", ",")
        count = CountString(\aux\tags$, ",") + 1
        For i = 1 To count
          AddElement(\tags$())
          \tags$() = Trim(StringField(\aux\tags$, i, ","))
        Next i
      EndIf
    EndWith
    
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
  
  Procedure parseInfoLUA(file$, *mod.mod) ; parse info from lua file$ and save to *mod
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
      parseLUAlocale(GetPathPart(file$)+"strings.lua", "en", *mod, reg_val())
      parseLUAlocale(GetPathPart(file$)+"strings.lua", locale::getCurrentLocale(), *mod, reg_val())
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure infoPP(*mod.mod)    ; post processing
    debugger::Add("mods::infoPP("+Str(*mod)+")")
    ; authors
    With *mod
      \aux\authors$ = ""
      ForEach \authors()
        If \aux\authors$
          \aux\authors$ + ", "
        EndIf
        \aux\authors$ + \authors()\name$
      Next
    EndWith
    
    ; version
    With *mod
      \majorVersion = Val(StringField(*mod\id$, CountString(*mod\id$, "_")+1, "_"))
      If \aux\version$ And Not \minorVersion
        \minorVersion = Val(StringField(\aux\version$, 2, "."))
      EndIf
      \aux\version$ = Str(\majorVersion)+"."+Str(\minorVersion)
    EndWith
    
    ; tags
    With *mod
      \aux\tags$ = ""
      ForEach \tags$()
        If \aux\tags$
          \aux\tags$ + ", "
        EndIf
        \aux\tags$ + locale::l("tags", \tags$())
      Next
    EndWith
    
    ProcedureReturn #True
  EndProcedure
  
  ; TODO : extract & load all necesarry information at each startup!
  
  Procedure debugInfo(*mod.mod)
    Protected deb$
    debugger::Add("mods::debugInfo() - id: "+*mod\id$)
    debugger::Add("mods::debugInfo() - name: "+*mod\name$)
    ForEach *mod\authors()
      debugger::Add("mods::debugInfo() - author: "+*mod\authors()\name$+", "+*mod\authors()\role$+", "+*mod\authors()\text$+", "+*mod\authors()\steamProfile$+", "+Str(*mod\authors()\tfnetId))
    Next
    debugger::Add("mods::debugInfo() - minorVersion: "+Str(*mod\minorVersion))
    debugger::Add("mods::debugInfo() - severityAdd: "+*mod\severityAdd$)
    debugger::Add("mods::debugInfo() - severityRemove: "+*mod\severityRemove$)
    debugger::Add("mods::debugInfo() - description: "+*mod\description$)
    debugger::Add("mods::debugInfo() - tfnetId: "+Str(*mod\tfnetId))
    debugger::Add("mods::debugInfo() - minGameVersion: "+Str(*mod\minGameVersion))
    debugger::Add("mods::debugInfo() - url: "+*mod\url$)
    deb$ = "mods::debugInfo() - tags: "
    ForEach *mod\tags$()
      deb$ + *mod\tags$()+", "
    Next
    debugger::Add(deb$)
    deb$ = "mods::debugInfo() - dependencies: "
    ForEach *mod\dependencies$()
      deb$ + *mod\dependencies$()+", "
    Next
    debugger::Add(deb$)
  EndProcedure
  
  Procedure getInfo(file$, *mod.mod, id$) ; extract info from new mod file$ (tfmm.ini, info.lua, ...)
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
    Protected NewList files$()
    AddElement(files$()) : files$() = "tfmm.ini"
    AddElement(files$()) : files$() = "info.lua"
    AddElement(files$()) : files$() = "strings.lua"
    
    ForEach files$()
      DeleteFile(tmpDir$ + files$(), #PB_FileSystem_Force)
    Next
    
    If Not ExtractFilesZip(file$, files$(), tmpDir$)
      If Not ExtractFilesRar(file$, files$(), tmpDir$)
        debugger::Add("mods::GetModInfo() - failed to open {"+file$+"} for extraction")
      EndIf
    EndIf
    
    ; read tfmm.ini
    parseTFMMini(tmpDir$ + "tfmm.ini", *mod)
    DeleteFile(tmpDir$ + "tfmm.ini")
    
    ; read info.lua
    parseInfoLUA(tmpDir$ + "info.lua", *mod)
    DeleteFile(tmpDir$ + "info.lua")
    
    If Not generateID(*mod, id$)
      ProcedureReturn #False
    EndIf
    
    ; Post Processing
    infoPP(*mod)
    
    debugInfo(*mod)
    
    ; generate info.lua (in memory)
    generateLUA(*mod)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure loadInfo(TF$, id$, *mod.mod)
    debugger::Add("mods::loadInfo("+TF$+", "+id$+", "+Str(*mod.mod)+")")
    
    If TF$ = ""
      ProcedureReturn #False
    EndIf
    
    Protected fileLib$, fileMods$
    
    fileLib$ = misc::Path(TF$ + "/TFMM/library/" + id$ + "/") + "info.lua"
    fileMods$ = misc::Path(TF$ + "/mods/" + id$ + "/") + "info.lua"
    
    *mod\id$ = id$
    
    Protected sizeLib, sizeMods
    sizeLib = FileSize(fileLib$)
    sizeMods = FileSize(fileMods$)
    
    If sizeLib >= 0 And sizeMods >= 0 ; in lib and mods -> installed
      *mod\aux\TFonly = #False
      *mod\aux\installed = #True
      parseInfoLUA(fileMods$, *mod) ; parse from install location
      
    ElseIf sizeLib >= 0 And sizeMods < 0 ; in lib, not in mods -> not installed
      *mod\aux\TFonly = #False
      *mod\aux\installed = #False
      parseInfoLUA(fileLib$, *mod) ; parse from lib
      
    ElseIf sizeLib < 0 And sizeMods >= 0 ; not in lib but in mods -> installed (TFONLY)
      *mod\aux\TFonly = #True
      *mod\aux\installed = #True
      parseInfoLUA(fileMods$, *mod) ; parse from install location
      
    Else ; not installed and not in lib -> mod does not exist!
      debugger::Add("mods::loadInfo() - ERROR - mod not found in lib and mods!")
      ProcedureReturn #False
    EndIf
    
    infoPP(*mod)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure toList(*mod.mod)
    debugger::Add("mods::toList("+Str(*mod)+")")
    Protected count.i
    If FindMapElement(*mods(), *mod\id$)
      *mods(*mod\id$) = *mod
      ; *mod already in list
      debugger::Add("mods::toList() - ERROR - mod already in list")
    Else
      *mods(*mod\id$) = *mod
      If IsGadget(library)
        count = CountGadgetItems(library)
        With *mod
          ListIcon::AddListItem(library, count, \name$ + Chr(10) + \aux\authors$ + Chr(10) + \aux\tags$ + Chr(10) + \aux\version$)
          ListIcon::SetListItemData(library, count, *mod)
          If \aux\installed
            ListIcon::SetListItemImage(library, count, ImageID(images::Images("yes")))
          Else 
            ListIcon::SetListItemImage(library, count, ImageID(images::Images("no")))
          EndIf
        EndWith
      EndIf
    EndIf
  EndProcedure
  
  Procedure extractZIP(file$, path$)
    debugger::Add("mods::extractZIP("+File$+")")
    Protected zip, error
    
    zip = OpenPack(#PB_Any, File$, #PB_PackerPlugin_Zip)
    If Not zip
      debugger::Add("mods::extractZIP() - ERROR - failed to open {"+file$+"}")
      ProcedureReturn #False 
    EndIf
    
    If Not ExaminePack(zip)
      debugger::Add("mods::ExtractModZip() - ERROR - failed to examining pack")
      ProcedureReturn #False
    EndIf
    
    path$ = misc::Path(path$)
    
    While NextPackEntry(zip)
      ; filter out Mac OS X bullshit
      If FindString(PackEntryName(zip), "__MACOSX") Or FindString(PackEntryName(zip), ".DS_Store") Or Left(GetFilePart(PackEntryName(zip)), 2) = "._"
        Continue
      EndIf
      
      file$ = PackEntryName(zip)
      file$ = misc::Path(GetPathPart(file$), "/")+GetFilePart(file$)
      debugger::Add("mods::extractZIP() - {"+file$+"}")
      If PackEntryType(zip) = #PB_Packer_File And PackEntrySize(zip) > 0
        If FindString(file$, "res/") ; only extract files which are located in subfoldres of res/
          file$ = Mid(file$, FindString(file$, "res/")) ; let all paths start with "res/" (if res is located in a subfolder!)
          ; adjust path delimiters to OS
          file$ = misc::Path(GetPathPart(file$)) + GetFilePart(file$)
          misc::CreateDirectoryAll(GetPathPart(path$ + file$))
          If UncompressPackFile(zip, path$ + file$, PackEntryName(zip)) = 0
            debugger::Add("mods::extractZIP() - ERROR - failed uncrompressing {"+PackEntryName(zip)+"} to {"+Path$ + File$+"}")
          EndIf
        EndIf
      EndIf
    Wend
    
    ClosePack(zip)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure extractRAR(file$, path$)
    debugger::Add("mods::extractRAR("+file$+", "+path$+")")
    
    Protected rarheader.unrar::RARHeaderDataEx
    Protected hRAR
    Protected Entry$
    
    hRAR = unrar::OpenRar(file$, unrar::#RAR_OM_EXTRACT)
    If Not hRAR
      debugger::Add("mods::extractRAR() - ERROR - failed to open {"+file$+"}")
      ProcedureReturn #False
    EndIf
    
    While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS
      CompilerIf #PB_Compiler_Unicode
        Entry$ = PeekS(@rarheader\FileNameW)
      CompilerElse
        Entry$ = PeekS(@rarheader\FileName,#PB_Ascii)
      CompilerEndIf
      
      ; filter out Mac OS X bullshit
      If FindString(Entry$, "__MACOSX") Or FindString(Entry$, ".DS_Store") Or Left(GetFilePart(Entry$), 2) = "._"
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; skip these files / entries
        Continue
      EndIf
      
      If FindString(entry$, "res\") ; only extract files to list which are located in subfoldres of res
        entry$ = Mid(entry$, FindString(entry$, "res\")) ; let all paths start with "res\" (if res is located in a subfolder!)
        entry$ = misc::Path(GetPathPart(entry$)) + GetFilePart(entry$) ; translate to correct delimiter: \ or /
  
        If unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #NULL$, Path$ + entry$) <> unrar::#ERAR_SUCCESS ; uncompress current file to modified tmp path
          debugger::Add("mods::extractRAR() - ERROR: failed to uncompress {"+entry$+"}")
        EndIf
      Else
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; file not in "res", skip it
      EndIf
      
    Wend
    unrar::RARCloseArchive(hRAR)
  
    ProcedureReturn #True
  EndProcedure
  
  ;PUBLIC
  
  Procedure changed()
    Protected ret = changed
    changed = #False
    ProcedureReturn ret
  EndProcedure
  
  Procedure registerLibraryGadget(lib)
    debugger::Add("registerLibraryGadget("+Str(lib)+")")
    library = lib
    ProcedureReturn lib
  EndProcedure
  
  Procedure init() ; allocate mod structure
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
    If Not getInfo(file$, *mod, id$)
      debugger::Add("mods::addMod() - ERROR: failed to retrieve info")
      FreeStructure(*mod)
      ProcedureReturn #False
    EndIf
    
    
    ; third step: check if mod with same ID already installed
    Protected sameHash.b = #False, sameID.b = #False
    ForEach *mods()
      If *mods()\aux\md5$ = *mod\aux\md5$ And *mod\aux\md5$
        debugger::Add("mods::addMod() - MD5 check found match!")
        id$ = *mods()\id$
        sameHash = #True
        Break
      EndIf
    Next
    
    If sameHash
      Protected NewMap strings$()
      ClearMap(strings$())
      strings$("name") = *mods(id$)\name$
      If *mods()\aux\installed
        MessageRequester(locale::l("main","install"), locale::getEx("management","conflict_hash",strings$()), #PB_MessageRequester_Ok)
        debugger::Add("mods::addMod() - cancel new installed, mod already installed")
      Else
        debugger::Add("mods::addMod() - trigger install of previous mod")
        queue::add(queue::#QueueActionInstall, id$)
      EndIf
      FreeStructure(*mod)
      ProcedureReturn #True
    EndIf
    
    If FindMapElement(*mods(),  *mod\id$)
      debugger::Add("mods::addMod() - Another mod with id {"+id$+"} already in list!")
      id$ = *mod\id$
      sameID = #True
    EndIf
    
    If sameID
      Protected NewMap strings$()
      ClearMap(strings$())
      strings$("id") = *mod\id$
      strings$("old_name") = *mods(id$)\name$
      strings$("old_version") = *mods(id$)\aux\version$
      strings$("new_name") = *mod\name$
      strings$("new_version") = *mod\aux\version$
      If MessageRequester(locale::l("main","install"), locale::getEx("management","conflict_id",strings$()), #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
        ; user does not want to replace
        FreeStructure(*mod)
        ProcedureReturn #True
      Else
        ; user wants to replace
        queue::add(queue::#QueueActionRemove, *mod\id$) ; remove from TF is present
        queue::add(queue::#QueueActionDelete, *mod\id$) ; delete from library
        queue::add(queue::#QueueActionNew, file$) ; re-schedule this mod
        FreeStructure(*mod)
        ProcedureReturn #True
      EndIf
    EndIf
    
    ; fourth step: move mod to internal TFMM mod folder and extract all recognised info files
    id$ = *mod\id$
    Protected dir$ = misc::Path(TF$+"/TFMM/library/"+id$)
    debugger::Add("mods::addMod() - add mod to library: {"+dir$+"}")
    ; create library entry (subdir)
    If Not misc::CreateDirectoryAll(dir$)
      debugger::Add("mods::addMod() - ERROR - failed to create {"+dir$+"}")
      FreeStructure(*mod)
      ProcedureReturn #False
    EndIf
    
    ; copy file to library
;     Protected newfile$ = dir$ + id$ + "." + LCase(GetExtensionPart(file$))
    Protected newfile$ = dir$ + id$ + ".tfmod"
    debugger::Add("mods::addMod() - copy file to library: {"+file$+"} -> {"+newfile$+"}")
    
    If Not CopyFile(file$, newfile$)
      debugger::Add("mods::addMod() - ERROR - failed to copy file {"+file$+"} -> {"+dir$+GetFilePart(file$)+"}")
      FreeStructure(*mod)
      ProcedureReturn #False
    EndIf
    
    ; extract files
    Protected NewList files$()
    ClearList(files$())
    AddElement(files$()) : files$() = "info.lua"
    AddElement(files$()) : files$() = "strings.lua"
    AddElement(files$()) : files$() = "main.lua"
    AddElement(files$()) : files$() = "filesystem.lua"
    ; TODO check if these important files needs to be re-extracted ?!
    
    AddElement(files$()) : files$() = "header.jpg"
    AddElement(files$()) : files$() = "preview.png"
    AddElement(files$()) : files$() = "image_00.tga"
    If Not ExtractFilesZip(newfile$, files$(), dir$)
      If Not ExtractFilesRar(newfile$, files$(), dir$)
        debugger::Add("mods::GetModInfo() - failed to open {"+newfile$+"} for extraction")
      EndIf
    EndIf
    
    Protected file
    If FileSize(dir$ + "info.lua") <= 0
      file = CreateFile(#PB_Any, dir$ + "info.lua")
      If file
        WriteString(file, *mod\aux\lua$, #PB_UTF8)
        CloseFile(file)
      EndIf
    EndIf
    
    
    ; images
    debugger::Add("mosd::new() - convert images")
    Protected im, image$, i
    image$ = dir$ + "header.jpg"
    If FileSize(image$) > 0
      im = LoadImage(#PB_Any, image$)
      If IsImage(im)
;         im = misc::ResizeCenterImage(im, 320, 180)
        i = 0
        Repeat
          image$ = dir$ + "image_" + RSet(Str(i) , 2, "0") + ".tga"
          i + 1
        Until FileSize(image$) <= 0
        misc::encodeTGA(im, image$, 24)
        FreeImage(im)
        DeleteFile(dir$ + "header.jpg")
      EndIf
    EndIf
    image$ = dir$ + "preview.png"
    If FileSize(image$) > 0
      im = LoadImage(#PB_Any, image$)
      If IsImage(im)
;         im = misc::ResizeCenterImage(im, 320, 180)
        i = 0
        Repeat
          image$ = dir$ + "image_" + RSet(Str(i) , 2, "0") + ".tga"
          i + 1
        Until FileSize(image$) <= 0
        misc::encodeTGA(im, image$, 32)
        FreeImage(im)
        DeleteFile(dir$ + "preview.png")
      EndIf
    EndIf
    
    
    ; fifth step: add mod to list
    toList(*mod)
    
    changed = #True
    
    ; last step: init install
    queue::add(queue::#QueueActionInstall, id$)
    ProcedureReturn #True
  EndProcedure
  
  Procedure load(*data.queue::dat) ; TF$) ; load all mods in internal modding folder and installed to TF
    Protected TF$ = *data\tf$
    debugger::Add("mods::load("+TF$+")")
    Protected pmods$, plib$, ptmp$, entry$
    Protected pmodsentry$, plibentry$, image$
    Protected dir, i
    Protected *mod.mod
    
    plib$   = misc::Path(TF$ + "/TFMM/library/")
    pmods$  = misc::Path(TF$ + "/mods/")
    ptmp$   = GetTemporaryDirectory()
    
    debugger::Add("mods::load() - read library {"+plib$+"}")
    dir = ExamineDirectory(#PB_Any, plib$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If Not checkID(entry$)
          Continue
        EndIf
        debugger::Add("mods::load() - found {"+entry$+"} in library")
        ; id$ = entry$
        
        plibentry$  = misc::Path(plib$ + entry$ + "/")
        pmodsentry$ = misc::Path(pmods$ + entry$ + "/")
        
        *mod = init()
        *mod\aux\file$ = plibentry$ + entry$ + ".tfmod"
        *mod\aux\md5$ = MD5FileFingerprint(*mod\aux\file$)
        
        ; check if installed
        If FileSize(misc::Path(pmods$ + entry$ + "/")) = -2
          ; TODO re-import mod if it was changed manually or with another manager! (version check?)
          
          *mod\aux\installed = #True
          debugger::Add("mods::load() - update info of {"+entry$+"} from mod directory")
          ; copy info.lua from TF/mods/ to TFMM/library to have current information available
          CopyFile(pmodsentry$ + "info.lua", plibentry$ + "info.lua")
          CopyFile(pmodsentry$ + "strings.lua", plibentry$ + "strings.lua")
          i = 0
          Repeat
            image$ = "image_" + RSet(Str(i), 2, "0")
            If FileSize(pmodsentry$ + image$) <= 0
              Break
            EndIf
            DeleteFile(plibentry$ + image$)
            CopyFile(pmodsentry$ + image$, plibentry$ + image$)
            i + 1
          ForEver
          
        EndIf
        
        loadInfo(TF$, entry$, *mod)
        toList(*mod)
      Wend
      FinishDirectory(dir)
    EndIf
    
    
    ; check mods from mods/ folder (installed)
    debugger::Add("mods::load() - read installed mods {"+pmods$+"}")
    dir = ExamineDirectory(#PB_Any, pmods$, "")
    If dir 
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If Not checkID(entry$)
          Continue
        EndIf
        
        If FindMapElement(*mods(), entry$)
          *mods()\aux\installed = #True
        Else
          ; mod installed but not in list
          ; add to library
          debugger::Add("mods::load() - load mod into library: {"+pmods$+entry$+"} -> {"+ptmp$+entry$+".zip"+"}")
          
          *mod = init()
          *mod\aux\file$ = ""
          *mod\aux\md5$ = ""
          loadInfo(TF$, entry$, *mod)
          toList(*mod)
        
;           If misc::packDirectory(pmods$ + entry$, ptmp$ + entry$ + ".zip")
;             queue::add(queue::#QueueActionNew, ptmp$ + entry$ + ".zip")
;           EndIf
        EndIf
        
      Wend
      FinishDirectory(dir)
    EndIf
    
  EndProcedure
  
  Procedure convert(*data.queue::dat)
    If MessageRequester(locale::l("conversion","title"), locale::l("conversion","start"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
      MessageRequester(locale::l("conversion","title"), locale::l("conversion","legacy"))
      ProcedureReturn #False
    EndIf
    
    Protected TF$ = *data\tf$
    debugger::Add("mods::convert("+TF$+")")
    
    Protected file$, NewList mods$(), NewMap files$()
    Protected i
    debugger::Add("mods::convert() - load mods.ini")
    
    OpenPreferences(misc::Path(TF$ + "/TFMM/") + "mods.ini")
    If ExaminePreferenceGroups()
      While NextPreferenceGroup()
        file$ = ReadPreferenceString("file", "")
        If file$
          debugger::Add("mods::convert() - found {"+file$+"}")
          AddElement(mods$())
          mods$() = misc::path(TF$ + "TFMM/Mods/") + file$
        EndIf
      Wend
    EndIf
    ClosePreferences()
    i = 0
    If ListSize(mods$()) > 0
      ; just add everything
      ForEach mods$()
        i + 1
        queue::progressVal(i, ListSize(mods$()))
        ; do not add to queue in order to wait in this thread until all mods are added , then delete files afterwards
        new(mods$(), TF$)
      Next
      ClearList(mods$())
    EndIf
    DeleteFile(misc::Path(TF$ + "/TFMM/") + "mods.ini")
    
    ; delete mod folder
    DeleteDirectory(misc::path(TF$ + "TFMM/Mods/"), "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    ; delete filetracker files +filetracker.ini
    OpenPreferences(misc::Path(TF$ + "/TFMM/") + "filetracker.ini")
    If ExaminePreferenceGroups()
      While NextPreferenceGroup()
        If ExaminePreferenceKeys()
          While NextPreferenceKey()
            file$ = TF$ + PreferenceKeyName()
            files$(file$) = PreferenceKeyValue()
          Wend
        EndIf
      Wend
    EndIf
    ClosePreferences()
    i = 0
    ForEach files$()
      file$ = MapKey(files$())
      If MD5FileFingerprint(file$) = files$()
        i + 1
        queue::progressVal(i, MapSize(files$()))
        debugger::Add("mods::convert() - delete {"+file$+"}")
      DeleteFile(file$, #PB_FileSystem_Force)
      EndIf
    Next
    DeleteFile(misc::Path(TF$ + "/TFMM/") + "filetracker.ini")
    DeleteFile(misc::Path(TF$ + "/TFMM/") + "mod-dependencies.ini")
    
    ; delete backup folder
    DeleteDirectory(misc::path(TF$ + "TFMM/Backup/"), "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    MessageRequester(locale::l("conversion","title"), locale::l("conversion","finish"))
    ProcedureReturn #True
  EndProcedure
  
  Procedure install(*data.queue::dat)
    debugger::Add("mods::install("+Str(*data)+")")
    Protected TF$, id$
    id$ = *data\id$
    tf$ = *data\tf$
    
    debugger::Add("mods::install() - mod {"+id$+"}")
    
    Protected *mod.mod = *mods(id$)
    Protected source$, target$
    Protected i
    
    ; check prequesits
    If Not *mod
      debugger::Add("mods::install() - ERROR - cannot find mod in map")
      ProcedureReturn #False
    EndIf
    If *mod\aux\installed
      debugger::Add("mods::install() - {"+id$+"} already installed")
      ProcedureReturn #False
    EndIf
    
    ; extract files
    source$ = misc::Path(tf$+"TFMM/library/"+id$+"/") + id$ + ".tfmod"
    target$ = misc::Path(tf$+"/mods/"+id$+"/")
    
    If FileSize(target$) = -2
      debugger::Add("mods::install() - {"+target$+"} already exists - assume already installed")
      *mod\aux\installed = #True
      If IsGadget(library)
        For i = 0 To CountGadgetItems(library) -1
          If ListIcon::GetListItemData(library, i) = *mod
            ListIcon::SetListItemImage(library, i, ImageID(images::Images("yes")))
            Break
          EndIf
        Next
      EndIf
      ProcedureReturn #True
    EndIf
    misc::CreateDirectoryAll(target$)
    
    If Not extractZIP(source$, target$)
      If Not extractRAR(source$, target$)
        debugger::Add("mods::install() - ERROR - failed to extract files")
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; copy info.lua and images
    debugger::Add("mods::install() - copy info.lua and images")
    source$ = misc::Path(tf$+"TFMM/library/"+id$+"/")
    target$ = misc::Path(tf$+"/mods/"+id$+"/")
    
    CopyFile(source$ + "info.lua", target$ + "info.lua")
    CopyFile(source$ + "strings.lua", target$ + "strings.lua")
    CopyFile(source$ + "filesystem.lua", target$ + "filesystem.lua")
    CopyFile(source$ + "main.lua", target$ + "main.lua")
    CopyFile(source$ + "image_00.tga", target$ + "image_00.tga")
    ; TODO copy all images
    
    ; finish installation
    debugger::Add("mods::install() - finish installation...")
    *mod\aux\installed = #True
    If IsGadget(library)
      For i = 0 To CountGadgetItems(library) -1
        If ListIcon::GetListItemData(library, i) = *mod
          ListIcon::SetListItemImage(library, i, ImageID(images::Images("yes")))
          Break
        EndIf
      Next
    EndIf
    
    debugger::Add("mods::install() - finished")
    ProcedureReturn #True
  EndProcedure
  
  Procedure remove(*data.queue::dat)
    debugger::Add("mods::remove("+Str(*data)+")")
    Protected TF$, id$
    id$ = *data\id$
    tf$ = *data\tf$
    
    
    debugger::Add("mods::remove() - mod {"+id$+"}")
    
    Protected *mod.mod = *mods(id$)
    Protected targetDir$
    Protected i
    
    ; TODO alternatively, backup mod
    If *mod\aux\TFonly
      ; queue::add(queue::#QueueActionDelete, id$)
      delete(*data)
    EndIf
    
    ; check prequesits
    If Not *mod
      debugger::Add("mods::remove() - ERROR - cannot find mod in map")
      ProcedureReturn #False
    EndIf
    If Not *mod\aux\installed
      debugger::Add("mods::remove() - ERROR - {"+id$+"} not installed")
      ProcedureReturn #False
    EndIf
    
    ; delete folder
    targetDir$ = misc::Path(tf$+"/mods/"+id$+"/")
    
    debugger::add("mods::remove() - delete {"+targetDir$+"} and all subfolders")
    DeleteDirectory(targetDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    ; finish removal
    
    *mod\aux\installed = #False
    If IsGadget(library)
      For i = 0 To CountGadgetItems(library) -1
        If ListIcon::GetListItemData(library, i) = *mod
          ListIcon::SetListItemImage(library, i, ImageID(images::Images("no")))
          Break
        EndIf
      Next
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure delete(*data.queue::dat) ; delete mod from library
    debugger::Add("mods::delete("+Str(*data)+")")
    Protected TF$, id$
    id$ = *data\id$
    tf$ = *data\tf$
    
    debugger::Add("mods::delete() - mod {"+id$+"}")
    
    Protected *mod.mod = *mods(id$)
    Protected targetDir$
    Protected i
    
    ; check prequesits
    If Not *mod
      debugger::Add("mods::delete() - ERROR - cannot find mod in map")
      ProcedureReturn #False
    EndIf
    If *mod\aux\installed
      debugger::Add("mods::delete() - ERROR - mod is still installed, remove first")
      If Not remove(*data)
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; delete folder
    targetDir$ = misc::Path(tf$+"/TFMM/library/"+id$+"/")
    
    debugger::add("mods::delete() - delete {"+targetDir$+"} and all subfolders")
    DeleteDirectory(targetDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    ; finish deletion
    If IsGadget(library)
      For i = 0 To CountGadgetItems(library) -1
        If ListIcon::GetListItemData(library, i) = *mod
          ListIcon::RemoveListItem(library, i)
          Break
        EndIf
      Next
    EndIf
    free(id$)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure generateID(*mod.mod, id$ = "")
    debugger::Add("mods::generateID("+Str(*mod)+", "+id$+")")
    Protected author$, name$, version$
    
    If Not *mod
      ProcedureReturn
    EndIf
    
    Static RegExp
    If Not RegExp
      RegExp  = CreateRegularExpression(#PB_Any, "[^a-z0-9]") ; non-alphanumeric characters
      ; regexp matches all non alphanum characters including spaces etc.
    EndIf
    
    With *mod
      If id$
        debugger::Add("mods::generateID() - passed through id = {"+id$+"}")
        ; this id$ is passed through, extracted from subfolder name
        ; if it is present, check if it is well-defined
        If checkID(id$)
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
      If \id$ And checkID(\id$)
        debugger::Add("mods::generateID() - ID {"+\id$+"} is well defined (first)")
        ProcedureReturn #True
      EndIf
      
      ; Check if ID in old format
      author$   = StringField(\id$, 1, ".")
      name$     = StringField(\id$, CountString(\id$, ".")+1, ".")
      version$  = Str(Abs(Val(StringField(\aux\version$, 1, "."))))
      \id$ = author$ + "_" + name$ + "_" + version$
      
      If \id$ And checkID(\id$)
        debugger::Add("mods::generateID() - ID {"+\id$+"} is well defined")
        ProcedureReturn #True
      EndIf
      
      \id$ = ""
      
      debugger::Add("mods::generateID() - generate new ID")
      ; ID = author_mod_version
      If ListSize(\authors()) > 0
        LastElement(\authors())
        author$ = ReplaceRegularExpression(RegExp, LCase(\authors()\name$), "") ; remove all non alphanum + make lowercase
      Else
        author$ = ""
      EndIf
      If author$ = ""
        author$ = "unknownauthor"
      EndIf
      name$ = ReplaceRegularExpression(RegExp, LCase(\name$), "") ; remove all non alphanum + make lowercase
      If name$ = ""
        name$ = "unknown"
      EndIf
      version$ = Str(Val(StringField(\aux\version$, 1, "."))) ; first part of version string concatenated by "." as numeric value
      
      \id$ = author$ + "_" + name$ + "_" + version$ ; concatenate id parts
      
      If \id$ And checkID(\id$)
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
      Select LCase(\severityAdd$)
        Case "none"
          \severityAdd$ = "NONE"
        Case "warning"
          \severityAdd$ = "WARNING"
        Case "critical"
          \severityAdd$ = "CRITICAL"
        Default
          \severityAdd$ = "NONE"
      EndSelect
      Select LCase(\severityRemove$)
        Case "none"
          \severityRemove$ = "NONE"
        Case "warning"
          \severityRemove$ = "WARNING"
        Case "critical"
          \severityRemove$ = "CRITICAL"
        Default
          \severityRemove$ = "WARNING"
      EndSelect
      
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
; CursorPosition = 768
; FirstLine = 103
; Folding = RIgRAg
; EnableUnicode
; EnableXP