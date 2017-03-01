XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_queue.pbi"
XIncludeFile "module_luaParser.pbi"
XIncludeFile "module_archive.pbi"

XIncludeFile "module_mods.h.pbi"

Module mods
  
  Structure scanner
    type$ ; mod, dlc, map
  EndStructure
  
  Global NewMap *mods.mod()
  Global mutexMods = CreateMutex()
  Global _window, _gadgetModList, _gadgetFilterString, _gadgetFilterHidden, _gadgetFilterVanilla, _gadgetFilterFolder
  
  Enumeration
    #FILTER_FOLDER_ALL = 0
    #FILTER_FOLDER_MANUAL
    #FILTER_FOLDER_STEAM
    #FILTER_FOLDER_STAGING
  EndEnumeration
  
  
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
      regexp = CreateRegularExpression(#PB_Any, "^([A-Za-z0-9]+_)+[0-9]+$") ; no author name required
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
  
  Procedure isVanillaMod(id$) ; check whether id$ belongs to official mod
    ; do not uninstall vanilla mods!
    Static NewMap vanillaMods()
    ; for speed purposes: fill map only at first call to procedure (static map)
    If MapSize(vanillaMods()) = 0
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_01_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_02_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_03_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_03_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_04_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_05_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_06_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_07_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_01_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_02_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_03_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_04_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_05_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_06_1")
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_07_1")
      AddMapElement(vanillaMods(), "urbangames_no_costs_1")
      AddMapElement(vanillaMods(), "urbangames_vehicles_no_end_year_1")
    EndIf
    
    ProcedureReturn Bool(FindMapElement(vanillaMods(), id$))
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
    
    ; version
    With *mod
      \majorVersion = Val(StringField(*mod\tpf_id$, CountString(*mod\tpf_id$, "_")+1, "_"))
      If \version$ And Not \minorVersion
        \minorVersion = Val(StringField(\version$, 2, "."))
      EndIf
      \version$ = Str(\majorVersion)+"."+Str(\minorVersion)
    EndWith
    
    ; if name or author not available, read from id
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
    
    ; Check for known DLC
;     If *mod\tpf_id$ = "usa_1" Or *mod\tpf_id$ = "nordic_1"
;       *mod\aux\type$ = "dlc"
;     EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure loadInfo(*mod.mod) ; load all (missing) information for this mod
                               ; first: read mod.lua if stored information is not up to date
                               ; second: update all volatile information (localized tags, etc...)
    
    Protected id$ = *mod\tpf_id$
    Protected modFolder$, luaFile$
    Protected file
    
    ; debugger::add("mods::loadInfo() - {"+id$+"}");
    
    ; for all mods found in folder: get location of folder and check mod.lua for changes
    ; folder may be workshop, mods/ or dlcs/
    modFolder$ = getModFolder(id$, *mod\aux\type$)
    luaFile$ = modFolder$ + "mod.lua"
    ;- TODO: mod.lua not used for maps!
    
    ; read mod.lua if required
    If *mod\name$ = "" Or                                                 ; no name
       *mod\aux\luaDate < GetFileDate(luaFile$, #PB_Date_Modified) Or     ; mod.lua modified
       *mod\aux\sv <> #SCANNER_VERSION Or                                 ; new program version
       *mod\aux\luaLanguage$ <> locale::getCurrentLocale()                ; language changed
      ; load info from mod.lua
      If FileSize(luaFile$) > 0
;         debugger::add("mods::loadInfo() - reload mod.lua for {"+id$+"}")
        If luaParser::parseModLua(modFolder$, *mod) ; current language
          ; ok
          *mod\aux\sv = #SCANNER_VERSION
        EndIf
      Else
        ; no mod.lua present -> extract info from ID
        debugger::add("mods::loadInfo() - ERROR: no mod.lua for mod {"+id$+"} found!")
      EndIf
      
      infoPP(*mod) ; IMPORTANT
      
      If *mod\name$ = ""
        debugger::add("mods::loadInfo() - ERROR: mod {"+id$+"} has no name")
      EndIf
    EndIf
    
    
    ; do this always
    localizeTags(*mod)
    *mod\aux\isVanilla = isVanillaMod(id$)
    
    
    If Left(id$, 1) = "*"
      ; workshop mod, read workshop file id directly from id
      *mod\aux\workshopID = Val(Mid(id$, 2, Len(id$)-3))
      
    Else
      ; not workshop mod, but "workshop_fileid.txt" present
      If FileSize(modFolder$ + "workshop_fileid.txt")
        file = ReadFile(#PB_Any, modFolder$ + "workshop_fileid.txt")
        If file
          ReadStringFormat(file) ; skip BOM if present
          *mod\aux\workshopID = Val(ReadString(file))
          CloseFile(file)
        EndIf
      EndIf
    EndIf
    
    
    If FileSize(luaFile$) <= 0
      ; maybe write a lua file?
    EndIf
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
  
  Procedure addToMap(id$, type$ = "mod")
    Protected count.i, *mod.mod
    
    debugger::add("mods::addToMap() - add new mod {"+id$+"} to internal hash table")
    ; create new mod and insert into map
    *mod = init()
    ; only basic information required here
    ; later, a check tests if info in list is up to date with mod.lua file
    ; only indicate type and location of mod here!
    *mod\tpf_id$    = id$
    *mod\aux\type$  = type$
    
    LockMutex(mutexMods)
    If FindMapElement(*mods(), id$) 
      debugger::Add("mods::addToMap() - WARNING: mod {"+*mod\tpf_id$+"} already in hash table -> delete old mod and overwrite with new")
      FreeStructure(*mods())
      DeleteMapElement(*mods(), *mod\tpf_id$)
    EndIf
    UnlockMutex(mutexMods)
    
    *mods(id$) = *mod ; add (or overwrite) mod to/in map
    
    ProcedureReturn *mod
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
    
    LockMutex(mutexMods)
    ForEach *mods()
      *modinfo = *mods()
      With *modinfo
          name$ = \name$
          authors$ = ""
          
          If \url$
            name$ = "<a href='"+ \url$ + "'>" + name$ + "</a>"
          ElseIf \aux\tfnetID
            name$ = "<a href='https://www.transportfever.net/filebase/index.php/Entry/" + \aux\tfnetID + "'>" + name$ + "</a>"
          ElseIf \aux\workshopID
            name$ = "<a href='http://steamcommunity.com/sharedfiles/filedetails/?id=" + \aux\workshopID + "'>" + name$ + "</a>"
          EndIf
          
          ForEach \authors()
            author$ = \authors()\name$
            If \authors()\tfnetId
              author$ = "<a href='https://www.transportfever.net/index.php/User/" + \authors()\tfnetId + "'>" + author$ + "</a>"
            EndIf
            authors$ + author$ + ", "
          Next
          If Len(authors$) >= 2 ; cut off ", " at the end of the string
            authors$ = Mid(authors$, 1, Len(authors$) -2)
          EndIf
          
          
          WriteString(file, "<tr><td>" + name$ + "</td><td>" + \version$ + "</td><td>" + authors$ + "</td></tr>", #PB_UTF8)
      EndWith
    Next
    UnlockMutex(mutexMods)
    
    WriteString(file, "</table>", #PB_UTF8)
    WriteString(file, "<footer><article>Created with <a href='http://goo.gl/utB3xn'>TPFMM</a> "+main::VERSION$+" &copy; 2014-"+FormatDate("%yyyy",Date())+" <a href='https://www.transportfevermods.com/'>Alexander Nähring</a></article></footer>", #PB_UTF8)
    
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
    
    LockMutex(mutexMods)
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
    UnlockMutex(mutexMods)
    WriteStringN(file, "", #PB_UTF8)
    WriteString(file, "Created with TPFMM "+main::VERSION$, #PB_UTF8)
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
  
  Procedure register(window, gadgetModList, gadgetFilterString, gadgetFilterHidden, gadgetFilterVanilla, gadgetFilterFolder)
    debugger::Add("mods::register()")
    _window               = window
    _gadgetModList        = gadgetModList
    _gadgetFilterString   = gadgetFilterString
    _gadgetFilterHidden   = gadgetFilterHidden
    _gadgetFilterVanilla  = gadgetFilterVanilla
    _gadgetFilterFolder   = gadgetFilterFolder
    
    If IsGadget(_gadgetFilterFolder)
      ClearGadgetItems(_gadgetFilterFolder)
      AddGadgetItem(_gadgetFilterFolder,      0, locale::l("mods","filter_all"))
      SetGadgetItemData(_gadgetFilterFolder,  0, #FILTER_FOLDER_ALL)
      AddGadgetItem(_gadgetFilterFolder,      1, locale::l("mods","filter_manual"))
      SetGadgetItemData(_gadgetFilterFolder,  1, #FILTER_FOLDER_MANUAL)
      AddGadgetItem(_gadgetFilterFolder,      2, locale::l("mods","filter_steam"))
      SetGadgetItemData(_gadgetFilterFolder,  2, #FILTER_FOLDER_STEAM)
      AddGadgetItem(_gadgetFilterFolder,      3, locale::l("mods","filter_staging"))
      SetGadgetItemData(_gadgetFilterFolder,  3, #FILTER_FOLDER_STAGING)
      SetGadgetState(_gadgetFilterFolder, 0)
    EndIf
    
    
    ProcedureReturn #True
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
        debugger::Add("mods::free() - ERROR: possible IMA: could not find ID for mod "+Str(*mod))
      EndIf
    Else
      debugger::Add("mods::free() - ERROR: IMA")
      ProcedureReturn #False
    EndIf
    
    LockMutex(mutexMods)
    If FindMapElement(*mods(), id$)
      *mod = *mods()
;       debugger::Add("mods::free() - free mod "+Str(*mod)+" ("+id$+")")
      DeleteMapElement(*mods())
      FreeStructure(*mod)
      UnlockMutex(mutexMods)
      ProcedureReturn #True
    EndIf
    UnlockMutex(mutexMods)
    
    debugger::Add("mods::freeMod() - WARNING: could not find mod {"+id$+"} in hash table")
    ProcedureReturn #False
    
  EndProcedure
  
  Procedure freeAll()
    debugger::Add("mods::freeAll()")
    ; cannot lock mutex here, is locked in "free"
    ForEach *mods()
      mods::free(*mods())
    Next
    ; displayMods()
  EndProcedure
  
  ;### Load and Save
  
  Procedure loadList(*dummy) ; load mod list from file and scan for installed mods
    debugger::Add("mods::loadList("+main::gameDirectory$+")")
    
    Protected json, NewMap mods_json.mod(), *mod.mod
    Protected dir, entry$
    Protected NewMap scanner.scanner()
    Protected count, n, id$, modFolder$, luaFile$
    
    defineFolder()
    
    windowMain::progressBar(0, 1, locale::l("progress","load")) ; 0%
    
    ; load list from json file
    json = LoadJSON(#PB_Any, pTPFMM$ + "mods.json")
    If json
      debugger::add("mods::loadList() - load mods from json file")
      ExtractJSONMap(JSONValue(json), mods_json())
      FreeJSON(json)
      
      ForEach mods_json()
        *mod = init()
        CopyStructure(mods_json(), *mod, mod)
        If Not *mod\aux\installDate
          *mod\aux\installDate = Date()
        EndIf
        *mods(MapKey(mods_json())) = *mod
        ; debugger::add("mods::loadList() - address {"+*mod+"} - id {"+*mod\tpf_id$+"} - name {"+*mod\name$+"}")
      Next
      debugger::Add("mods::loadList() - loaded "+MapSize(mods_json())+" mods from mods.json")
      FreeMap(mods_json())
    EndIf
    
    ; *mods() map now contains all mods that where known to TPFMM at last program shutdown
    ; check for new mods and check if mod info has changed since last parsing of mod.lua
    
    ;{ Scanning
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
    
    ;}
    ; scanning finished - now check if new mods have been added or mods have been removed
    
    
    ; first check:  deleted mods
    debugger::add("mods::loadList() - check for removed mods")
    ForEach *mods()
      If Not FindMapElement(scanner(), MapKey(*mods()))
        debugger::add("mods::loadList() - WARNING: remove {"+MapKey(*mods())+"} from list")
        free(*mods())
      EndIf
    Next
    
    
    ; second check: added mods
    debugger::add("mods::loadList() - check for added mods")
    count = MapSize(scanner())
    n = 0
    debugger::Add("mods::loadList() - found "+MapSize(scanner())+" mods in folders")
    If count > 0
      windowMain::progressBar(0, count)
      
      ForEach scanner() ; for each mod found in any of the known mod folders:
        n + 1 ; update progress bar
        windowMain::progressBar(n)
        
        id$ = MapKey(scanner())
        
        If FindMapElement(*mods(), id$)
          ; select existing element or
          *mod = *mods()
        Else
          ; create new element
          *mod = addToMap(id$, scanner()\type$)
        EndIf
        
        If Not *mod Or Not FindMapElement(*mods(), id$)
          ; this should never be reached
          debugger::add("mods::loadList() - ERROR: failed to add mod to map")
          Continue
        EndIf
        
        loadInfo(*mod)
        
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
    windowMain::progressBar(-1, -1, locale::l("progress","loaded")) ; 0%
    
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
  
  Procedure.s generateNewID(*mod.mod) ; return new ID as string
    Protected author$, name$, version$
    ; ID = author_mod_version
    
    Static RegExpNonAlphaNum
    If Not RegExpNonAlphaNum
      RegExpNonAlphaNum  = CreateRegularExpression(#PB_Any, "[^a-z0-9]") ; non-alphanumeric characters
      ; regexp matches all non alphanum characters including spaces etc.
    EndIf
    
    With *mod
      If ListSize(\authors()) > 0
        FirstElement(\authors()) ; LastElement ?
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
      
      ProcedureReturn author$ + "_" + name$ + "_" + version$ ; concatenate id parts
    EndWith
    
  EndProcedure
  
  Procedure canUninstall(*mod.mod)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    If *mod\aux\isVanilla
      ProcedureReturn #False
    EndIf
    If Left(*mod\tpf_id$, 1) = "*"
      ProcedureReturn #False
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure canBackup(*mod.mod)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    If *mod\aux\isVanilla
      ProcedureReturn #False
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure isInstalled(source$, id)
    
    If Not id
      ProcedureReturn #False
    EndIf
    If source$ <> "tfnet" And
       source$ <> "tpfnet" And
       source$ <> "workshop"
      ProcedureReturn #False
    EndIf
    
    ; search for mod in list of installed mods
    If source$ = "tfnet" Or source$ = "tpfnet"
      ForEach *mods()
        If *mods()\aux\tfnetID = id
          ProcedureReturn #True
        EndIf
      Next
    ElseIf source$ = "workshop"
      ForEach *mods()
        If *mods()\aux\workshopID = id
          ProcedureReturn #True
        EndIf
      Next
    EndIf
    
    ProcedureReturn #False
    
  EndProcedure
  
  
  Procedure install(*data.queue::dat) ; install mod from file (archive)
    debugger::Add("mods::install("+Str(*data)+")")
    Protected file$ = *data\string$
    
    debugger::Add("mods::install() - {"+file$+"}")
    
    Protected source$, target$
    Protected i
    
    
    ; check if file exists
    If FileSize(file$) <= 0
      debugger::Add("mods::install() - file {"+file$+"} does not exist or is empty")
      ProcedureReturn #False
    EndIf
    
    windowMain::progressBar(1, 5, locale::l("progress", "install"))
    
    ; 1) extract to temp directory (in TPF folder: /Transport Fever/TPFMM/temp/)
    ; 2) check extracted files and format
    ; 3) if not correct, delete folder and cancel install
    ;    if correct, move whole folder to mods/ or dlc/ (depending on type)
    ; 4) save information to list for faster startup of TPFMM
    
    
    ; (1) extract files to temp
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
    
    If Not archive::extract(source$, target$)
        debugger::Add("mods::install() - ERROR - failed to extract files")
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        windowMain::progressBar(-1, -1, locale::l("progress","install_fail"))
        ProcedureReturn #False
    EndIf
    
    ; archive is extracted to target$
    ; (2) try to find mod in target$ (may be in some sub-directory)...
    windowMain::progressBar(2, 5)
    Protected modRoot$
    modRoot$ = getModRoot(target$)
    
    If modRoot$ = ""
      debugger::add("mods::install() - ERROR: getModRoot("+target$+") failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      windowMain::progressBar(-1, -1, locale::l("progress","install_fail"))
      ProcedureReturn #False
    EndIf
    
    ; modRoot folder found. 
    ; try to get ID from folder name
    Protected id$
    id$ = misc::getDirectoryName(modRoot$)
    If Not checkID(id$)
      debugger::add("mods::install() - ERROR: checkID("+id$+") failed!")
      
      ; try to get ID from file name
      id$ = GetFilePart(source$, #PB_FileSystem_NoExtension)
      If Not checkID(id$)
        debugger::add("mods::install() - ERROR: checkID("+id$+") failed!")
        
        ;-TODO try to generate ID if not found?
        ; required for older mods - but new mods should not require this
        ;-TODO handle mods downloaded from workshop as well!
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        windowMain::progressBar(-1, -1, locale::l("progress","install_fail_id"))
        ProcedureReturn #False
      EndIf
    EndIf
    
    
    Protected modFolder$
    modFolder$ = getModFolder(id$, "mod") ;- TODO handle installation of maps and DLCs
    
    ; check if mod already installed?
    If FindMapElement(*mods(), id$)
      debugger::add("mods::install() - WARNING: mod {"+id$+"} is already installed, overwrite with new mod")
      free(*mods(id$))
    EndIf
    If FileSize(modFolder$) = -2
      DeleteDirectory(modFolder$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    EndIf
    
    
    ; (3) copy mod to game folder
    windowMain::progressBar(3, 5)
    If Not RenameFile(modRoot$, modFolder$) ; RenameFile also works with directories!
      debugger::add("mods::install() - ERROR: MoveDirectory() failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      windowMain::progressBar(-1, -1, locale::l("progress","install_fail"))
      ProcedureReturn #False
    EndIf
    
    
    ; (4) create reference to mod and load info
    windowMain::progressBar(4, 5)
    Protected *mod.mod
    *mod = addToMap(id$, "mod")
    loadInfo(*mod)
    *mod\aux\installDate = Date()
    
    ; is mod installed from a repository? -> read .meta file
    If FileSize(file$+".meta") > 0
      ;-WIP! (load repository meta data...)
      ;TODO: change to direct passing of information via function parameter?
      ; pro of using file: information is also used when installing the file manually. (manually drag&drop from "download/" folder)
      ; read info from meta file and add information to file reference...
      ; IMPORTANT: tpfnetID / workshop id!
      Protected json
      json = LoadJSON(#PB_Any, file$+".meta")
      If json
        Protected repo_mod.repository::mod
        If JSONType(JSONValue(json)) = #PB_JSON_Object
          ExtractJSONStructure(JSONValue(json), repo_mod, repository::mod)
          FreeJSON(json)
          *mod\aux\repoTimeChanged = repo_mod\timechanged
          Select repo_mod\source$
            Case "tpfnet"
              *mod\aux\tfnetID = repo_mod\id
            Case "workshop"
              *mod\aux\workshopID = repo_mod\id
            Default
              
          EndSelect
          ; other idea: mod\repositoryinformation = copy of repo info during time of installation/download
          ; later: when checking for update: compare repositoryinformation stored in mod with current information in repository.
        EndIf
      EndIf
      ; could read more information... (author, thumbnail, etc...)
      ; delete files from download directory? -> for now, keep as backup / archive
    EndIf
    
    ; finish installation
    windowMain::progressBar(-1, -1, locale::l("progress","installed"))
    debugger::Add("mods::install() - finish installation...")
    DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
    displayMods()
    debugger::Add("mods::install() - finished")
    
    
    ; start backup if required
    Protected backup, backupFolder$
    If OpenPreferences(main::settingsFile$) ;- TODO: make sure that preferences are not open in other thread? -> maybe use settings:: module with mutex..
      backup = ReadPreferenceInteger("autobackup", 0)
      ClosePreferences()
      If backup
        queue::add(queue::#QueueActionBackup, id$)
      EndIf
    EndIf
    
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
    
    If Not canUninstall(*mod)
      debugger::add("mods::uninstall() - ERROR: can not uninstall {"+id$+"}")
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
    
    displayMods()
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure backup(*data.queue::dat)
    Protected id$, backupFolder$, modFolder$, backupFile$
    Protected *mod.mod
    
    id$           = *data\string$
    backupFolder$ = *data\option$
    ; overwrite backupFolder
    backupFolder$ = misc::path(main::gameDirectory$ + "TPFMM/backups/")
    misc::CreateDirectoryAll(backupFolder$)
    
    debugger::add("mods::backup("+id$+")")
    
    If FindMapElement(*mods(), id$)
      *mod = *mods(id$)
    Else
      debugger::add("mods::backup() - ERROR: cannot find mod {"+id$+"}")
      ProcedureReturn #False
    EndIf
    
    
    If FileSize(backupFolder$) <> -2
      debugger::add("mods::backup() - ERROR: target directory does not exist {"+backupFolder$+"}")
      ProcedureReturn #False
    EndIf
    
    modFolder$ = getModFolder(id$, *mod\aux\type$)
    
    If FileSize(modFolder$) <> -2
      debugger::add("mods::backup() - ERROR: mod directory does not exist {"+modFolder$+"}")
      ProcedureReturn #False
    EndIf
    
    ; normally, use id$ as filename. DO NOT when creating backup of mods in workshop or staging area
    backupFile$ = id$
    If Left(id$, 1) = "*" Or Left(id$, 1) = "?" ; workshop or staging area
      ;backupFile$ = generateNewID(*mod)
      ; for now, use original folder name (without * and ?)
      backupFile$ = Right(id$, Len(id$)-1)
    EndIf
    
    ; add backupPath
    backupFile$ = backupFolder$ + backupFile$ + ".zip"
    
    ; start backup now: modFolder$ -> zip -> backupFile$
    Protected NewMap strings$()
    strings$("mod") = *mod\name$
    
    windowMain::progressBar(80, 100, locale::getEx("progress", "backup_mod", strings$()))
    
    If archive::pack(backupFile$, modFolder$)
      debugger::add("mods::backup() - success")
      *mod\aux\backup\date = Date()
      *mod\aux\backup\filename$ = GetFilePart(backupFile$)
      windowMain::progressBar(-1, -1, locale::l("progress", "backup_fin"))
      ProcedureReturn #True
    Else
      debugger::add("mods::backup() - failed")
      windowMain::progressBar(-1, -1, locale::l("progress", "backup_fail"))
      ProcedureReturn #False
    EndIf
    
  EndProcedure
  
  Procedure generateID(*mod.mod, id$ = "")
    debugger::Add("mods::generateID("+Str(*mod)+", "+id$+")")
    Protected author$, name$, version$
    
    If Not *mod
      ProcedureReturn
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
      
      \tpf_id$ = generateNewID(*mod)
      
      If \tpf_id$ And checkID(\tpf_id$)
        debugger::Add("mods::generateID() - ID {"+\tpf_id$+"} is well defined (generated by TPFMM)")
        ProcedureReturn #True
      EndIf
    EndWith
    
    debugger::Add("mods::generateID() - ERROR: No ID generated")
    ProcedureReturn #False
  EndProcedure
  
  Procedure.s getLUA(*mod.mod)
    
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
  
  Procedure displayMods()
    Protected filterString$, showHidden, showVanilla, filterFolder
    Protected text$, mod_ok, tmp_ok, count, item, k, col, str$
    Protected NewList *mods_to_display(), *mod.mod
    
    
    If Not IsWindow(_window)
      debugger::add("mods::displayMods() - ERROR: window not valid")
      ProcedureReturn #False
    EndIf
    If Not IsGadget(_gadgetModList)
      debugger::add("mods::displayMods() - ERROR: #gadget not valid")
      ProcedureReturn #False
    EndIf
    
    If IsGadget(_gadgetFilterString)
      filterString$ = GetGadgetText(_gadgetFilterString)
    EndIf
    If IsGadget(_gadgetFilterHidden)
      showHidden = GetGadgetState(_gadgetFilterHidden)
    EndIf
    If IsGadget(_gadgetFilterVanilla)
      showVanilla = GetGadgetState(_gadgetFilterVanilla)
    EndIf
    If IsGadget(_gadgetFilterFolder)
      filterFolder = GetGadgetItemData(_gadgetFilterFolder, GetGadgetState(_gadgetFilterFolder))
    EndIf
    
    
    windowMain::stopGUIupdate()
    HideGadget(_gadgetModList, #True)
    ListIcon::ClearListItems(_gadgetModList)
    
    Protected compareVersion
    If OpenPreferences(main::settingsFile$)
      compareVersion = ReadPreferenceInteger("compareVersion", #False)
      ClosePreferences()
    EndIf
    
    
    ; count = number of individual parts of search string
    ; only if all parts are found, show result!
    count = CountString(filterString$, " ") + 1 
    ForEach *mods()
      With *mods()
        mod_ok = 0 ; reset ok for every mod entry
        If \aux\type$ = "dlc"
          Continue
        EndIf
        If \aux\hidden And Not showHidden
          Continue
        EndIf
        If \aux\isVanilla And Not showVanilla
          Continue
        EndIf
        If filterFolder ; 0 = show all
          If Left(\tpf_id$, 1) = "*"
            If filterFolder <> #FILTER_FOLDER_STEAM
              Continue
            EndIf
          ElseIf Left(\tpf_id$, 1) = "?"
            If filterFolder <> #FILTER_FOLDER_STAGING
              Continue
            EndIf
          Else
            If filterFolder <> #FILTER_FOLDER_MANUAL
              Continue
            EndIf
          EndIf
        EndIf
        
        If filterString$ = ""
          mod_ok = 1
          count = 1
        Else
          ; check all individual parts of search string
          For k = 1 To count
            ; tmp_ok = true if this part is found, increase number of total matches by one
            tmp_ok = 0
            str$ = Trim(StringField(filterstring$, k, " "))
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
          
          AddElement(*mods_to_display())
          *mods_to_display() = *mods()
          
        EndIf
      EndWith
    Next
    
    misc::SortStructuredPointerList(*mods_to_display(), #PB_Sort_Ascending|#PB_Sort_NoCase, OffsetOf(mod\name$), #PB_String)
    
    Protected *repo_mod.repository::mod
    
    ForEach *mods_to_display()
      *mod = *mods_to_display()
      
      With *mod
        text$ = \name$ + #LF$ + getAuthors(\authors()) + #LF$ + listToString(\tags$()) + #LF$ + \version$
        
        ListIcon::AddListItem(_gadgetModList, item, text$)
        ListIcon::SetListItemData(_gadgetModList, item, *mod)
        ; ListIcon::SetListItemImage(_gadgetModList, item, ImageID(images::Images("yes")))
        ;- TODO: image based on online update status or something else?
        If Left(\tpf_id$, 1) = "*"
          ListIcon::SetListItemImage(_gadgetModList, item, ImageID(images::Images("icon_workshop")))
        Else
          If \aux\isVanilla
            ListIcon::SetListItemImage(_gadgetModList, item, ImageID(images::Images("icon_mod_official")))
          Else
            ListIcon::SetListItemImage(_gadgetModList, item, ImageID(images::Images("icon_mod")))
          EndIf
        EndIf
        
        If \aux\hidden
          SetGadgetItemColor(_gadgetModList, item, #PB_Gadget_FrontColor, RGB(100, 100, 100))
        EndIf
        
        \aux\repo_mod = repository::findModOnline(*mod)
        If \aux\repo_mod
          ; link to online mod exists
          *repo_mod = \aux\repo_mod
          ; try to find indication that repo mod is newer than local version
          ; do not use "version" for now, as it may not be realiable
          Protected compare
          If compareVersion And *repo_mod\version$
            ; use alternative comparison method: version check
            compare = Bool(*repo_mod\version$ And \version$ And ValD(\version$) < ValD(*repo_mod\version$))
          Else
            ; default compare: date check
            compare =  Bool((\aux\repoTimeChanged And *repo_mod\timechanged > \aux\repoTimeChanged) Or
                            (\aux\installDate And *repo_mod\timechanged > \aux\installDate))
          EndIf
          
          If compare
            ; update available (most likely)
            SetGadgetItemColor(_gadgetModList, item, #PB_Gadget_FrontColor, RGB($FF, $99, $00))
          Else
            ; no update available (most likely)
            SetGadgetItemColor(_gadgetModList, item, #PB_Gadget_FrontColor, RGB($00, $66, $00))
            
          EndIf
        EndIf
        
        
        item + 1
      EndWith
    Next
    
    
    HideGadget(_gadgetModList, #False)
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
      previewImages(*mod\tpf_id$) = misc::ResizeCenterImage(im, 240, 135)
    EndIf
    
    If original
      ProcedureReturn previewImagesOriginal(*mod\tpf_id$)
    Else
      ProcedureReturn previewImages(*mod\tpf_id$)
    EndIf
  EndProcedure
  
EndModule
