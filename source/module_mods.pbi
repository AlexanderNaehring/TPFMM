XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_unrar.pbi"
; XIncludeFile "module_parseLUA.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_queue.pbi"
XIncludeFile "module_luaParser.pbi"

XIncludeFile "module_mods.h.pbi"

Module mods
  
  Enumeration
    #system_old ; old modding system
    #system_new ; new modding system
  EndEnumeration
  
  Structure mod_scanner
    folderMods.b
    folderDLCs.b
    folderLibrary.b
  EndStructure
  
  Global NewMap *mods.mod()
  Global _window, _gadgetMod, _gadgetDLC, _gadgetEventTriggerDLC
  
  UseMD5Fingerprint()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure checkID(id$)
;     debugger::Add("mods::checkID("+id$+")")
    Static regexp
    If Not IsRegularExpression(regexp)
      ; mods: author_name_version
      ; DLC: name_version
      ; general: (alphanum_)*num
      ; regexp = CreateRegularExpression(#PB_Any, "^([a-z0-9]+_){2,}[0-9]+$") ; at least one author name
      regexp = CreateRegularExpression(#PB_Any, "^([a-z0-9]+_)+[0-9]+$") ; no author name required
    EndIf
    
    ProcedureReturn MatchRegularExpression(regexp, id$)
  EndProcedure
  
;   Procedure openArchive(*mod.mod, file$)
;     debugger::add("mods::openArchive("+*mod+", "+file$+")")
;     
;     If Not *mod
;       debugger::add("          ERROR: no memory adress defined")
;       ProcedureReturn #False
;     EndIf
;     If FileSize(file$) <= 0
;       debugger::add("          ERROR: file not found or empty")
;       ProcedureReturn #False
;     EndIf
;     
;     ; open archive
;     Protected handle = 0
;     If Not handle ; ZIP
;       debugger::add("          Try to open "+file$+" as zip")
;       handle = OpenPack(#PB_Any, file$, #PB_PackerPlugin_Zip)
;       If handle
;         debugger::add("          ... success")
;         *mod\archive\type = #TYPE_ZIP
;       Else
;         debugger::add("          ... failed")
;       EndIf
;     EndIf
;     If Not handle ; RAR
;       debugger::add("          Try to open "+file$+" as rar")
;       handle = unrar::OpenRar(File$, *mod, unrar::#RAR_OM_EXTRACT) ; #RAR_OM_LIST
;       If handle
;         debugger::add("          ... success")
;         *mod\archive\type = #TYPE_RAR
;       Else
;         debugger::add("          ... failed")
;       EndIf
;     EndIf
;     If Not handle
;       debugger::add("          ERROR: Could not open file")
;       ProcedureReturn #False
;     EndIf
;     
;     *mod\archive\handle = handle
;     
;     ; check if archive is a valid TF modification
;     
;     With *mod
;       
;     EndWith
;     
;   EndProcedure
;   
;   Procedure closeArchive(*mod.mod)
;     debugger::add("mods::closeArchive("+*mod+")")
;     If *mod\archive\handle
;       Select *mod\archive\type
;         Case #TYPE_ZIP
;           ClosePack(*mod\archive\handle)
;         Case #TYPE_RAR
;           unrar::RARCloseArchive(handle)
;       EndSelect
;       *mod\archive\handle = #Null
;     EndIf
;   EndProcedure
  
  ;- TODO do not return string but directly store "id" in *mod -> handle in other functions accordingly
  Procedure.s checkModFileZip(file$) ; check for res/ or info.lua
    debugger::Add("mods::CheckModFileZip("+file$+")")
    Protected entry$, pack
    
    pack = OpenPack(#PB_Any, file$)
    If pack
      If ExaminePack(pack)
        While NextPackEntry(pack)
          entry$ = PackEntryName(pack)
          entry$ = misc::Path(GetPathPart(entry$), "/")+GetFilePart(entry$)
          ; debugger::Add("mods::checkModFileZip() - {"+entry$+"}")
          If FindString(entry$, "res/") ; found a "res" subfolder, assume this mod is valid 
            ClosePack(pack)
            entry$ = GetFilePart(Left(entry$, FindString(entry$, "res/")-2)) ; entry = folder name (id)
            debugger::Add("mods::checkModFileZip() - found res/")
            ProcedureReturn entry$
          EndIf
          If GetFilePart(entry$) =  "info.lua" ; found info.lua, asume mod is valid
            ClosePack(pack)
            entry$ = GetFilePart(Left(entry$, FindString(entry$, "info.lua")-2)) ; entry = folder name (id)
            debugger::Add("mods::checkModFileZip() - found info.lua")
            ProcedureReturn entry$
          EndIf
        Wend
      EndIf
      ClosePack(pack)
    EndIf
    ProcedureReturn "false"
  EndProcedure
  
  Procedure.s checkModFileRar(file$, *mod.mod) ; check for res/ or info.lua
    debugger::Add("mods::CheckModFileRar("+File$+")")
    Protected rarheader.unrar::RARHeaderDataEx
    Protected hRAR
    Protected entry$
    
    hRAR = unrar::OpenRar(File$, *mod, unrar::#RAR_OM_LIST) ; only list rar files (do not extract)
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
          debugger::Add("mods::checkModFileRar() - found res\")
          ProcedureReturn entry$
        EndIf
        If GetFilePart(Entry$) =  "info.lua"
          unrar::RARCloseArchive(hRAR) ; found info.lua subfolder, assume this mod is valid
          entry$ = GetFilePart(Left(entry$, FindString(entry$, "info.lua")-2)) ; entry$ = parent folder = id
          debugger::Add("mods::checkModFileRar() - found info.lua")
          ProcedureReturn entry$
        EndIf
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #Null$, #Null$) ; skip to next entry in rar
      Wend
      unrar::RARCloseArchive(hRAR)
    EndIf
    ProcedureReturn "false"
  EndProcedure
  
  Procedure.s checkModFile(file$, *mod.mod) ; Check mod for a "res" folder or the info.lua file, called in new(), return mod ID if any
    debugger::add("mods::CheckModFile("+file$+")")
    Protected extension$, ret$
    
    extension$ = LCase(GetExtensionPart(File$))
    
    If FileSize(File$) <= 0
      debugger::Add("mods::checkModFile() - ERROR - {"+File$+"} not found")
      ProcedureReturn "false"
    EndIf
    
    ret$ = checkModFileZip(File$)
    If ret$ = "false"
      ret$ = checkModFileRar(file$, *mod)
      If ret$ = "false"
        ProcedureReturn "false"
      EndIf
    EndIf
    
    ProcedureReturn ret$
  EndProcedure
  
  Procedure ExtractFilesZip(zip$, List files$(), dir$) ; extracts all Files$() (from all subdirs!) to given directory
    debugger::Add("mods::ExtractFilesZip("+zip$+", Files$(), "+dir$+")")
    Protected deb$ = "mods::ExtractFilesZip() - search for: "
    ForEach files$() : deb$ + files$()+", " : Next
    debugger::Add(deb$)
    
    Protected zip, Entry$
    dir$ = misc::Path(dir$)
    
    zip = OpenPack(#PB_Any, zip$, #PB_PackerPlugin_Zip)
    If Not zip
      debugger::Add("ExtractFilesZip() - Error opening zip: "+ZIP$)
      ProcedureReturn #False
    EndIf
    
    If ExaminePack(zip)
      While NextPackEntry(zip)
        entry$ = PackEntryName(zip)
        If FindString(Entry$, "__MACOSX") Or FindString(Entry$, ".DS_Store") Or Left(GetFilePart(Entry$), 2) = "._"
          Continue
        EndIf
        
        entry$ = GetFilePart(entry$)
        ForEach files$()
          If LCase(Entry$) = LCase(Files$())
            debugger::add("          extract "+entry$+" -> "+dir$ + files$())
            If UncompressPackFile(zip, dir$ + files$()) = -1
              debugger::add("          ERROR: failed to extract file!")
            EndIf
            DeleteElement(Files$()) ; if file is extracted, delete from list
            Break ; ForEach
          EndIf
        Next
      Wend
    Else
      debugger::add("          ERROR: could not examine zip")
    EndIf
    ClosePack(zip)
    ProcedureReturn #True
  EndProcedure

  Procedure ExtractFilesRar(RAR$, List Files$(), dir$, *mod) ; extracts all Files$() (from all subdirs!) to given directory
    debugger::Add("ExtractFilesRar("+RAR$+", Files$(), "+dir$+")")
    Protected deb$ = "mods::ExtractFilesZip() - search for: "
    ForEach Files$() : deb$ + files$()+", " : Next
    debugger::Add(deb$)
    
    Protected rarheader.unrar::RARHeaderDataEx
    Protected hRAR, hit
    Protected Entry$
    dir$ = misc::Path(dir$)
    
    hRAR = unrar::OpenRar(RAR$, *mod, unrar::#RAR_OM_EXTRACT)
    If Not hRAR
      debugger::Add("ExtractFilesRar() - Error opening rar: "+RAR$)
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
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #Null$, #Null$) ; skip these files / entries
        Continue
      EndIf
      
      hit = #False
      ForEach Files$()
        entry$ = GetFilePart(entry$)
        If LCase(entry$) = LCase(Files$())
          unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #Null$, dir$ + Files$())
          DeleteElement(Files$()) ; if file is extracted, delete from list
          hit = #True
          Break ; ForEach
        EndIf
      Next
      If Not hit
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #Null$, #Null$)
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
      
      \tf_id$ = ReadPreferenceString("id", "")
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
      
      \aux\active = 0
      
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
  
  Procedure parseInfoLUA(file$, *mod.mod)
    Protected ret
    ret = luaParser::parseInfoLUA(file$, *mod)
    If ret
      ; everytime when loading info from lua, save lua date to mod
      ; then, information only has to be reloaded if info.lua is changed
      *mod\aux\luaDate = GetFileDate(file$, #PB_Date_Modified)
    EndIf
    ProcedureReturn ret
  EndProcedure
  
  Procedure infoPP(*mod.mod)    ; post processing: authors have to be 
;     debugger::Add("mods::infoPP("+Str(*mod)+")")
    ; authors: write \aux\authors$ string
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
      \majorVersion = Val(StringField(*mod\tf_id$, CountString(*mod\tf_id$, "_")+1, "_"))
      If \aux\version$ And Not \minorVersion
        \minorVersion = Val(StringField(\aux\version$, 2, "."))
      EndIf
      \aux\version$ = Str(\majorVersion)+"."+Str(\minorVersion)
    EndWith
    
    ; tags
    With *mod
      \aux\tags$ = ""
      ForEach \tags$()
        If \aux\tags$ : \aux\tags$ + ", " : EndIf
        \aux\tags$ + locale::l("tags", LCase(\tags$()))
      Next
    EndWith
    
    ; if name or author not available
    With *mod
      Protected count, i
      count = CountString(\tf_id$, "_")
      ; get author from ID
      If \aux\authors$ = ""
        If count = 1 ; only name and version in ID
          \aux\authors$ = "unknown"
        Else ; author, name and version in ID
          \aux\authors$ = StringField(\tf_id$, 1, "_")
        EndIf
        AddElement(\authors())
        \authors()\name$ = \aux\authors$
      EndIf
      ; get name from ID
      If \name$ = ""
        If count = 1
          \name$ = StringField(\tf_id$, 1, "_")
        Else
          For i = 2 To count
            If \name$ : \name$ + "_" : EndIf
            \name$ + StringField(\tf_id$, i, "_")
          Next
        EndIf
      EndIf
    EndWith
    
    ; Check for DLC
    ; known DLC: usa_1 and nordic_1
    If *mod\tf_id$ = "usa_1" Or *mod\tf_id$ = "nordic_1"
      *mod\isDLC = #True
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure debugInfo(*mod.mod)
    Protected json, json$
    
    json = CreateJSON(#PB_Any)
    InsertJSONStructure(JSONValue(json), *mod, mod)
    json$ = ComposeJSON(json, #PB_JSON_PrettyPrint)
    FreeJSON(json)
    debugger::add("mods::debugInfo(): "+json$)
    ProcedureReturn #True
  EndProcedure
  
  Procedure clearModInfo(*mod.mod)
    ; clean info
    ClearStructure(*mod, mod)
    InitializeStructure(*mod, mod)
  EndProcedure
  
  Procedure getInfo(file$, *mod.mod, id$) ; extract info from new mod file$ (tfmm.ini, info.lua, ...)
    debugger::Add("mods::getInfo("+file$+", "+Str(*mod)+", "+id$+")")
    Protected tmpDir$ = misc::Path(GetTemporaryDirectory()+"/tfmm/")
    misc::CreateDirectoryAll(tmpDir$)
    
    If FileSize(file$) <= 0
      debugger::add("mods::GetModInfo() - ERROR: no file {"+file$+"}")
      ProcedureReturn #False
    EndIf
    
    ; read standard information
    With *mod
      \archive\name$ = GetFilePart(file$)
      \archive\md5$ = FileFingerprint(file$, #PB_Cipher_MD5)
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
    ForEach files$()
      If FileSize(files$()) >= 0
        debugger::add("          ERROR: file "+files$()+" still present in temporary folder")
      EndIf
    Next
    
    If Not ExtractFilesZip(file$, files$(), tmpDir$)
      If Not ExtractFilesRar(file$, files$(), tmpDir$, *mod)
        debugger::Add("mods::GetModInfo() - failed to open {"+file$+"} for extraction")
      EndIf
    EndIf
    
    ; read tfmm.ini
    parseTFMMini(tmpDir$ + "tfmm.ini", *mod)
    DeleteFile(tmpDir$ + "tfmm.ini")
    
    ; read info.lua
    parseInfoLUA(tmpDir$ + "info.lua", *mod)
    DeleteFile(tmpDir$ + "info.lua")
    DeleteFile(tmpDir$ + "strings.lua")
    
    If Not generateID(*mod, id$)
      ProcedureReturn #False
    EndIf
    
    ; Post Processing
    infoPP(*mod)
    
    ; print mod information
    debugInfo(*mod)
    
    ; generate info.lua (in memory)
    ; generateLUA(*mod)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure addToMap(*mod.mod)
    Protected count.i, id$ = *mod\tf_id$
    
    If id$ = ""
      ProcedureReturn #False
    EndIf
    
    If FindMapElement(*mods(), id$)
      If *mods() = *mod ; same pointer = identical mod
        ; do nothing
      Else ; different mods with same tf_id! -> overwrite old mod
        debugger::Add("mods::toList() - WARNING: mod {"+*mod\tf_id$+"} already in list -> delete old mod and overwrite with new")
        FreeStructure(*mods())
        DeleteMapElement(*mods(), *mod\tf_id$)
      EndIf
    EndIf
    
    *mods(id$) = *mod ; add (or overwrite) mod to/in map
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
      file$ = misc::Path(GetPathPart(file$), "/")+GetFilePart(file$) ; zip always uses "/"
      ; debugger::Add("mods::extractZIP() - {"+file$+"}")
      If PackEntryType(zip) = #PB_Packer_File And PackEntrySize(zip) > 0
        If FindString(file$, "res/") ; only extract files which are located in subfoldres of res/
          file$ = Mid(file$, FindString(file$, "res/")) ; let all paths start with "res/" (if res is located in a subfolder!)
          file$ = misc::Path(GetPathPart(file$)) + GetFilePart(file$)
          misc::CreateDirectoryAll(GetPathPart(path$ + file$))
          debugger::Add("          extract {"+file$+"}")
          If UncompressPackFile(zip, path$ + file$) = -1
            debugger::Add("mods::extractZIP() - ERROR - failed uncrompressing {"+PackEntryName(zip)+"} to {"+Path$ + File$+"}")
          EndIf
        ElseIf FindString(file$, "main.lua") Or
               FindString(file$, "info.lua") Or
               FindString(file$, "strings.lua") Or
               FindString(file$, "filesystem.lua") Or
               FindString(file$, "image_00.tga")
          debugger::Add("          extract {"+file$+"}")
          file$ = GetFilePart(file$) ; these files will be stored directly in the root folder of the mod
          If UncompressPackFile(zip, path$ + file$) = -1
            debugger::Add("mods::extractZIP() - ERROR - failed uncrompressing {"+PackEntryName(zip)+"} to {"+Path$ + file$+"}")
          EndIf
        EndIf
      EndIf
    Wend
    
    ClosePack(zip)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure extractRAR(file$, path$, *mod)
    debugger::Add("mods::extractRAR("+file$+", "+path$+")")
    
    Protected rarheader.unrar::RARHeaderDataEx
    Protected hRAR
    Protected entry$
    
    hRAR = unrar::OpenRar(file$, *mod, unrar::#RAR_OM_EXTRACT)
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
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #Null$, #Null$) ; skip these files / entries
        Continue
      EndIf
      
      If FindString(entry$, "res\") ; only extract files to list which are located in subfoldres of res
        entry$ = Mid(entry$, FindString(entry$, "res\")) ; let all paths start with "res\" (if res is located in a subfolder!)
        entry$ = misc::Path(GetPathPart(entry$)) + GetFilePart(entry$) ; translate to correct delimiter: \ or /
        
        If unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #Null$, path$ + entry$) <> unrar::#ERAR_SUCCESS ; uncompress current file to modified tmp path
          debugger::Add("mods::extractRAR() - ERROR: failed to uncompress {"+entry$+"}")
        EndIf
      ElseIf FindString(entry$, "main.lua") Or
             FindString(entry$, "info.lua") Or
             FindString(entry$, "strings.lua") Or
             FindString(entry$, "filesystem.lua") Or
             FindString(entry$, "image_00.tga")
        entry$ = GetFilePart(entry$)
        If unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #Null$, path$ + entry$) <> unrar::#ERAR_SUCCESS
          debugger::Add("mods::extractRAR() - ERROR: failed to uncompress {"+entry$+"}")
        EndIf
      Else
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #Null$, #Null$) ; file not in "res", skip it
      EndIf
      
    Wend
    unrar::RARCloseArchive(hRAR)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure exportListHTML(all, file$)
    debugger::add("mods::exportListHTML("+all+", "+file$+")")
    Protected file
    Protected *modinfo.mod
    Protected name$, author$, authors$
    
    file = CreateFile(#PB_Any, file$)
    If Not file
      debugger::add("mods::exportListHTML() - ERROR: cannot create file {"+file$+"}")
      ProcedureReturn #False
    EndIf
    
    WriteStringN(file, "<!DOCTYPE html>", #PB_UTF8)
    WriteString(file, "<html>", #PB_UTF8)
    WriteString(file, "<head><meta charset='utf-8' /><meta name='Author' content='TFMM' /><title>TFMM Modification List Export</title><style>", #PB_UTF8)
    WriteString(file, "h1 {color: #fff; text-align: center; width: 100%; margin: 5px 0px; padding: 10px; background: #831555} "+
                      "table {width: 60%; min-width: 640px; background: #fff; padding: 0px; margin: 5px auto; border-collapse: collapse; border-spacing: 0px; border: 1px solid; border-color: RGBA(0, 0, 0, .2); box-shadow: 3px 3px 3px RGBA(0, 0, 0, .2); } "+
                      "td { padding: 5px; text-align: left; vertical-align: middle; border: none; } "+
                      "th { padding: 5px; text-align: center; vertical-align: moddle; border: none; font-weight: bold; font-size: 1.1em; border: none;background: #413e39; color: #fff } "+
                      "tr {border: none;} "+
                      "table tr:Not(:last-child) { border-style: solid; border-width: 0px 0px 1px 0px; border-color: RGBA(0, 0, 0, .2); } "+
                      "table > tr:first-child > th { } "+
                      "table tr:nth-child(even) td, table tr:nth-child(even) th { background: RGBA(0, 0, 0, .04); } "+
                      "table tr:hover td { background: RGBA(0, 0, 0, .06) !important; } "+
                      "footer { width: 100%; margin: 20px 0px; padding: 5px; border-top: 1px solid #413e39; text-align: right; font-size: small; color: rgba(65,62,57,.5); transition: color .5s ease-in-out } "+
                      "footer:hover { color: #413e39; } "+
                      "footer article { width: 60%; min-width: 640px; margin: 0px auto; padding: 0px; } "+
                      "a { color: inherit; } "+
                      "a:hover { color: #831555; } "+
                      "", #PB_UTF8)
    WriteString(file, "</style></head>", #PB_UTF8)
    WriteString(file, "<body><h1>", #PB_UTF8)
    If all
      WriteString(file, "List of Modifications", #PB_UTF8)
    Else
      WriteString(file, "List of Activated Modifications", #PB_UTF8)
    EndIf
    WriteString(file, "</h1><table><tr><th>Modification</th><th>Version</th><th>Author</th></tr>", #PB_UTF8)
    
    ForEach *mods()
      *modinfo = *mods()
      With *modinfo
        If all Or \aux\active
          name$ = \name$
          authors$ = ""
          
          If \url$
            name$ = "<a href='"+ \url$ + "'>" + name$ + "</a>"
          ElseIf \tfnetId
            name$ = "<a href='http://www.train-fever.net/filebase/index.php/Entry/" + \tfnetId + "'>" + name$ + "</a>"
          EndIf
          
          ForEach \authors()
            author$ = \authors()\name$
            If \authors()\tfnetId
              author$ = "<a href='http://www.train-fever.net/index.php/User/" + \authors()\tfnetId + "'>" + author$ + "</a>"
            EndIf
            authors$ + author$ + ", "
          Next
          If Len(authors$) >= 2 ; cut off ", " at the end of the string
            authors$ = Mid(authors$, 1, Len(authors$) -2)
          EndIf
          
          
          WriteString(file, "<tr><td>" + name$ + "</td><td>" + \aux\version$ + "</td><td>" + authors$ + "</td></tr>", #PB_UTF8)
        EndIf
      EndWith
    Next
    
    WriteString(file, "</table>", #PB_UTF8)
    WriteString(file, "<footer><article>Created with <a href='http://goo.gl/utB3xn'>TFMM</a> "+updater::VERSION$+" &copy; 2014-"+FormatDate("%yyyy",Date())+" <a href='http://tfmm.xanos.eu/'>Alexander Nähring</a></article></footer>", #PB_UTF8)
    
    WriteString(file, "</body></html>", #PB_UTF8)
    CloseFile(file)
    
    misc::openLink(File$)
  EndProcedure
  
  Procedure exportListTXT(all, File$)
    debugger::add("mods::exportListTXT("+all+", "+file$+")")
    Protected file, i
    Protected *modinfo.mod
    
    file = CreateFile(#PB_Any, File$)
    If Not file
      debugger::add("mods::exportListTXT() - ERROR: cannot create file {"+file$+"}")
      ProcedureReturn #False
    EndIf
    
    ForEach *mods()
      *modinfo = *mods()
      With *modinfo
        If all Or \aux\active
          WriteStringN(file, \name$ + Chr(9) + "v" + \aux\version$ + Chr(9) + \aux\authors$, #PB_UTF8)
        EndIf
      EndWith
    Next
    WriteStringN(file, "", #PB_UTF8)
    WriteString(file, "Created with TFMM "+updater::VERSION$, #PB_UTF8)
    CloseFile(file)
    
    misc::openLink(File$)
  EndProcedure
  
  Procedure convertToTGA(imageFile$)
    debugger::add("mods::convertToTGA("+imageFile$+")")
    Protected im, i
    Protected dir$, image$
    dir$  = misc::Path(GetPathPart(imageFile$))
    im    = LoadImage(#PB_Any, image$)
    If IsImage(im)
      ; im = misc::ResizeCenterImage(im, 320, 180)
      i = 0
      Repeat
        image$ = dir$ + "image_" + RSet(Str(i) , 2, "0") + ".tga"
        i + 1
      Until FileSize(image$) <= 0
      misc::encodeTGA(im, image$, 24)
      FreeImage(im)
      
      If FileSize(image$) > 0
        ProcedureReturn #True
      EndIf
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure.s findArchive(path$)
    Protected dir, entry$
    debugger::add("mods::findArchive("+path$+")")
    
    path$ = misc::path(path$)
    dir = ExamineDirectory(#PB_Any, path$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_Directory
          Continue
        EndIf
        Select LCase(GetExtensionPart(DirectoryEntryName(dir)))
          Case "zip"
            entry$ = DirectoryEntryName(dir)
            Break
          Case "rar"
            entry$ = DirectoryEntryName(dir)
            Break
          Case "tfmod"
            entry$ = DirectoryEntryName(dir)
            Break
          Default
            Continue
        EndSelect
      Wend
      FinishDirectory(dir)
    Else
      debugger::add("          ERROR: cannot examine "+path$)
    EndIf
    If entry$
      debugger::add("          -> "+entry$)
    EndIf
    ProcedureReturn entry$
  EndProcedure
  
  
  
  Procedure displayDLCs_callback()
    windowMain::displayDLCs(*mods())
  EndProcedure
  
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure registerMainWindow(window)
    debugger::Add("registerMainWindow("+Str(window)+")")
    _window = window
    ProcedureReturn window
  EndProcedure
  
  Procedure registerModGadget(gadget) ; ListIcon Gadget
    debugger::Add("registerModGadget("+Str(gadget)+")")
    _gadgetMod = gadget
    ProcedureReturn gadget
  EndProcedure
  
  Procedure registerDLCGadget(gadget) ; ScrollArea Gadget
    debugger::Add("registerDLCGadget("+Str(gadget)+")")
    If Not IsWindow(_window)
      debugger::add("          ERROR: window not valid or not registered")
      ProcedureReturn #False
    EndIf
    
    _gadgetDLC = gadget
    
    ; new gadgets can only be added to the scrollarea from main thread
    ; as workaround, do not call "displayDLCs" directly but register an event to an invisible gadget
    If Not _gadgetEventTriggerDLC Or Not IsGadget(_gadgetEventTriggerDLC)
      UseGadgetList(WindowID(_window))
      _gadgetEventTriggerDLC = ButtonGadget(#PB_Any, 0, 0, 0, 0, "")
      HideGadget(_gadgetEventTriggerDLC, #True)
      BindGadgetEvent(_gadgetEventTriggerDLC, @displayDLCs_callback())
    EndIf
    ProcedureReturn gadget
  EndProcedure
  
  Procedure init() ; allocate mod structure
    Protected *mod.mod
    *mod = AllocateStructure(mod)
    debugger::Add("mods::initMod() - new mod: {"+Str(*mod)+"}")
    ProcedureReturn *mod
  EndProcedure
  
  Procedure free(id$) ; delete mod from map and free memory
;     debugger::Add("mods::freeMod("+id$+")")
    Protected *mod.mod
    If FindMapElement(*mods(), id$)
      *mod = *mods()
      DeleteMapElement(*mods())
      FreeStructure(*mod)
      ProcedureReturn #True
    EndIf
    
    debugger::Add("mods::freeMod() - ERROR: could not find mod {"+id$+"} in List")
    ProcedureReturn #False
  EndProcedure
  
  Procedure freeAll()
    debugger::Add("mods::freeAll()")
    ForEach *mods()
      mods::free(*mods()\tf_id$)
    Next
    displayMods()
  EndProcedure
  
  Procedure new(*data.queue::dat) ; INITIAL STEP: add new mod file from any location
    Protected file$ = *data\string$
    debugger::Add("mods::new("+file$+")")
    Protected *mod.mod, id$
    Protected TF$ = main::TF$
    
    queue::progressText(locale::l("progress","new"))
    queue::progressVal(0, 5)
    
    ; allocate memory for mod information
    *mod = init()
    debugger::Add("mods::new() - memory adress of new mod: {"+*mod+"}")
    
    ; open archive (with password check)
    ; openArchive(*mod, file$)
    
    ; first step: check mod
    id$ = CheckModFile(file$, *mod) ; for all archive related functions *mod is passed in order to handle password
    If id$ = "false"
      debugger::Add("mods::new() - ERROR: check failed, abort")
      FreeStructure(*mod)
      ProcedureReturn #False
    EndIf
    queue::progressVal(1, 5)
    
    ; second step: read information
    If Not getInfo(file$, *mod, id$)
      debugger::Add("mods::new() - ERROR: failed to retrieve info")
      FreeStructure(*mod)
      ProcedureReturn #False
    EndIf
    ; at this point, ID is valid and will not change
    *mod\aux\installDate = Date()
    queue::progressVal(2, 5)
    
    
    ; third step: check if mod with same ID already installed
    Protected sameHash.b = #False, sameID.b = #False
    ForEach *mods()
      If *mod\archive\md5$ And *mods()\archive\md5$ = *mod\archive\md5$
        debugger::Add("mods::new() - MD5 check found match!")
        id$ = *mods()\tf_id$
        sameHash = #True
        Break
      EndIf
    Next
    
    If sameHash
      Protected NewMap strings$()
      ClearMap(strings$())
      strings$("name") = *mods(id$)\name$
      If *mods()\aux\active
        MessageRequester(locale::l("main","install"), locale::getEx("management","conflict_hash",strings$()), #PB_MessageRequester_Ok)
        debugger::Add("mods::new() - cancel new installation, mod already installed")
        ;- TODO: maybe ask, if user wants to reinstall (reload archive file)
      Else
        debugger::Add("mods::new() - trigger install of previous mod")
        queue::add(queue::#QueueActionInstall, id$)
      EndIf
      FreeStructure(*mod)
      ProcedureReturn #True
    EndIf
    
    If FindMapElement(*mods(), *mod\tf_id$)
      debugger::Add("mods::new() - Another mod with id {"+id$+"} already in list!")
      id$ = *mod\tf_id$
      sameID = #True
    EndIf
    
    If sameID
      Protected NewMap strings$()
      ClearMap(strings$())
      strings$("id") = *mod\tf_id$
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
        queue::add(queue::#QueueActionRemove, *mod\tf_id$) ; remove from TF if present
        queue::add(queue::#QueueActionDelete, *mod\tf_id$) ; delete from library
        queue::add(queue::#QueueActionNew, file$) ; re-schedule this mod
        FreeStructure(*mod)
        ProcedureReturn #True
      EndIf
    EndIf
    queue::progressVal(3, 5)
    
    ; fourth step: copy mod to internal TFMM mod folder and extract all recognised information files
    queue::progressText(locale::l("progress","copy_lib"))
    id$ = *mod\tf_id$
    Protected dir$ = misc::Path(TF$+"/TFMM/library/"+id$)
    debugger::Add("mods::new() - add mod to library: {"+dir$+"}")
    ; create library entry (subdir)
    If Not misc::CreateDirectoryAll(dir$)
      debugger::Add("mods::new() - ERROR - failed to create {"+dir$+"}")
      FreeStructure(*mod)
      ProcedureReturn #False
    EndIf
    
    ; copy file to library
    ;     Protected newfile$ = dir$ + id$ + "." + LCase(GetExtensionPart(file$))
    ;- TODO - decide to change filename and extension or leave it as original
    Protected newfile$ = dir$ + *mod\archive\name$
    debugger::Add("mods::new() - copy file to library: {"+file$+"} -> {"+newfile$+"}")
    
    If Not CopyFile(file$, newfile$)
      debugger::Add("mods::new() - ERROR - failed to copy file {"+file$+"} -> {"+dir$+GetFilePart(file$)+"}")
      FreeStructure(*mod)
      ProcedureReturn #False
    EndIf
    queue::progressVal(4, 5)
    
    ; extract files
    Protected NewList files$()
    Protected i
    ClearList(files$())
    AddElement(files$()) : files$() = "header.jpg"
    AddElement(files$()) : files$() = "preview.png"
    For i = 0 To 9
      AddElement(files$()) : files$() = "image_0" + i + ".tga"
    Next
    If Not ExtractFilesZip(newfile$, files$(), dir$)
      If Not ExtractFilesRar(newfile$, files$(), dir$, *mod)
        debugger::Add("mods::GetModInfo() - failed to open {"+newfile$+"} for extraction")
      EndIf
    EndIf
    
    ; images
    debugger::Add("mosd::new() - convert images")
    Protected image$
    ; make sure at least the "image_00.tga" is in the library
    image$ = dir$ + "preview.png"
    If FileSize(image$) > 0
      convertToTGA(image$) ; convert the file to the first "free" image_xx.tga
      DeleteFile(image$)
    EndIf
    image$ = dir$ + "header.jpg"
    If FileSize(image$) > 0
      convertToTGA(image$)
      DeleteFile(image$)
    EndIf
    
    ; fifth step: update lists
    addToMap(*mod)
    displayMods()
    displayDLCs()
    queue::progressVal(5, 5)
    
    ; changed = #True
    
    ; last step: init install
    queue::add(queue::#QueueActionInstall, id$)
    ProcedureReturn #True
  EndProcedure
  
  Procedure loadList(*dummy) ; TF$) ; load all mods in internal modding folder and installed to TF
    Protected TF$ = main::TF$
    debugger::Add("mods::loadList("+TF$+")")
    
    Protected pMods$, pDLCs$, pTFMM$, pLib$, pTMP$
    Protected json, NewMap mods_json.mod(), *mod.mod
    Protected dir, entry$, NewMap mod_scanner.mod_scanner()
    Protected count, n, id$, modFolder$, luaFile$
    
    pTFMM$  = misc::Path(TF$ + "/TFMM/")
    pLib$   = misc::Path(TF$ + "/TFMM/library/")
    pMods$  = misc::Path(TF$ + "/mods/")
    pDLCs$  = misc::Path(TF$ + "/dlcs/")
    ; pTMP$   = GetTemporaryDirectory()
    
    queue::progressText(locale::l("progress","load"))
    queue::progressVal(0, 1) ; 0% progress
    
    ; load list from json file
    json = LoadJSON(#PB_Any, pTFMM$ + "mods.json")
    If json
      ExtractJSONMap(JSONValue(json), mods_json())
      FreeJSON(json)
      
      ForEach mods_json()
        *mod = init()
        CopyStructure(mods_json(), *mod, mod)
        If Not *mod\aux\installDate
          *mod\aux\installDate = Date()
        EndIf
        *mods(MapKey(mods_json())) = *mod
      Next
      debugger::Add("mods::loadList() - loaded "+MapSize(mods_json())+" mods from mods.json")
      FreeMap(mods_json())
    EndIf
    
    ; *mods() map now contains all mods that where known to TFMM at last program exit
    ; check for new mods and check if mod info has changed since last parsing of info.lua
    
    ; scan Train Fever/mods/ and TFMM/library folders
    ClearMap(mod_scanner())
    
    debugger::Add("mods::loadList() - scan mods folder {"+pMods$+"}")
    dir = ExamineDirectory(#PB_Any, pMods$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If checkID(entry$)
          mod_scanner(entry$)\folderMods = #True
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    debugger::Add("mods::loadList() - scan dlcs folder {"+pDLCs$+"}")
    dir = ExamineDirectory(#PB_Any, pDLCs$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If checkID(entry$)
          mod_scanner(entry$)\folderDLCs = #True
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    debugger::Add("mods::loadList() - scan library folder {"+pLib$+"}")
    dir = ExamineDirectory(#PB_Any, pLib$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If checkID(entry$)
          mod_scanner(entry$)\folderLibrary = #True
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ; check if a mod is in json file, that does not exist in one of the folders
    ; if mod is NOT found in any folder: delete!
    ; if mod is found in one of the folders, the corresponding flags will be updates (active, inLibrary)
    ; e.g.: mod only found in library: set lib flag to true (and automatically active flag to false)
    ;- TODO - currently, only "new modding system" is used. with "old" system, installed mods do not have to be in "mods/" folder
    ForEach *mods()
      If Not FindMapElement(mod_scanner(), MapKey(*mods()))
        debugger::add("mods::loadList() - WARNING: {"+MapKey(*mods())+"} in json but not in folders")
        free(MapKey(*mods()))
      EndIf
    Next
    
    ; Load installed modifications from Train Fever/mods/ folder
    count = MapSize(mod_scanner())
    n = 0
    debugger::Add("mods::loadList() - found "+MapSize(mod_scanner())+" mods in folders")
    If count > 0
      queue::progressVal(0, count)
      
      ForEach mod_scanner()
        n + 1 ; update progress bar
        queue::progressVal(n)
        
        id$ = MapKey(mod_scanner())
        debugger::Add("mods::loadList() - scanner: {"+id$+"}")
        
        If Not FindMapElement(*mods(), id$)
          debugger::add("mods::loadList() - Found mod {"+id$+"} in folders, add new mod")
          ; if not already in map, create new mod and insert into map
          *mod = init()
          *mods(id$) = *mod
        EndIf
        
        If Not FindMapElement(*mods(), id$)
          ; this should never be reached
          debugger::add("mods::loadList() - CRITICAL ERROR: failed to add mod to map")
          Continue
        EndIf
        
        ; set pointer to current element in mod map
        *mod = *mods(id$)
        *mod\tf_id$ = id$ ; IMPORTANT
        
        
;         debugger::add("mods::loadList() - \folderLibrary = " + mod_scanner()\folderLibrary +
;                       ", \folderMods = " + mod_scanner()\folderMods +
;                       ", \folderDLCs = " + mod_scanner()\folderDLCs)
        ; analogue for library
        *mod\aux\inLibrary = mod_scanner()\folderLibrary
        ; mark mod as active if found in mods/ folder
        *mod\aux\active = Bool(mod_scanner()\folderMods Or mod_scanner()\folderDLCs)
        If mod_scanner()\folderDLCs
          *mod\isDLC = #True
        EndIf
        
        ; handle stuff for installed mods / dlcs
        If *mod\aux\active
;           debugger::add("mods::loadList() - mod is active (installed)")
          
          If *mod\isDLC
            modFolder$ = misc::Path(pDLCs$+id$+"/")
          Else
            modFolder$ = misc::Path(pMods$+id$+"/")
          EndIf
          luaFile$ = modFolder$ + "info.lua"
          
          ; check if info.lua was modified and reload info.lua if required
          ; will also trigger, if no info is stored until now (luaDate = 0)
          If *mod\name$ = "" Or *mod\aux\luaDate < GetFileDate(luaFile$, #PB_Date_Modified)
            debugger::add("mods::loadList() - reload information now")
            ; load info from info.lua
            If FileSize(luaFile$) > 0
              debugger::add("mods::loadList() - reload info.lua for {"+id$+"}")
              If Not parseInfoLUA(luaFile$, *mod)
                debugger::add("mods::loadList() - ERROR: failed to parse info.lua")
              EndIf
            Else
              ; no info.lua present -> extract info from ID
              debugger::add("mods::loadList() - ERROR: no info.lua for mod '"+id$+"' found!")
            EndIf
            infoPP(*mod) ; IMPORTANT
            
            If *mod\name$ = ""
              debugger::add("mods::loadList() - CRITICAL ERROR!")
              debugger::add("                 - Loading name from active mod '"+id$+"'failed {"+*mod+"}")
            EndIf
          EndIf
          
          ; after loading: write back info.lua if not present
          Protected file
          If FileSize(luaFile$) <= 0
            file = CreateFile(#PB_Any, luaFile$)
            If file
              WriteString(file, getLUA(*mod), #PB_UTF8)
              CloseFile(file)
              *mod\aux\luaDate = GetFileDate(luaFile$, #PB_Date_Modified)
            EndIf
          EndIf
          
          ; no need to load images, is handled dynamically if mod is selected
          
        EndIf ; active
        
        ; handle stuff for mods in library
        If *mod\aux\inLibrary
;           debugger::add("mods::loadList() - mod is in TFMM library")
          modFolder$  = misc::Path(pLib$ + id$)
          ; file name was stored as "id.tfmod" with complete path for older versions
          ; now, only store "filename" without path and filename = original name
          If *mod\archive\name$ = ""
            debugger::add("          ERROR: no filename known for archive in library, try to find zip or rar file")
            *mod\archive\name$ = findArchive(misc::Path(pLib$ + id$ + "/"))
            If *mod\archive\name$
              debugger::add("          Archivename found and stored")
            Else
              Protected file$ = misc::Path(pLib$ + id$ + "/") + id$ + ".tfmod"
              If FileSize(file$)
                *mod\archive\name$ = id$ + ".tfmod"
              EndIf
            EndIf
          EndIf
          
          If *mod\archive\md5$ = "" And FileSize(misc::Path(pLib$+id$+"/") + *mod\archive\name$) > 0
            *mod\archive\md5$ = FileFingerprint(misc::Path(pLib$+id$+"/") + *mod\archive\name$, #PB_Cipher_MD5)
          EndIf
          
          ; info should be stored in mods.json when file is in library
          ; if not? -> load again from mod file
          If *mod\name$ = "" Or Not *mod\aux\luaDate
            getInfo(modFolder$ + *mod\archive\name$, *mod, id$)
          EndIf
        Else
          ; If mod is not saved in library, no filename is required.
          ; filename may be present from installation, if mod was installed using TFMM
        EndIf
        
        If *mod\name$ = ""
          debugger::add("mods::loadList() - CRITICAL ERROR: no name for mod {"+id$+"}")
        EndIf
        
      Next
    EndIf
    
    
    
    ; Final Check
    debugger::add("mods::loadList() - final checkup")
    ForEach *mods()
      *mod = *mods()
      If *mod\tf_id$ = "" Or MapKey(*mods()) = ""
        debugger::add("mods::loadList() - CRITICAL ERROR: mod without ID in list: key={"+MapKey(*mods())+"} tf_id$={"+*mod\tf_id$+"}")
        End
      EndIf
    Next
    
    debugger::add("mods::loadList() - finished")
    ; Display mods in list gadget
    displayMods()
    displayDLCs()
    
  EndProcedure
  
  Procedure saveList()
    Protected TF$ = main::TF$
    debugger::add("mods::saveList("+TF$+")")
    
    If TF$ = ""
      debugger::add("mods::saveList() - ERROR: TF$ not defined")
      ProcedureReturn #False
    EndIf
    
    Protected NewMap mods_tmp.mod()
    ForEach *mods()
      CopyStructure(*mods(), mods_tmp(MapKey(*mods())), mod)
    Next
    
    Protected pTFMM$
    pTFMM$  = misc::Path(TF$ + "/TFMM/")
    If FileSize(pTFMM$) <> -2
      misc::CreateDirectoryAll(pTFMM$)
    EndIf
    
    Protected json
    json = CreateJSON(#PB_Any)
    InsertJSONMap(JSONValue(json), mods_tmp())
    SaveJSON(json, pTFMM$ + "mods.json", #PB_JSON_PrettyPrint)
    FreeJSON(json)
    
    FreeMap(mods_tmp())
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure convert(*dummy)
    Protected TF$ = main::TF$
    Protected Backup$
    debugger::Add("mods::convert("+TF$+")")
    
    Protected file$, name$
    Protected NewList mods$(), NewMap files$()
    Protected i
    debugger::Add("mods::convert() - load mods.ini")
    
    ; delete filetracker files (essentially uninstalling old mods)
    OpenPreferences(misc::Path(TF$ + "/TFMM/") + "filetracker.ini")
    ClearMap(files$())
    If ExaminePreferenceGroups()
      While NextPreferenceGroup()
        If ExaminePreferenceKeys()
          While NextPreferenceKey()
            ; save pairs of filenames and md5 fingerprints
            files$(PreferenceKeyName()) = PreferenceKeyValue()
          Wend
        EndIf
      Wend
    EndIf
    ClosePreferences()
    i = 0
    queue::progressVal(0, MapSize(files$()))
    ForEach files$()
      file$ = MapKey(files$())
      If FileFingerprint(TF$ + file$, #PB_Cipher_MD5) = files$()
        debugger::Add("mods::convert() - delete. {"+file$+"}")
        DeleteFile(TF$ + file$, #PB_FileSystem_Force)
        
        ; restore backup if any
        Backup$ = misc::Path(TF$ + "TFMM/Backup/")
        If FileSize(Backup$ + file$) >= 0
          debugger::Add("mods::convert() - restore backup: {"+file$+"}")
          RenameFile(Backup$ + file$, TF$ + file$)
          DeleteFile(Backup$ + file$, #PB_FileSystem_Force)
        EndIf
        
        i + 1
        queue::progressVal(i)
      Else
        debugger::Add("mods::convert() - fingerprint mismatch {"+file$+"}")
      EndIf
    Next
    
    
    
    ; add mods with new modding system
    OpenPreferences(misc::Path(TF$ + "/TFMM/") + "mods.ini")
    If ExaminePreferenceGroups()
      While NextPreferenceGroup()
        file$ = ReadPreferenceString("file", "")
        name$ = PreferenceGroupName() ; = ReadPreferenceString("name", "")
        If file$ And name$
          debugger::Add("mods::convert() - found {"+name$+"}: {"+file$+"}")
          AddElement(mods$())
          mods$() = misc::path(TF$ + "TFMM/Mods/") + file$
        EndIf
      Wend
    EndIf
    ClosePreferences()
    
    i = 0
    queue::progressVal(0, ListSize(mods$()))
    ForEach mods$()
      queue::progressText("Process '"+mods$()+"'")
      
      Protected newMod.queue::dat\string$ = mods$()
      new(newMod)
        
      queue::progressVal(i)
      i + 1
    Next
    
    
    
    ; delete files and folders
    DeleteFile(misc::Path(TF$ + "/TFMM/") + "mods.ini")
    DeleteFile(misc::Path(TF$ + "/TFMM/") + "filetracker.ini")
    DeleteFile(misc::Path(TF$ + "/TFMM/") + "mod-dependencies.ini")
    DeleteDirectory(misc::path(TF$ + "TFMM/Mods/"), "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    DeleteDirectory(misc::path(TF$ + "TFMM/Backup/"), "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure install(*data.queue::dat)
    debugger::Add("mods::install("+Str(*data)+")")
    Protected TF$, id$
    id$ = *data\string$
    tf$ = main::TF$
    
    debugger::Add("mods::install() - mod {"+id$+"}")
    
    Protected *mod.mod = *mods(id$)
    Protected source$, target$
    Protected i
    
    ; check prequesits
    If Not *mod
      debugger::Add("mods::install() - ERROR - cannot find mod in map")
      ProcedureReturn #False
    EndIf
    If *mod\aux\active
      debugger::Add("mods::install() - {"+id$+"} already installed")
      ProcedureReturn #False
    EndIf
    
    ; extract files
    source$ = misc::Path(tf$+"TFMM/library/"+id$+"/") + *mod\archive\name$
    target$ = misc::Path(tf$+"/mods/"+id$+"/")
    If *mod\isDLC
      target$ = misc::Path(tf$+"/dlcs/"+id$+"/")
    EndIf
    
    If FileSize(target$) = -2
      debugger::Add("mods::install() - {"+target$+"} already exists - assume already installed")
      *mod\aux\active = #True
      If *mod\isDLC
        displayDLCs()
      Else
        displayMods()
        ;- TODO Image Update: Check if easier way to only update images (new procedure: updateActiveIcons() just crawls through list and sets image ID)
        If IsGadget(_gadgetMod)
          For i = 0 To CountGadgetItems(_gadgetMod) -1
            If ListIcon::GetListItemData(_gadgetMod, i) = *mod
              ListIcon::SetListItemImage(_gadgetMod, i, ImageID(images::Images("yes")))
              Break
            EndIf
          Next
        EndIf
      EndIf
      ProcedureReturn #True
    EndIf
    misc::CreateDirectoryAll(target$)
    
    ;- TODO: make "overwrite lua with TFMM information" optional, write info from TFMM as lua to mods/ (if it is a mod)
    If Not extractZIP(source$, target$)
      If Not extractRAR(source$, target$, *mod)
        debugger::Add("mods::install() - ERROR - failed to extract files")
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        ProcedureReturn #False
      EndIf
    EndIf
    
    
    ; special case: copy files to res?
    ; required for nordic dlc shaders
    Protected backups$
    If *mod\tf_id$ = "nordic_1" And *mod\isDLC
      debugger::Add("mods::install() - ATTENTION: overwrite original shaders")
      OpenPreferences(misc::path(main::TF$ + "TFMM") + "files.list")
      PreferenceGroup("nordic_1")
      UseMD5Fingerprint()
      backups$ = misc::path(main::TF$ + "TFMM/backups/")
      Protected NewList files$()
      misc::examineDirectoryRecusrive(misc::path(target$ + "/res/shaders/"), files$())
      ForEach files$()
        files$() = misc::path("/res/shaders/") + files$() ; only scanned the res/shaders folder, add path manually
        debugger::add("          copy shader file: "+files$())
        Debug "res: " + main::TF$ + files$()
        Debug "bak: " + backups$ + files$()
        Debug "dlc: " + target$ + files$()
        If FileSize(main::TF$ + files$()) > 0
          ; file exists in res, backup first
          If FileSize(backups$ + files$()) > 0
            ; backup exists, do NOT backup again
          Else
            ; no backup there yet, backup original file
            misc::CreateDirectoryAll(GetPathPart(backups$ + files$()))
            If Not CopyFile(main::TF$ + files$(), backups$ + files$())
              debugger::add("          ERROR: cannot backup shader file: "+files$())
            EndIf
          EndIf
        Else
          ; file not present in res
        EndIf
        ; now copy file from dlc to res:
        misc::CreateDirectoryAll(GetPathPart(main::TF$ + files$()))
        CopyFile(target$ + files$(), main::TF$ + files$())
        WritePreferenceString(files$(), FileFingerprint(main::TF$ + files$(), #PB_Cipher_MD5))
      Next
      ClosePreferences()
    EndIf
    
    ; copy images
    If FileSize(target$ + "image_00.tga") <= 0
      debugger::Add("mods::install() - copy images")
      CopyFile(GetPathPart(source$) + "image_00.tga", target$ + "image_00.tga")
    EndIf
    
    
    ;- TODO change this
    ; these files are not longer extracted automatically
    ; just extract files from zip and/or generate lua file manually
    ; same issue: handle multilanguage in lua -> create strings.lua and internally save all strings in a language map:
    ; map: strings.info() with info strucutre containing e.g. "name", "description", etc...
;     CopyFile(source$ + "info.lua", target$ + "info.lua")
;     CopyFile(source$ + "strings.lua", target$ + "strings.lua")
;     CopyFile(source$ + "filesystem.lua", target$ + "filesystem.lua")
;     CopyFile(source$ + "main.lua", target$ + "main.lua")
    
    ; finish installation
    debugger::Add("mods::install() - finish installation...")
    *mod\aux\active = #True
    ;- TODO Image Update
    If *mod\isDLC
      displayDLCs()
    Else
      If IsGadget(_gadgetMod)
        For i = 0 To CountGadgetItems(_gadgetMod) -1
          If ListIcon::GetListItemData(_gadgetMod, i) = *mod
            ListIcon::SetListItemImage(_gadgetMod, i, ImageID(images::Images("yes")))
            Break
          EndIf
        Next
      EndIf
    EndIf
    
    debugger::Add("mods::install() - finished")
    ProcedureReturn #True
  EndProcedure
  
  Procedure remove(*data.queue::dat) ; remove from Train Fever Mod folder (not library)
    debugger::Add("mods::remove("+Str(*data)+")")
    Protected TF$, id$
    id$ = *data\string$
    TF$ = main::TF$
    
    
    debugger::Add("mods::remove() - mod {"+id$+"}")
    
    Protected *mod.mod = *mods(id$)
    Protected targetDir$
    Protected i
    
    If Not *mod
      ProcedureReturn #True
    EndIf
    
    If *mod\aux\active And Not *mod\aux\inLibrary
      ;- TODO backup mod
    EndIf
    
    ; check prequesits
    If Not *mod
      debugger::Add("mods::remove() - ERROR - cannot find mod in map")
      ProcedureReturn #False
    EndIf
    If Not *mod\aux\active
      debugger::Add("mods::remove() - ERROR - {"+id$+"} not installed")
      ProcedureReturn #False
    EndIf
    
    ; delete folder
    If *mod\isDLC
      If *mod\tf_id$ = "usa_1"
        debugger::Add("mods::remove() - ERROR - cannot remove usa_1 DLC")
        ProcedureReturn #False
      EndIf
      targetDir$ = misc::Path(tf$+"/dlcs/"+id$+"/")
    Else
      targetDir$ = misc::Path(tf$+"/mods/"+id$+"/")
    EndIf
    
    debugger::add("mods::remove() - delete {"+targetDir$+"} and all subfolders")
    DeleteDirectory(targetDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    
    ; special: if res folder files have been replaced: restore backup
    OpenPreferences(misc::path(main::TF$ + "TFMM") + "files.list")
    If PreferenceGroup(*mod\tf_id$)
      Protected file$, backups$
      backups$ = misc::path(main::TF$ + "TFMM/backups/")
      ExaminePreferenceKeys()
      While NextPreferenceKey()
        file$ = PreferenceKeyName()
        If FileFingerprint(main::TF$ + file$, #PB_Cipher_MD5) = PreferenceKeyValue()
          ; check if backup present
          If FileSize(backups$ + file$) > 0
            ; backup file present
            debugger::add("          restore backup file: "+file$)
            DeleteFile(main::TF$ + file$)
            RenameFile(backups$ + file$, main::TF$ + file$)
          Else
            ; no backup file found!
            debugger::add("          delete file (without backup): "+file$)
            DeleteFile(main::TF$ + file$)
          EndIf
        Else
          ; fingerprint different -> file has been changed since install, do NOT overwrite with backup!
          debugger::add("          WARNING: fingerprint missmatch, do not touch: "+file$)
        EndIf
      Wend
    EndIf
    RemovePreferenceGroup(*mod\tf_id$)
    ClosePreferences()
    
    ; finish removal
    
    *mod\aux\active = #False
    ;- TODO Image Update
    If IsGadget(_gadgetMod)
      For i = 0 To CountGadgetItems(_gadgetMod) -1
        If ListIcon::GetListItemData(_gadgetMod, i) = *mod
          ListIcon::SetListItemImage(_gadgetMod, i, ImageID(images::Images("no")))
          Break
        EndIf
      Next
    EndIf
    
    If *mod\aux\active And Not *mod\aux\inLibrary
      ; delete mod from list, as it is not in library anymore
      delete(*data)
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure delete(*data.queue::dat) ; delete mod completely from TF and TFMM
    debugger::Add("mods::delete("+Str(*data)+")")
    Protected TF$, id$
    id$ = *data\string$
    TF$ = main::TF$
    
    debugger::Add("mods::delete() - mod {"+id$+"}")
    
    Protected *mod.mod = *mods(id$)
    Protected targetDir$
    Protected i
    
    ; check prequesits
    If Not *mod
      debugger::Add("mods::delete() - ERROR - cannot find mod in map")
      ProcedureReturn #False
    EndIf
    If *mod\aux\active
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
    ;- TODO List Update
    If IsGadget(_gadgetMod)
      For i = 0 To CountGadgetItems(_gadgetMod) -1
        If ListIcon::GetListItemData(_gadgetMod, i) = *mod
          ListIcon::RemoveListItem(_gadgetMod, i)
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
    
    Static RegExpNonAlphaNum
    If Not RegExpNonAlphaNum
      RegExpNonAlphaNum  = CreateRegularExpression(#PB_Any, "[^a-z0-9]") ; non-alphanumeric characters
      ; regexp matches all non alphanum characters including spaces etc.
    EndIf
    
    With *mod
      If id$
        debugger::Add("mods::generateID() - passed through id = {"+id$+"}")
        ; this id$ is passed through, extracted from subfolder name
        ; if it is present, check if it is well-defined
        If checkID(id$)
          debugger::Add("mods::generateID() - {"+id$+"} is a valid ID")
          \tf_id$ = id$
          ; id read from mod folder was valid, thus use it directly
          ProcedureReturn #True
        Else
          debugger::Add("mods::generateID() - {"+id$+"} is no valid ID - generate new ID")
        EndIf
      Else
        debugger::Add("mods::generateID() - no ID defined - generate new ID")
      EndIf
      
      
      ; if no id$ was passed through or id was invalid, generate new ID
      
      \tf_id$ = LCase(\tf_id$)
      
      ; Check if ID already correct
      If \tf_id$ And checkID(\tf_id$)
        debugger::Add("mods::generateID() - ID {"+\tf_id$+"} is well defined (from structure)")
        ProcedureReturn #True
      EndIf
      
      ; Check if ID in old format
      author$   = StringField(\tf_id$, 1, ".")
      name$     = StringField(\tf_id$, CountString(\tf_id$, ".")+1, ".")
      version$  = Str(Abs(Val(StringField(\aux\version$, 1, "."))))
      \tf_id$ = author$ + "_" + name$ + "_" + version$
      
      If \tf_id$ And checkID(\tf_id$)
        debugger::Add("mods::generateID() - ID {"+\tf_id$+"} is well defined (converted from old TFMM-id)")
        ProcedureReturn #True
      EndIf
      
      \tf_id$ = ""
      
      debugger::Add("mods::generateID() - generate new ID")
      ; ID = author_mod_version
      If ListSize(\authors()) > 0
        LastElement(\authors())
        author$ = ReplaceRegularExpression(RegExpNonAlphaNum, LCase(\authors()\name$), "") ; remove all non alphanum + make lowercase
      Else
        author$ = ""
      EndIf
      If author$ = ""
        author$ = "unknownauthor"
      EndIf
      name$ = ReplaceRegularExpression(RegExpNonAlphaNum, LCase(\name$), "") ; remove all non alphanum + make lowercase
      If name$ = ""
        name$ = "unknown"
      EndIf
      version$ = Str(Val(StringField(\aux\version$, 1, "."))) ; first part of version string concatenated by "." as numeric value
      
      \tf_id$ = author$ + "_" + name$ + "_" + version$ ; concatenate id parts
      
      If \tf_id$ And checkID(\tf_id$)
        debugger::Add("mods::generateID() - ID {"+\tf_id$+"} is well defined (generated by TFMM)")
        ProcedureReturn #True
      EndIf
    EndWith
    
    debugger::Add("mods::generateID() - ERROR: No ID generated")
    ProcedureReturn #False
  EndProcedure
  
  Procedure.s getLUA(*mod.mod)
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
      ForEach \authors()
        Select UCase(\authors()\role$)
          Case "CREATOR"
            \authors()\role$ = "CREATOR"
          Case "CO_CREATOR"
            \authors()\role$ = "CO_CREATOR"
          Case "TESTER"
            \authors()\role$ = "TESTER"
          Case "BASED_ON"
            \authors()\role$ = "BASED_ON"
          Case "OTHER"
            \authors()\role$ = "OTHER"
          Default
            \authors()\role$ = "CREATOR"
        EndSelect
      Next
      
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
                "      role = "+#DQUOTE$+""+\authors()\role$+""+#DQUOTE$+"," + #CRLF$ +
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
    
;     *mod\aux\lua$ = lua$
    ProcedureReturn lua$
  EndProcedure
  
  Procedure exportList(all=#False)
    debugger::Add("Export Mod List")
    Protected file$, selectedExt$, ext$
    Protected ok = #False
    
    file$ = SaveFileRequester(locale::l("management", "export_list"), "mods", "HTML|*.html|Plain Text|*.txt", 0)
    If file$ = ""
      ProcedureReturn #False
    EndIf
    
    ; get selected file pattern (from dropdown in save file dialog)
    Select SelectedFilePattern()
      Case 0
        selectedExt$ = "html"
      Case 1
        selectedExt$ = "txt"
      Default
        selectedExt$ = "html"
    EndSelect
    
    ext$ = LCase(GetExtensionPart(file$))
    ; only if no extension is specified in filename, use extension that was selected
    If ext$ <> "html" And ext$ <> "txt"
      ext$ = selectedExt$
      file$ = GetPathPart(file$) + GetFilePart(file$, #PB_FileSystem_NoExtension) + "." + ext$
    EndIf
    
    If FileSize(file$) > 0
      If MessageRequester(locale::l("management", "export_list"), locale::l("management", "overwrite_file"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
        ok = #True
      EndIf
    Else
      ok = #True
    EndIf
    
    If Not ok
      ProcedureReturn #False
    EndIf
    
    Select LCase(GetExtensionPart(file$))
      Case "html"
        ExportListHTML(all, file$)
      Case "txt"
        ExportListTXT(all, file$)
      Default
        ProcedureReturn #False
    EndSelect
    ProcedureReturn #True
  EndProcedure
  
  Procedure displayMods(filter$="")
    Protected text$, mod_ok, tmp_ok, count, item, k, col, str$
    
    If Not IsWindow(_window)
      debugger::add("mods::displayMods() - ERROR: window not valid")
      ProcedureReturn #False
    EndIf
    If Not IsGadget(_gadgetMod)
      debugger::add("mods::displayMods() - ERROR: gadget not valid")
      ProcedureReturn #False
    EndIf
    
    windowMain::stopGUIupdate() ; do not execute "updateGUI()" timer
    misc::StopWindowUpdate(WindowID(_window)) ; do not repaint window
    HideGadget(_gadgetMod, #True)
    ListIcon::ClearListItems(_gadgetMod)
    
    count = CountString(filter$, " ") + 1
    ForEach *mods()
      With *mods()
        mod_ok = 0 ; reset ok for every mod entry
        If \isDLC
          Continue
        EndIf
        If filter$ = ""
          mod_ok = 1
          count = 1
        Else
          For k = 1 To count
            tmp_ok = 0
            str$ = Trim(StringField(filter$, k, " "))
            If str$
              ; search in author, name, tags
              If FindString(\aux\authors$, str$, 1, #PB_String_NoCase)
                tmp_ok = 1
              ElseIf FindString(\name$, str$, 1, #PB_String_NoCase)
                tmp_ok = 1
              Else
                ForEach \tags$()
                  If FindString(\tags$(), str$, 1, #PB_String_NoCase) Or 
                     FindString(locale::l("tags", LCase(\tags$())), str$, 1, #PB_String_NoCase)
                    tmp_ok = 1
                  EndIf
                Next
              EndIf
            Else
              tmp_ok = 1 ; empty search string is just ignored (ok)
            EndIf
            
            If tmp_ok
              mod_ok + 1 ; increase "ok-counter"
            EndIf
          Next
        EndIf
        If mod_ok And mod_ok = count ; all substrings have to be found (ok-counter == count of substrings)
          text$ = ""
          text$ = \name$ + #LF$ + \aux\authors$ + #LF$ + \aux\tags$ + #LF$ + \aux\version$
          
          ListIcon::AddListItem(_gadgetMod, item, text$)
          ListIcon::SetListItemData(_gadgetMod, item, *mods())
          If \aux\active
            ListIcon::SetListItemImage(_gadgetMod, item, ImageID(images::Images("yes")))
          Else
            ListIcon::SetListItemImage(_gadgetMod, item, ImageID(images::Images("no")))
          EndIf
          item + 1
        EndIf
      EndWith
    Next
    
    HideGadget(_gadgetMod, #False)
    misc::ContinueWindowUpdate(WindowID(_window))
    windowMain::stopGUIupdate(#False)
    
  EndProcedure
  
  Procedure displayDLCs()
    Protected item
    If Not IsGadget(_gadgetDLC)
      debugger::add("          ERROR: gadget not valid")
      ProcedureReturn #False
    EndIf
    If Not IsWindow(_window)
      debugger::add("          ERROR: window not valid")
      ProcedureReturn #False
    EndIf
    
    ; IMPORTANT: New gadgets can only be added inside the main thread!
    ; therefore, ensure that this procedure always calls the main thread
    ; -> Cannot check if current function is called in main thread or not
    ; therefore, just send an "event" to the main window, which is always handled in the main thread
    ; the event has to be bound to the real "displayDLCs" function, which is automatically called
    PostEvent(#PB_Event_Gadget, _window, _gadgetEventTriggerDLC)
    ProcedureReturn #True
  EndProcedure
  
  Procedure getPreviewImage(*mod.mod, original=#False)
    debugger::add("mods::getPreviewImage("+*mod+", "+original+")")
    Static NewMap previewImages()
    Static NewMap previewImagesOriginal()
    
    If Not IsImage(previewImages(*mod\tf_id$))
      ; if image is not yet loaded
      Protected im.i, image$
      If *mod\aux\active
        If *mod\isDLC
          If *mod\tf_id$ = "usa_1"
            image$ = misc::Path(main::TF$ + "res/textures/ui/scenario/") + "usa.tga"
          Else
            image$ = misc::Path(main::TF$ + "dlcs/" + *mod\tf_id$) + "image_00.tga"
          EndIf
        Else
          image$ = misc::Path(main::TF$ + "mods/" + *mod\tf_id$) + "image_00.tga"
        EndIf
        If FileSize(image$) > 0
          im = LoadImage(#PB_Any, image$)
        EndIf
      ElseIf *mod\aux\inLibrary
        ;- TODO: check filenames of images! -> compare to "new()" procedure and set standard
        ; image_00.tga should always be present
        image$ = misc::Path(main::TF$ + "TFMM/library/" + *mod\tf_id$) + "image_00.tga"
        If FileSize(image$) > 0
          im = LoadImage(#PB_Any, image$)
        Else
          ; otherwise try preview.png file
          image$ = misc::Path(main::TF$ + "TFMM/library/" + *mod\tf_id$) + "preview.png"
          If FileSize(image$) > 0
            im = LoadImage(#PB_Any, image$)
          Else
            ; no image found
            debugger::add("          ERROR: cannot find a preview image in ./TFMM/library/" + *mod\tf_id$)
          EndIf
        EndIf
      EndIf
      
      ; still not loaded -> fail
      If Not IsImage(im)
        ProcedureReturn #False
      EndIf
      
      previewImagesOriginal(*mod\tf_id$) = im
      
      ; now resize image to special size:
      ; mod images: 210x118 (original: 320x180)
      ; dlc images: 120x80
      If *mod\isDLC
        previewImages(*mod\tf_id$) = misc::ResizeCenterImage(im, 120, 80)
      Else
        previewImages(*mod\tf_id$) = misc::ResizeCenterImage(im, 210, 118)
      EndIf
    EndIf
    
    If original
      ProcedureReturn previewImagesOriginal(*mod\tf_id$)
    Else
      ProcedureReturn previewImages(*mod\tf_id$)
    EndIf
  EndProcedure
  
EndModule
