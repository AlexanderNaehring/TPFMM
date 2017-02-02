XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_unrar.pbi"
; XIncludeFile "module_parseLUA.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_queue.pbi"
XIncludeFile "module_luaParser.pbi"

XIncludeFile "module_mods.h.pbi"

Module mods
  
  Structure scanner
    type$ ; mod, dlc, map
  EndStructure
  
  Global NewMap *mods.mod()
  Global _window, _gadgetMod, _gadgetDLC, _gadgetEventTriggerDLC
  
  
  UseMD5Fingerprint()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Macro defineFolder()
    Protected pTPFMM$, pMods$, pWorkshop$, pStagingArea$, pMaps$, pDLCs$
    pTPFMM$       = misc::Path(main::gameDirectory$ + "/TPFMM/") ; only used for json file
    pMods$        = misc::Path(main::gameDirectory$ + "/mods/")
    pDLCs$        = misc::Path(main::gameDirectory$ + "/dlcs/")
    pWorkshop$    = misc::Path(main::gameDirectory$ + "/../../workshop/content/446800/") ;- TODO !!! check if this directoy is always true
    pStagingArea$ = misc::Path(main::gameDirectory$ + "/")                               ;- TODO !!!
    pMaps$        = misc::Path(main::gameDirectory$ + "/maps/")
  EndMacro
  
  
  
  Procedure.s getModFolder(id$ = "", type$ = "mod")
    defineFolder()
    
    If id$ = "" And type$ = "mod"
      ProcedureReturn pMods$
    EndIf
    
    If Left(id$, 1) = "*"
      ProcedureReturn misc::Path(pWorkshop$ + Mid(id$, 2, Len(id$)-3) + "/")
    ElseIf Left(id$, 1) = "?"
      ProcedureReturn misc::Path(pStagingArea$ + Mid(id$, 2) + "/")
    ElseIf type$ = "dlc"
      ProcedureReturn misc::path(pDLCs$ + id$ + "/")
    ElseIf type$ = "map"
      ProcedureReturn misc::path(pMaps$ + id$ + "/")
    Else
      ProcedureReturn misc::path(pMods$ + id$ + "/")
    EndIf
  EndProcedure
  
  
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
  
  Procedure checkWorkshopID(id$)
    ; workshop folder only have a number as 
    
    Static regexp
    If Not IsRegularExpression(regexp)
      regexp = CreateRegularExpression(#PB_Any, "^([0-9]+)$")
    EndIf
    
    ProcedureReturn MatchRegularExpression(regexp, id$)
  EndProcedure
  
  ;- TODO do not return string but directly store "id" in *mod -> handle in other functions accordingly
  Procedure.s checkModFileZip(file$) ; check for res/ or mod.lua
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
          If GetFilePart(entry$) =  "mod.lua" ; found mod.lua, asume mod is valid
            ClosePack(pack)
            entry$ = GetFilePart(Left(entry$, FindString(entry$, "mod.lua")-2)) ; entry = folder name (id)
            debugger::Add("mods::checkModFileZip() - found mod.lua")
            ProcedureReturn entry$
          EndIf
        Wend
      EndIf
      ClosePack(pack)
    EndIf
    ProcedureReturn "false"
  EndProcedure
  
  Procedure.s checkModFileRar(file$, *mod.mod) ; check for res/ or mod.lua
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
        If GetFilePart(Entry$) =  "mod.lua"
          unrar::RARCloseArchive(hRAR) ; found mod.lua subfolder, assume this mod is valid
          entry$ = GetFilePart(Left(entry$, FindString(entry$, "mod.lua")-2)) ; entry$ = parent folder = id
          debugger::Add("mods::checkModFileRar() - found mod.lua")
          ProcedureReturn entry$
        EndIf
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #Null$, #Null$) ; skip to next entry in rar
      Wend
      unrar::RARCloseArchive(hRAR)
    EndIf
    ProcedureReturn "false"
  EndProcedure
  
  Procedure.s checkModFile(file$, *mod.mod) ; Check mod for a "res" folder or the mod.lua file, called in new(), return mod ID if any
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
  
  Procedure checkMod(path$)
    path$ = misc::path(path$)
    ; check if mod at specified path is valid
    ; mods must have
    ; - res/       OR
    ; - mod.lua
    ; mods should have
    ; - mod.lua               
    ; - image_00.tga          (ingame preview)
    ; - workshop_preview.jps  (workshop)
    ; mods can have
    ; - preview.png           (modmanager)
    
    If FileSize(path$) <> -2
      debugger::add("mods::checkMod() - ERROR: {"+path$+"} does not exist")
      ProcedureReturn #False
    EndIf
    
    If FileSize(path$ + "res") = -2
      ; res/ folder found, assume mod is ok
      ProcedureReturn #True
    EndIf
    
    If FileSize(path$ + "mod.lua") > 0
      ; mod.lua found, assume mod is ok
      ProcedureReturn #True
    EndIf
    
    
  EndProcedure
  
  Procedure.s getModRoot(path$) ; try to find mod.lua to determine the root location of the mod
    Protected dir
    Protected entry$, result$
    path$ = misc::path(path$) ; makes sure that string ends on delimiter
    
    dir = ExamineDirectory(#PB_Any, path$, "")
    If dir
      While NextDirectoryEntry(dir)
        entry$ = DirectoryEntryName(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_Directory
          If entry$ = "." Or entry$ = ".."
            Continue
          EndIf
          
          If entry$ = "res" And #False ; only rely on "mod.lua"
            FinishDirectory(dir)
            ProcedureReturn path$
          Else
            result$ = getModRoot(path$ + entry$)
            If result$
              FinishDirectory(dir)
              ProcedureReturn result$
            EndIf
          EndIf
          
        Else
          If entry$ = "mod.lua"
            debugger::add("mods::getModRoot() - found mod.lua in: "+path$)
            FinishDirectory(dir)
            ProcedureReturn path$
          EndIf
        EndIf
      Wend
    EndIf
    
    FinishDirectory(dir)
    ProcedureReturn ""
    
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
  
  Procedure parseInfoLUA(file$, *mod.mod)
    Protected ret
    ret = luaParser::parseInfoLUA(file$, *mod)
    If ret
      ; everytime when loading info from lua, save lua date to mod
      ; then, information only has to be reloaded if mod.lua is changed
      *mod\aux\luaDate = GetFileDate(file$, #PB_Date_Modified)
    EndIf
    ProcedureReturn ret
  EndProcedure
  
  Procedure localizeTags(*mod.mod)
    With *mod
      ClearList(\tagsLocalized$())
      ForEach \tags$()
        AddElement(\tagsLocalized$())
        \tagsLocalized$() = locale::l("tags", LCase(\tags$()))
      Next
    EndWith
  EndProcedure
  
  Procedure infoPP(*mod.mod)    ; post processing
;     debugger::Add("mods::infoPP("+Str(*mod)+")")
    
    localizeTags(*mod)
    
    ; version
    With *mod
      \majorVersion = Val(StringField(*mod\tpf_id$, CountString(*mod\tpf_id$, "_")+1, "_"))
      If \version$ And Not \minorVersion
        \minorVersion = Val(StringField(\version$, 2, "."))
      EndIf
      \version$ = Str(\majorVersion)+"."+Str(\minorVersion)
    EndWith
    
    ; if name or author not available
    With *mod
      Protected count, i
      count = CountString(\tpf_id$, "_")
      ; get author from ID
      If ListSize(\authors()) = 0
        AddElement(\authors())
        If count = 1 ; only name and version in ID
          \authors()\name$ = "unknown"
        Else ; author, name and version in ID
          \authors()\name$ = StringField(\tpf_id$, 1, "_")
          \authors()\role$ = ""
        EndIf
      EndIf
      ; get name from ID
      If \name$ = ""
        If count = 1
          \name$ = StringField(\tpf_id$, 1, "_")
        Else
          For i = 2 To count
            If \name$ : \name$ + "_" : EndIf
            \name$ + StringField(\tpf_id$, i, "_")
          Next
        EndIf
      EndIf
    EndWith
    
    ; Check for DLC
    ; known DLC: usa_1 and nordic_1
    If *mod\tpf_id$ = "usa_1" Or *mod\tpf_id$ = "nordic_1"
      *mod\aux\type$ = "dlc"
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
  
  Procedure getInfo(file$, *mod.mod, id$) ; extract info from new mod file$ (tpfmm.ini, mod.lua, ...)
    debugger::Add("mods::getInfo("+file$+", "+Str(*mod)+", "+id$+")")
    Protected tmpDir$ = misc::Path(GetTemporaryDirectory()+"/tpfmm/")
    misc::CreateDirectoryAll(tmpDir$)
    
    If FileSize(file$) <= 0
      debugger::add("mods::GetModInfo() - ERROR: no file {"+file$+"}")
      ProcedureReturn #False
    EndIf
    
    ; read standard information
    With *mod
      \aux\archive\name$ = GetFilePart(file$)
      \aux\archive\md5$ = FileFingerprint(file$, #PB_Cipher_MD5)
      \name$ = GetFilePart(File$, #PB_FileSystem_NoExtension)
    EndWith
    
    ; extract some files
    Protected NewList files$()
    AddElement(files$()) : files$() = "mod.lua"
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
    
    ; read mod.lua
    parseInfoLUA(tmpDir$ + "mod.lua", *mod)
    DeleteFile(tmpDir$ + "mod.lua")
    DeleteFile(tmpDir$ + "strings.lua")
    
    If Not generateID(*mod, id$)
      ProcedureReturn #False
    EndIf
    
    ; Post Processing
    infoPP(*mod)
    
    ; print mod information
    debugInfo(*mod)
    
    ; generate mod.lua (in memory)
    ; generateLUA(*mod)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure addToMap(*mod.mod)
    Protected count.i, id$ = *mod\tpf_id$
    
    If id$ = ""
      ProcedureReturn #False
    EndIf
    
    If FindMapElement(*mods(), id$)
      If *mods() = *mod ; same pointer = identical mod
        ; do nothing
      Else ; different mods with same tf_id! -> overwrite old mod
        debugger::Add("mods::toList() - WARNING: mod {"+*mod\tpf_id$+"} already in list -> delete old mod and overwrite with new")
        FreeStructure(*mods())
        DeleteMapElement(*mods(), *mod\tpf_id$)
      EndIf
    EndIf
    
    *mods(id$) = *mod ; add (or overwrite) mod to/in map
  EndProcedure
  
  Procedure extractZIP(file$, path$)
    debugger::Add("mods::extractZIP("+File$+")")
    Protected zip, error
    Protected zippedFile$, targetFile$
    
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
      
      zippedFile$ = PackEntryName(zip)
      zippedFile$ = misc::Path(GetPathPart(zippedFile$), "/")+GetFilePart(zippedFile$) ; zip always uses "/"
      If PackEntryType(zip) = #PB_Packer_File And PackEntrySize(zip) > 0
        zippedFile$ = misc::Path(GetPathPart(zippedFile$)) + GetFilePart(zippedFile$)
        targetFile$ = path$ + zippedFile$
        misc::CreateDirectoryAll(GetPathPart(targetFile$))
        debugger::Add("          extract {"+zippedFile$+"}")
        If UncompressPackFile(zip, targetFile$) = -1
          debugger::Add("mods::extractZIP() - ERROR - failed uncrompressing {"+PackEntryName(zip)+"} to {"+targetFile$+"}")
        EndIf
      EndIf
    Wend
    
    ClosePack(zip)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure extractRAR(file$, path$, *mod = #Null)
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
      
      entry$ = misc::Path(GetPathPart(entry$)) + GetFilePart(entry$) ; translate to correct delimiter: \ or /
      
      If unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #Null$, path$ + entry$) <> unrar::#ERAR_SUCCESS ; uncompress current file to modified tmp path
        debugger::Add("mods::extractRAR() - ERROR: failed to uncompress {"+entry$+"}")
      EndIf
      
    Wend
    unrar::RARCloseArchive(hRAR)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure exportListHTML(file$)
    debugger::add("mods::exportListHTML("+file$+")")
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
    WriteString(file, "<head><meta charset='utf-8' /><meta name='Author' content='TPFMM' /><title>TPFMM Modification List Export</title><style>", #PB_UTF8)
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
    WriteString(file, "List of Modifications", #PB_UTF8)
    WriteString(file, "</h1><table><tr><th>Modification</th><th>Version</th><th>Author</th></tr>", #PB_UTF8)
    
    ForEach *mods()
      *modinfo = *mods()
      With *modinfo
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
          
          
          WriteString(file, "<tr><td>" + name$ + "</td><td>" + \version$ + "</td><td>" + authors$ + "</td></tr>", #PB_UTF8)
      EndWith
    Next
    
    WriteString(file, "</table>", #PB_UTF8)
    WriteString(file, "<footer><article>Created with <a href='http://goo.gl/utB3xn'>TPFMM</a> "+updater::VERSION$+" &copy; 2014-"+FormatDate("%yyyy",Date())+" <a href='https://www.transportfevermods.com/'>Alexander Nähring</a></article></footer>", #PB_UTF8)
    
    WriteString(file, "</body></html>", #PB_UTF8)
    CloseFile(file)
    
    misc::openLink(File$)
  EndProcedure
  
  Procedure exportListTXT(File$)
    debugger::add("mods::exportListTXT("+file$+")")
    Protected file, i, authors$
    Protected *modinfo.mod
    
    file = CreateFile(#PB_Any, File$)
    If Not file
      debugger::add("mods::exportListTXT() - ERROR: cannot create file {"+file$+"}")
      ProcedureReturn #False
    EndIf
    
    ForEach *mods()
      *modinfo = *mods()
      With *modinfo
        authors$ = ""
        ForEach \authors()
          authors$ + \authors()\name$ + ", "
        Next
        If Len(authors$) >= 2 ; cut off ", " at the end of the string
          authors$ = Mid(authors$, 1, Len(authors$) -2)
        EndIf
          
        WriteStringN(file, \name$ + Chr(9) + "v" + \version$ + Chr(9) + authors$, #PB_UTF8)
      EndWith
    Next
    WriteStringN(file, "", #PB_UTF8)
    WriteString(file, "Created with TPFMM "+updater::VERSION$, #PB_UTF8)
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
  
  Procedure.s getAuthors(List authors.author())
    Protected authors$
    ForEach authors()
      authors$ + authors()\name$ + ", "
    Next
    If Len(authors$) > 2
      authors$ = Left(authors$, Len(authors$)-2)
    EndIf
    ProcedureReturn authors$
  EndProcedure
  
  Procedure.s listToString(List strings$())
    Protected str$
    ForEach strings$()
      str$ + strings$() + ", "
    Next
    If Len(str$) > 2
      str$ = Left(str$, Len(str$)-2)
    EndIf
    ProcedureReturn str$
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
  
  ;### data structure handling
  
  Procedure init() ; allocate mod structure
    Protected *mod.mod
    *mod = AllocateStructure(mod)
;     debugger::Add("mods::initMod() - new mod: {"+Str(*mod)+"}")
    ProcedureReturn *mod
  EndProcedure
  
  Procedure free(*mod.mod) ; delete mod from map and free memory
    Protected id$
    If *mod
      id$ = *mod\tpf_id$
      If id$ = "" ; TODO check for valid ID (in case of IMA)
        debugger::Add("mods::free() - ERROR: could not find ID for mod "+Str(*mod))
      EndIf
    Else
      debugger::Add("mods::free() - ERROR: invalid memory address provided")
      ProcedureReturn #False
    EndIf
    
    If FindMapElement(*mods(), id$)
      *mod = *mods()
;       debugger::Add("mods::free() - free mod "+Str(*mod)+" ("+id$+")")
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
      mods::free(*mods())
    Next
    ; displayMods()
  EndProcedure
  
  Procedure new(*data.queue::dat) ; INITIAL STEP: add new mod file from any location
    ProcedureReturn #False
    
    Protected file$ = *data\string$
    debugger::Add("mods::new("+file$+")")
    Protected *mod.mod, id$
    Protected gameDirectory$ = main::gameDirectory$
    
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
      If *mod\aux\archive\md5$ And *mods()\aux\archive\md5$ = *mod\aux\archive\md5$
        debugger::Add("mods::new() - MD5 check found match!")
        id$ = *mods()\tpf_id$
        sameHash = #True
        Break
      EndIf
    Next
    
    If sameHash
      Protected NewMap strings$()
      ClearMap(strings$())
      strings$("name") = *mods(id$)\name$
      MessageRequester(locale::l("main","install"), locale::getEx("management","conflict_hash",strings$()), #PB_MessageRequester_Ok)
      debugger::Add("mods::new() - cancel new installation, mod already installed")
      ;- TODO: ask user for reinstallation
      FreeStructure(*mod)
      ProcedureReturn #True
    EndIf
    
    If FindMapElement(*mods(), *mod\tpf_id$)
      debugger::Add("mods::new() - Another mod with id {"+id$+"} already in list!")
      id$ = *mod\tpf_id$
      sameID = #True
    EndIf
    
    If sameID
      Protected NewMap strings$()
      ClearMap(strings$())
      strings$("id") = *mod\tpf_id$
      strings$("old_name") = *mods(id$)\name$
      strings$("old_version") = *mods(id$)\version$
      strings$("new_name") = *mod\name$
      strings$("new_version") = *mod\version$
      ;- TODO check if this works on linux ( message requester in thread!)
      If MessageRequester(locale::l("main","install"), locale::getEx("management","conflict_id",strings$()), #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
        ; user does not want to replace
        FreeStructure(*mod)
        ProcedureReturn #True
      Else
        ; user wants to replace
        queue::add(queue::#QueueActionUninstall, *mod\tpf_id$) 
        queue::add(queue::#QueueActionInstall, file$) ; re-schedule this mod
        FreeStructure(*mod)
        ProcedureReturn #True
      EndIf
    EndIf
    queue::progressVal(3, 5)
    
    ; fourth step: copy mod to internal TPFMM mod folder and extract all recognised information files
    queue::progressText(locale::l("progress","copy_lib"))
    id$ = *mod\tpf_id$
    Protected dir$ = misc::Path(gameDirectory$+"/TPFMM/library/"+id$)
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
    Protected newfile$ = dir$ + *mod\aux\archive\name$
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
  
  ;### Load and Save
  
  Procedure loadList(*dummy) ; load mod list from file and scan for installed mods
    debugger::Add("mods::loadList("+main::gameDirectory$+")")
    
    Protected json, NewMap mods_json.mod(), *mod.mod
    Protected dir, entry$
    Protected NewMap scanner.scanner()
    Protected count, n, id$, modFolder$, luaFile$
    
    defineFolder()
    
    queue::progressText(locale::l("progress","load"))
    queue::progressVal(0, 1) ; 0% progress
    
    ; load list from json file
    json = LoadJSON(#PB_Any, pTPFMM$ + "mods.json")
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
    
    ; *mods() map now contains all mods that where known to TPFMM at last program shutdown
    ; check for new mods and check if mod info has changed since last parsing of mod.lua
    
    ; scan /mods and workshop folders
    ClearMap(scanner())
    
    ; scan for mods in folders!
    ; important: mods can be in (at least) three different places: mods/ workshop and staging_area
    ; mods/ is the "manual" installation folder, folders are names author_title_version , e.g. urbangames_no_costs_1
    ; workshop is filled automatically with subscribed mods from the workshop, folders are named after the item id, e.g. 763167187.
    ;   Internally, all * is used as prefix and _1 as postfix -> *763167187_1
    ; staging area is used for uplaoding mods to steam workshop
    ;   Internally, ? is used as prefix
    
    ; scan pMods
    debugger::Add("mods::loadList() - scan mods folder {"+pMods$+"}")
    dir = ExamineDirectory(#PB_Any, pMods$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If checkID(entry$) And checkMod(pMods$ + entry$)
          ; this folder is (most likely) a mod
          scanner(entry$)\type$ = "mod"
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ;scan pWorkshop
    debugger::Add("mods::loadList() - scan workshop folder {"+pWorkshop$+"}")
    dir = ExamineDirectory(#PB_Any, pWorkshop$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If checkWorkshopID(entry$)
          If checkMod(pWorkshop$ + entry$)
            ; workshop mod folders only have a number.
            ; Add * as prefix and _1 as postfix
            scanner("*"+entry$+"_1")\type$ = "mod"
          EndIf
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ;scan pStagingArea
    debugger::Add("mods::loadList() - scan staging area folder {"+pStagingArea$+"}")
    dir = ExamineDirectory(#PB_Any, pStagingArea$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If checkID(entry$)
          ; staging area mod have to comply to format (name_version)
          ; Add ? as prefix
          scanner("?"+entry$)\type$ = "mod" 
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ; scan pDLC
    debugger::Add("mods::loadList() - scan dlcs folder {"+pDLCs$+"}")
    dir = ExamineDirectory(#PB_Any, pDLCs$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If checkID(entry$)
          ; make sure to not overwrite any mods here!
          If FindMapElement(scanner(), entry$) = #Null
            scanner(entry$)\type$ = "dlc"
          Else
            debugger::add("mods::loadList() - WARNING: skipping DLC {"+entry$+"},  already found as mod!")
          EndIf
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    
    ; scanning finished - now check if new mods have been added or mods have been removed
    
    
    ; first check:  deleted mods
    ForEach *mods()
      If Not FindMapElement(scanner(), MapKey(*mods()))
        debugger::add("mods::loadList() - WARNING: remove {"+MapKey(*mods())+"} from list, no longer installed")
        free(*mods())
      EndIf
    Next
    
    
    ; second check: added mods
    count = MapSize(scanner())
    n = 0
    debugger::Add("mods::loadList() - found "+MapSize(scanner())+" mods in folders")
    If count > 0
      queue::progressVal(0, count)
      
      ForEach scanner()
        n + 1 ; update progress bar
        queue::progressVal(n)
        
        id$ = MapKey(scanner())
;         debugger::Add("mods::loadList() - scanner: {"+id$+"}")
        
        If Not FindMapElement(*mods(), id$)
          debugger::add("mods::loadList() - add new mod {"+id$+"} to list")
          ; create new mod and insert into map
          *mod = init()
          ; only basic information required here
          ; later, a check tests if info in list is up to date with mod.lua file
          ; only indicate type and location of mod here!
          *mod\tpf_id$ = id$ ; IMPORTANT
          
          *mod\aux\type$ = scanner()\type$
          
          ; save in list
          *mods(id$) = *mod
        EndIf
        
        If Not FindMapElement(*mods(), id$)
          ; this should never be reached
          debugger::add("mods::loadList() - ERROR: failed to add mod to map")
          Continue
        EndIf
        
        ; set pointer to current element in mod map
        *mod = *mods(id$)
        
        
        ; for all mods found in folder: get location of folder and check mod.lua for changes
        ; folder may be workshop, mods/ or dlcs/
        modFolder$ = getModFolder(id$, scanner()\type$)
        
        luaFile$ = modFolder$ + "mod.lua"
        ;- TODO: mod.lua not used for maps!
        
        ; check if mod.lua was modified and reload mod.lua if required
        ; will also trigger, if no info is stored until now (luaDate = 0)
        If *mod\name$ = "" Or *mod\aux\luaDate < GetFileDate(luaFile$, #PB_Date_Modified)
          ; load info from mod.lua
          If FileSize(luaFile$) > 0
            debugger::add("mods::loadList() - reload mod.lua for {"+id$+"}")
            If Not parseInfoLUA(luaFile$, *mod)
              debugger::add("mods::loadList() - ERROR: failed to parse mod.lua")
            EndIf
          Else
            ; no mod.lua present -> extract info from ID
            debugger::add("mods::loadList() - ERROR: no mod.lua for mod {"+id$+"} found!")
          EndIf
          infoPP(*mod) ; IMPORTANT
          
          If *mod\name$ = ""
            debugger::add("mods::loadList() - ERROR: mod {"+id$+"} has no name")
          EndIf
        EndIf
        
        localizeTags(*mod)
        
        ; after loading: write back mod.lua if not present
        Protected file
        If FileSize(luaFile$) <= 0
          file = CreateFile(#PB_Any, luaFile$)
          If file
            WriteString(file, getLUA(*mod), #PB_UTF8)
            CloseFile(file)
            *mod\aux\luaDate = GetFileDate(luaFile$, #PB_Date_Modified)
          EndIf
        EndIf
        
        ; no need to load images now, is handled dynamically if mod is selected
        
        If *mod\name$ = ""
          debugger::add("mods::loadList() - ERROR: no name for mod {"+id$+"}")
        EndIf
        
      Next
    EndIf
    
    
    
    ; Final Check
    debugger::add("mods::loadList() - final checkup")
    ForEach *mods()
      *mod = *mods()
      If *mod\tpf_id$ = "" Or MapKey(*mods()) = ""
        debugger::add("mods::loadList() - CRITICAL ERROR: mod without ID in list: key={"+MapKey(*mods())+"} tf_id$={"+*mod\tpf_id$+"}")
        End
      EndIf
    Next
    
    debugger::add("mods::loadList() - finished")
    ; Display mods in list gadget
    displayMods()
    displayDLCs()
    
  EndProcedure
  
  Procedure saveList()
    Protected gameDirectory$ = main::gameDirectory$
    debugger::add("mods::saveList("+gameDirectory$+")")
    
    If gameDirectory$ = ""
      debugger::add("mods::saveList() - ERROR: gameDirectory$ not defined")
      ProcedureReturn #False
    EndIf
    
    Protected NewMap mods_tmp.mod()
    ForEach *mods()
      CopyStructure(*mods(), mods_tmp(MapKey(*mods())), mod)
    Next
    
    defineFolder()
    
    If FileSize(pTPFMM$) <> -2
      misc::CreateDirectoryAll(pTPFMM$)
    EndIf
    
    Protected json
    json = CreateJSON(#PB_Any)
    InsertJSONMap(JSONValue(json), mods_tmp())
    SaveJSON(json, pTPFMM$ + "mods.json", #PB_JSON_PrettyPrint)
    FreeJSON(json)
    
    FreeMap(mods_tmp())
    
    ProcedureReturn #True
  EndProcedure
  
  ;### mod handling
  
  Procedure install(*data.queue::dat) ; install mod from file (archive)
    debugger::Add("mods::install("+Str(*data)+")")
    Protected file$ = *data\string$
    
    debugger::Add("mods::install() - {"+file$+"}")
    
    Protected source$, target$
    Protected i
    
    ; install replaces also "new".
    ; so: extract to target directory and add info to internal list
    ;- TODO: how to handle download information like e.g. when installing mod from repository
    ;- idea: use a second file in temp dir With same name As zip file To store repository information And load during install
    
    ; check if file exists
    If FileSize(file$) <= 0
      debugger::Add("mods::install() - file {"+file$+"} does not exist or is empty")
      ProcedureReturn #False
    EndIf
    
    
    ; 1) extract to temp directory (in TPF folder: /Transport Fever/TPFMM/temp/)
    ; 2) check extracted files and format
    ; 3) if not correc,t delete folder and cancel install
    ;    if correct, move whole folder to mods/ or dlc/ (depending on type)
    ; 4) save information to list for faster startup of TPFMM
    
    
    ; extract files to temp
    source$ = file$
    target$ = misc::Path(main::gameDirectory$+"/TPFMM/install/"+GetFilePart(file$, #PB_FileSystem_NoExtension)+"/")
    
    ; make sure target is clean!
    DeleteDirectory(target$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
;     If FileSize(target$) = -2
;       ; target directory could not be removed!
;       debugger::add("mods::install() - could not create clean target directory {"+target$+"}")
;       ProcedureReturn #False
;     EndIf
    
    ; create fresh target directory
    misc::CreateDirectoryAll(target$)
    ;RunProgram(target$)
    
    If Not extractZIP(source$, target$)
      If Not extractRAR(source$, target$)
        debugger::Add("mods::install() - ERROR - failed to extract files")
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; archive is extracted to target$
    ; try to find mod in target$ (may be in some sub-directory)...
    Protected modRoot$
    modRoot$ = getModRoot(target$)
    
    If modRoot$ = ""
      debugger::add("mods::install() - ERROR: getModRoot("+target$+") failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      ProcedureReturn #False
    EndIf
    
    ; modRoot folder found. 
    ; try to get ID from folder name
    Protected id$
    id$ = misc::getDirectoryName(modRoot$)
    Debug id$
    
    If Not checkID(id$)
      debugger::add("mods::install() - ERROR: checkID("+id$+") failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      ProcedureReturn #False
    EndIf
    
    ; copy mod to game folder
    Protected pMods$, modFolder$
    pMods$ = getModFolder()
    modFolder$ = misc::path(pMods$ + id$)
    
    ;- TODO: remove old version if present! (also handle old version in *mods list
    If Not RenameFile(modRoot$, modFolder$) ; RenameFile also works with directories!
      debugger::add("mods::install() - ERROR: MoveDirectory() failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      ProcedureReturn #False
    EndIf
    
    
    ;RunProgram(modFolder$)
    
    ; finish installation
    debugger::Add("mods::install() - finish installation...")
    DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
    displayMods(GetGadgetText(_gadgetMod))
    debugger::Add("mods::install() - finished")
    ProcedureReturn #True
  EndProcedure
  
  Procedure uninstall(*data.queue::dat) ; remove from Train Fever Mod folder (not library)
    debugger::Add("mods::uninstall("+Str(*data)+")")
    Protected id$
    id$ = *data\string$
    
    debugger::Add("mods::uninstall() - mod {"+id$+"}")
    
    Protected *mod.mod
    *mod = *mods(id$)
    
    If Not *mod
      debugger::add("mods::uninstall() - ERROR: cannot find *mod in list")
      ProcedureReturn #False
    EndIf
    
    If Left(id$, 11) = "urbangames_"
      debugger::add("mods::uninstall() - ERROR: cannot uninstall vanilla mods created by urbangames")
      ProcedureReturn #False
    EndIf
    
    If Left(id$, 1) = "*"
      debugger::add("mods::uninstall() - WARNING: uninstalling Steam Workshop mod - may be added automatically again by Steam client")
    EndIf
    
    Protected modFolder$
    modFolder$ = getModFolder(id$, *mod\aux\type$)
    
    debugger::add("mods::uninstall() - delete {"+modFolder$+"} and all subfolders")
    DeleteDirectory(modFolder$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    free(*mod)
    
    displayMods(GetGadgetText(_gadgetMod))
    
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
          \tpf_id$ = id$
          ; id read from mod folder was valid, thus use it directly
          ProcedureReturn #True
        Else
          debugger::Add("mods::generateID() - {"+id$+"} is no valid ID - generate new ID")
        EndIf
      Else
        debugger::Add("mods::generateID() - no ID defined - generate new ID")
      EndIf
      
      \tpf_id$ = LCase(\tpf_id$)
      
      ; Check if ID already correct
      If \tpf_id$ And checkID(\tpf_id$)
        debugger::Add("mods::generateID() - ID {"+\tpf_id$+"} is well defined (from structure)")
        ProcedureReturn #True
      EndIf
      
      ; Check if ID in old format
      author$   = StringField(\tpf_id$, 1, ".")
      name$     = StringField(\tpf_id$, CountString(\tpf_id$, ".")+1, ".")
      version$  = Str(Abs(Val(StringField(\version$, 1, "."))))
      \tpf_id$ = author$ + "_" + name$ + "_" + version$
      
      If \tpf_id$ And checkID(\tpf_id$)
        debugger::Add("mods::generateID() - ID {"+\tpf_id$+"} is well defined (converted from old TFFMM-id)")
        ProcedureReturn #True
      EndIf
      
      \tpf_id$ = ""
      
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
      version$ = Str(Val(StringField(\version$, 1, "."))) ; first part of version string concatenated by "." as numeric value
      
      \tpf_id$ = author$ + "_" + name$ + "_" + version$ ; concatenate id parts
      
      If \tpf_id$ And checkID(\tpf_id$)
        debugger::Add("mods::generateID() - ID {"+\tpf_id$+"} is well defined (generated by TPFMM)")
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
        ExportListHTML(file$)
      Case "txt"
        ExportListTXT(file$)
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
;     misc::StopWindowUpdate(WindowID(_window)) ; do not repaint window
;     HideGadget(_gadgetMod, #True)
    ListIcon::ClearListItems(_gadgetMod)
    
    ; count = number of individual parts of search string
    ; only if all parts are found, show result!
    count = CountString(filter$, " ") + 1 
    ForEach *mods()
      With *mods()
        mod_ok = 0 ; reset ok for every mod entry
        If \aux\type$ = "dlc"
          Continue
        EndIf
        If filter$ = ""
          mod_ok = 1
          count = 1
        Else
          ; check all individual parts of search string
          For k = 1 To count
            ; tmp_ok = true if this part is found, increase number of total matches by one
            tmp_ok = 0
            str$ = Trim(StringField(filter$, k, " "))
            If str$
              ; search in name, authors, tags
              If FindString(\name$, str$, 1, #PB_String_NoCase)
                tmp_ok = 1
              Else
                ForEach \authors()
                  If FindString(\authors()\name$, str$, 1, #PB_String_NoCase)
                    tmp_ok = 1
                    Break
                  EndIf
                Next
                If Not tmp_ok
                  ForEach \tags$()
                    If FindString(\tags$(), str$, 1, #PB_String_NoCase)
                      tmp_ok = 1
                      Break
                    EndIf
                  Next
                  If Not tmp_ok
                    ForEach \tagsLocalized$()
                      If FindString(\tagsLocalized$(), str$, 1, #PB_String_NoCase)
                        tmp_ok = 1
                        Break
                      EndIf
                    Next
                  EndIf
                EndIf
              EndIf
            Else
              tmp_ok = 1 ; empty search string is just ignored (ok)
            EndIf
            
            If tmp_ok
              mod_ok + 1
            EndIf
          Next
        EndIf
        If mod_ok And mod_ok = count ; all substrings have to be found (ok-counter == count of substrings)
          text$ = \name$ + #LF$ + getAuthors(\authors()) + #LF$ + listToString(\tags$()) + #LF$ + \version$
          
          ListIcon::AddListItem(_gadgetMod, item, text$)
          ListIcon::SetListItemData(_gadgetMod, item, *mods())
          ; ListIcon::SetListItemImage(_gadgetMod, item, ImageID(images::Images("yes")))
          ;- TODO: image based on online update status or something else?
          If Left(\tpf_id$, 1) = "*"
            ListIcon::SetListItemImage(_gadgetMod, item, ImageID(images::Images("icon_workshop")))
          Else
            If Left(\tpf_id$, 11) = "urbangames_"
              ListIcon::SetListItemImage(_gadgetMod, item, ImageID(images::Images("icon_mod_official")))
            Else
              ListIcon::SetListItemImage(_gadgetMod, item, ImageID(images::Images("icon_mod")))
            EndIf
          EndIf
          
          item + 1
        EndIf
      EndWith
    Next
    
;     HideGadget(_gadgetMod, #False)
;     misc::ContinueWindowUpdate(WindowID(_window))
    windowMain::stopGUIupdate(#False)
    
  EndProcedure
  
  Procedure displayDLCs()
;     Protected item
;     If Not IsGadget(_gadgetDLC)
;       ProcedureReturn #False
;     EndIf
;     If Not IsWindow(_window)
;       ProcedureReturn #False
;     EndIf
;     
;     ; IMPORTANT: New gadgets can only be added inside the main thread!
;     ; therefore, ensure that this procedure always calls the main thread
;     ; -> Cannot check if current function is called in main thread or not
;     ; therefore, just send an "event" to the main window, which is always handled in the main thread
;     ; the event has to be bound to the real "displayDLCs" function, which is then automatically called
;     PostEvent(#PB_Event_Gadget, _window, _gadgetEventTriggerDLC)
;     ProcedureReturn #True
  EndProcedure
  
  Procedure getPreviewImage(*mod.mod, original=#False)
;     debugger::add("mods::getPreviewImage("+*mod+", "+original+")")
    Static NewMap previewImages()
    Static NewMap previewImagesOriginal()
    
    If Not IsImage(previewImages(*mod\tpf_id$))
      ; if image is not yet loaded
      
      Protected im.i, modFolder$
      modFolder$ = getModFolder(*mod\tpf_id$, *mod\aux\type$)
      Protected NewList possibeFiles$()
      AddElement(possibeFiles$())
      possibeFiles$() = modFolder$ + "image_00.tga"
      AddElement(possibeFiles$())
      possibeFiles$() = modFolder$ + "workshop_preview.jpg"
      AddElement(possibeFiles$())
      possibeFiles$() = modFolder$ + "preview.png"
      
      ForEach possibeFiles$()
        If FileSize(possibeFiles$()) > 0
          im = LoadImage(#PB_Any, possibeFiles$())
          If IsImage(im)
            Break
          EndIf
        EndIf
      Next
      
      ClearList(possibeFiles$())
      
      If Not IsImage(im)
        ProcedureReturn #False
      EndIf
      
      
      ; mod images: 210x118 (original: 320x180)
      ; dlc images: 120x80
      previewImagesOriginal(*mod\tpf_id$) = im
      previewImages(*mod\tpf_id$) = misc::ResizeCenterImage(im, 210, 118)
    EndIf
    
    If original
      ProcedureReturn previewImagesOriginal(*mod\tpf_id$)
    Else
      ProcedureReturn previewImages(*mod\tpf_id$)
    EndIf
  EndProcedure
  
EndModule
