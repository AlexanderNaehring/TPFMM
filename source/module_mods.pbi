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
    folderLibrary.b
  EndStructure
  
  
  Global NewMap *mods.mod()
  Global changed.i ; report variable if mod states have changed
  Global library.i ; library gadget
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  
  Procedure checkID(id$)
;     debugger::Add("mods::checkID("+id$+")")
    Static regexp
    If Not IsRegularExpression(regexp)
      regexp = CreateRegularExpression(#PB_Any, "^([a-z0-9]+_){2,}[0-9]+$")
    EndIf
    
    ProcedureReturn MatchRegularExpression(regexp, id$)
  EndProcedure
  
  Procedure.s checkModFileZip(File$) ; check for res/ or info.lua
    debugger::Add("mods::CheckModFileZip("+File$+")")
    Protected entry$, pack
    
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
    Else
      debugger::Add("mods::checkModFileZip() - ERROR - cannot open pack {"+File$+"}")
    EndIf
    ProcedureReturn "false"
  EndProcedure
  
  Procedure.s checkModFileRar(File$) ; check for res/ or info.lua
    debugger::Add("mods::CheckModFileRar("+File$+")")
    Protected rarheader.unrar::RARHeaderDataEx
    Protected hRAR
    Protected entry$
    
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
          debugger::Add("mods::checkModFileRar() - found res\")
          ProcedureReturn entry$
        EndIf
        If GetFilePart(Entry$) =  "info.lua"
          unrar::RARCloseArchive(hRAR) ; found info.lua subfolder, assume this mod is valid
          entry$ = GetFilePart(Left(entry$, FindString(entry$, "info.lua")-2)) ; entry$ = parent folder = id
          debugger::Add("mods::checkModFileRar() - found info.lua")
          ProcedureReturn entry$
        EndIf
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; skip to next entry in rar
      Wend
      unrar::RARCloseArchive(hRAR)
    EndIf
    ProcedureReturn "false"
  EndProcedure
  
  Procedure.s checkModFile(File$) ; Check mod for a "res" folder or the info.lua file
    debugger::Add("mods::CheckModFile("+File$+")")
    Protected extension$, ret$
    
    extension$ = LCase(GetExtensionPart(File$))
    
    If FileSize(File$) <= 0
      debugger::Add("mods::checkModFile() - ERROR - {"+File$+"} not found")
      ProcedureReturn "false"
    EndIf
    
    ret$ = checkModFileZip(File$)
    If ret$ = "false"
      ret$ = checkModFileRar(File$)
      If ret$ = "false"
        ProcedureReturn "false"
      EndIf
    EndIf
    
;     Select PeekI(*system)
;       Case #system_old
;         debugger::Add("mods::checkModFile() - old modding system deteced")
;         Break
;       Case #system_new
;         debugger::Add("mods::checkModFile() - new modding system deteced")
;     EndSelect
    
    ProcedureReturn ret$
  EndProcedure
  
  Procedure cleanModInfo(*mod.mod)
    debugger::Add("mods::cleanModInfo("+Str(*mod)+")")
    With *mod
      \tf_id$ = ""
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
    
      \aux\archive$ = ""
      \aux\active = 0
;       \aux\lua$ = ""
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
    
      \aux\archive$ = ""
      \aux\active = 0
;       \aux\lua$ = ""
      
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
  
  Procedure infoPP(*mod.mod)    ; post processing
;     debugger::Add("mods::infoPP("+Str(*mod)+")")
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
    Protected json, json$
    
    json = CreateJSON(#PB_Any)
    InsertJSONStructure(JSONValue(json), *mod, mod)
    json$ = ComposeJSON(json, #PB_JSON_PrettyPrint)
    FreeJSON(json)
    debugger::add("mods::debugInfo(): "+json$)
    ProcedureReturn #True
    
;     Protected deb$
;     debugger::Add("mods::debugInfo() - tf_id: "+*mod\tf_id$)
;     debugger::Add("mods::debugInfo() - name: "+*mod\name$)
;     ForEach *mod\authors()
;       debugger::Add("mods::debugInfo() - author: "+*mod\authors()\name$+", "+*mod\authors()\role$+", "+*mod\authors()\text$+", "+*mod\authors()\steamProfile$+", "+Str(*mod\authors()\tfnetId))
;     Next
;     debugger::Add("mods::debugInfo() - minorVersion: "+Str(*mod\minorVersion))
;     debugger::Add("mods::debugInfo() - severityAdd: "+*mod\severityAdd$)
;     debugger::Add("mods::debugInfo() - severityRemove: "+*mod\severityRemove$)
;     debugger::Add("mods::debugInfo() - description: "+*mod\description$)
;     debugger::Add("mods::debugInfo() - tfnetId: "+Str(*mod\tfnetId))
;     debugger::Add("mods::debugInfo() - minGameVersion: "+Str(*mod\minGameVersion))
;     debugger::Add("mods::debugInfo() - url: "+*mod\url$)
;     deb$ = "mods::debugInfo() - tags: "
;     ForEach *mod\tags$()
;       deb$ + *mod\tags$()+", "
;     Next
;     debugger::Add(deb$)
;     deb$ = "mods::debugInfo() - dependencies: "
;     ForEach *mod\dependencies$()
;       deb$ + *mod\dependencies$()+", "
;     Next
;     debugger::Add(deb$)
  EndProcedure
  
  Procedure getInfo(file$, *mod.mod, id$) ; extract info from new mod file$ (tfmm.ini, info.lua, ...)
    debugger::Add("mods::loadInfo("+file$+", "+Str(*mod)+", "+id$+")")
    Protected tmpDir$ = GetTemporaryDirectory()
    
    ; clean info
    cleanModInfo(*mod)
    
    ; read standard information
    With *mod
      \aux\archive$ = GetFilePart(file$)
      \aux\archiveMD5$ = MD5FileFingerprint(file$)
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
    ; generateLUA(*mod)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure toList(*mod.mod) ; add *mod to map and to list gadget | if mod is overwritten, please make sure that old gadget entry is deleted beforehand!
    Protected count.i, id$ = *mod\tf_id$
    
    debugger::Add("mods::toList("+id$+")")
    
    If id$ = ""
      debugger::add("mods::toList() - ERROR: no id$ specified! CRITICAL")
      End
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
    If IsGadget(library) ; add newly added mod to list gadget
      count = CountGadgetItems(library)
      With *mod
        ListIcon::AddListItem(library, count, \name$ + Chr(10) + \aux\authors$ + Chr(10) + \aux\tags$ + Chr(10) + \aux\version$)
        ListIcon::SetListItemData(library, count, *mod)
        If \aux\active
          ListIcon::SetListItemImage(library, count, ImageID(images::Images("yes")))
        Else 
          ListIcon::SetListItemImage(library, count, ImageID(images::Images("no")))
        EndIf
      EndWith
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
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
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
;     debugger::Add("mods::initMod() - new mod: {"+Str(*mod)+"}")
    ProcedureReturn *mod
  EndProcedure
  
  Procedure free(id$)
;     debugger::Add("mods::freeMod("+id$+")")
    Protected *mod.mod
    If FindMapElement(*mods(), id$)
      FreeStructure(*mods())
      DeleteMapElement(*mods())
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
    If IsGadget(library)
      ListIcon::ClearListItems(library)
    EndIf
  EndProcedure
  
  Procedure new(file$) ; add new mod from any location to list of mods and initiate install
    debugger::Add("mods::addMod("+file$+")")
    Protected *mod.mod, id$
    Protected TF$ = main::TF$
    
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
      If *mods()\aux\archiveMD5$ = *mod\aux\archiveMD5$ And *mod\aux\archiveMD5$
        debugger::Add("mods::addMod() - MD5 check found match!")
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
        debugger::Add("mods::addMod() - cancel new installed, mod already installed")
      Else
        debugger::Add("mods::addMod() - trigger install of previous mod")
        queue::add(queue::#QueueActionInstall, id$)
      EndIf
      FreeStructure(*mod)
      ProcedureReturn #True
    EndIf
    
    If FindMapElement(*mods(),  *mod\tf_id$)
      debugger::Add("mods::addMod() - Another mod with id {"+id$+"} already in list!")
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
    
    ; fourth step: copy mod to internal TFMM mod folder and extract all recognised information files
    id$ = *mod\tf_id$
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
    ; TODO - decide to change filename and extension or leave it as original
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
        WriteString(file, getLUA(*mod), #PB_UTF8)
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
  
  Procedure loadList(*dummy) ; TF$) ; load all mods in internal modding folder and installed to TF
    Protected TF$ = main::TF$
    debugger::Add("mods::loadList("+TF$+")")
    
    Protected pMods$, pTFMM$, pLib$, pTMP$
    Protected json, NewMap mods_json.mod(), *mod.mod
    Protected dir, entry$, NewMap mod_scanner.mod_scanner()
    Protected count, n, id$, modFolder$, luaFile$
    
    pTFMM$  = misc::Path(TF$ + "/TFMM/")
    pLib$   = misc::Path(TF$ + "/TFMM/library/")
    pMods$  = misc::Path(TF$ + "/mods/")
    pTMP$   = GetTemporaryDirectory()
    
    
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
        *mods(MapKey(mods_json())) = *mod
      Next
      debugger::Add("mods::loadList() - loaded "+MapSize(mods_json())+" mods from mods.json")
      FreeMap(mods_json())
    EndIf
    
    ; *mods() map now contains all mods that where known to TFMM at last program exit
    ; check for new mods and check if mod info has changed since last parsing of info.lua
    
    ; scan Train Fever/mods/ and TFMM/library folders
    debugger::Add("mods::loadList() - scan mods folder {"+pMods$+"}")
    ClearMap(mod_scanner())
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
    ; TODO - currently, only "new modding system" is used
    ; TODO - with "old" system, installed mods do not have to be in "mods/" folder
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
        
        If Not FindMapElement(*mods(), id$)
          debugger::add("mods::loadList() - Found mod {"+id$+"} in folders, add new mod")
          ; if not already in map, create new mod and insert into map
          *mod = init()
          *mods(id$) = *mod
        EndIf
        
        If Not FindMapElement(*mods(), id$)
          ; this should never be reached
          debugger::add("mods::loadList() - ERROR: mod not found in map")
          Continue
        EndIf
        
        ; set pointer to current element in mod map
        *mod = *mods(id$)
        *mod\tf_id$ = id$ ; IMPORTANT
        
        ; mark mod as active if found in mods/ folder
        *mod\aux\active = mod_scanner()\folderMods
        ; analogue for library
        *mod\aux\inLibrary = mod_scanner()\folderLibrary
        
        ; handle stuff for installed mods
        If *mod\aux\active
          modFolder$  = misc::Path(pMods$ + id$ + "/")
          luaFile$    = modFolder$ + "info.lua"
          
          ; check if info.lua was modified and reload info.lua if required
          If *mod\aux\luaDate < GetFileDate(luaFile$, #PB_Date_Modified)
            debugger::add("mods::loadList() - reload info.lua for {"+id$+"}")
            If Not parseInfoLUA(luaFile$, *mod)
              debugger::add("mods::loadList() - ERROR: failed to parse info.lua")
            EndIf
            infoPP(*mod) ; IMPORTANT
            
            If *mod\name$ = ""
              debugger::add("mods::loadList() - CRITICAL ERROR: no name for mod {"+*mod+"} {"+id$+"}!")
            EndIf
          EndIf
          
          ; image loading is handled dynamically if mod is selected
        EndIf
        
        ; handle stuff for mods in library
        If *mod\aux\inLibrary
          modFolder$  = misc::Path(pLib$ + id$)
          luaFile$    = modFolder$ + "info.lua"
          ; info should be stored in mods.json
          ; if not? -> FIXME
          
          If *mod\aux\luaDate < GetFileDate(luaFile$, #PB_Date_Modified)
            If Not parseInfoLUA(luaFile$, *mod)
              debugger::add("mods::loadList() - ERROR: failed to parse info.lua")
            EndIf
            infoPP(*mod) ; IMPORTANT
          EndIf
          
          *mod\aux\archive$ =  misc::Path(pLib$ + id$ + "/") + id$ + ".tfmod"
;           *mod\aux\archiveMD5$ = MD5FileFingerprint(*mod\aux\archive$)
        EndIf
        
        If *mod\name$ = ""
          debugger::add("CRITICAL ERROR: no name for mod {"+*mod+"} {"+id$+"}!")
          MessageRequester("CRITICAL ERROR in mods::loadList()", "Possible critical error occured,"+#LF$+"please contact the programmer!")
        EndIf
      Next
    EndIf
    
    
    windowMain::stopGUIupdate()
    debugger::add("mods::loadList() - add all mods to list gadget")
    ForEach *mods()
      *mod = *mods()
      If *mod\tf_id$ = "" Or MapKey(*mods()) = ""
        debugger::add("mods::loadList() - CRITICAL ERROR: mod without ID in list: key={"+MapKey(*mods())+"} tf_id$={"+*mod\tf_id$+"}")
        End
      EndIf
      toList(*mods())
    Next
    windowMain::stopGUIupdate(#False)
    
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
    
    Protected json
    json = CreateJSON(#PB_Any)
    InsertJSONMap(JSONValue(json), mods_tmp())
    SaveJSON(json, pTFMM$ + "mods.json", #PB_JSON_PrettyPrint)
    FreeJSON(json)
    
    FreeMap(mods_tmp())
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure convert(*data.queue::dat)
    Protected TF$ = main::TF$
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
        new(mods$())
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
    
    ; TODO restore backups ?!
    
    ; delete backup folder
    DeleteDirectory(misc::path(TF$ + "TFMM/Backup/"), "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    ; TODO move message requester out of thread!
    ProcedureReturn #True
  EndProcedure
  
  Procedure install(*data.queue::dat)
    debugger::Add("mods::install("+Str(*data)+")")
    Protected TF$, id$
    id$ = *data\id$
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
    source$ = misc::Path(tf$+"TFMM/library/"+id$+"/") + id$ + ".tfmod"
    target$ = misc::Path(tf$+"/mods/"+id$+"/")
    
    If FileSize(target$) = -2
      debugger::Add("mods::install() - {"+target$+"} already exists - assume already installed")
      *mod\aux\active = #True
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
    *mod\aux\active = #True
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
    TF$ = main::TF$
    
    
    debugger::Add("mods::remove() - mod {"+id$+"}")
    
    Protected *mod.mod = *mods(id$)
    Protected targetDir$
    Protected i
    
    ; TODO alternatively, backup mod
    If *mod\aux\active And Not *mod\aux\inLibrary
      ; queue::add(queue::#QueueActionDelete, id$)
      delete(*data)
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
    targetDir$ = misc::Path(tf$+"/mods/"+id$+"/")
    
    debugger::add("mods::remove() - delete {"+targetDir$+"} and all subfolders")
    DeleteDirectory(targetDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    ; finish removal
    
    *mod\aux\active = #False
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
          \tf_id$ = id$
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
    
;     *mod\aux\lua$ = lua$
    ProcedureReturn lua$
  EndProcedure
  
  Procedure exportList(all=#False)
    
  EndProcedure
  
EndModule

; EnableXP