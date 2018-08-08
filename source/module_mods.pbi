XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_luaParser.pbi"
XIncludeFile "module_archive.pbi"

XIncludeFile "module_mods.h.pbi"

Module mods
  
  Structure scanner
    type$ ; mod, dlc, map
  EndStructure
  
  Global _window, _gadgetModList, _gadgetFilterString, _gadgetFilterHidden, _gadgetFilterVanilla, _gadgetFilterFolder
  
  Enumeration
    #FILTER_FOLDER_ALL = 0
    #FILTER_FOLDER_MANUAL
    #FILTER_FOLDER_STEAM
    #FILTER_FOLDER_STAGING
  EndEnumeration
  
  Enumeration
    #QUEUE_LOAD
    #QUEUE_INSTALL
    #QUEUE_UNINSTALL
    #QUEUE_BACKUP
    #QUEUE_UPDATE
  EndEnumeration
  Structure queue
    action.i
    string$
  EndStructure
  
  Global mutexMods    = CreateMutex()
  Global mutexQueue   = CreateMutex()
  Global _backupActive = #False
  Global threadQueue
  Global NewMap mods.mod()
  Global NewList queue.queue()
  
  Declare doLoad()
  Declare doInstall(file$)
  Declare doBackup(id$)
  Declare doUninstall(id$)
  Declare doUpdate(id$)
  
  UseMD5Fingerprint()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Macro defineFolder()
    Protected pTPFMM$, pMods$, pWorkshop$, pStagingArea$, pMaps$, pDLCs$
    pTPFMM$       = misc::Path(main::gameDirectory$ + "/TPFMM/") ; only used for json file
    pMods$        = misc::Path(main::gameDirectory$ + "/mods/")
    pDLCs$        = misc::Path(main::gameDirectory$ + "/dlcs/")
    pWorkshop$    = misc::Path(main::gameDirectory$ + "/../../workshop/content/446800/")
    pStagingArea$ = misc::Path(main::gameDirectory$ + "/userdata/staging_area/")
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
      regexp = CreateRegularExpression(#PB_Any, "^([A-Za-z0-9\-]+_)+[0-9]+$") ; no author name required
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
          \authors()\role$ = "CREATOR"
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
    If Not *mod
      debugger::add("mods::loadInfo() - Error: passed null pointer")
      ProcedureReturn
    EndIf
    
    
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
       *mod\aux\luaDate <> GetFileDate(luaFile$, #PB_Date_Modified) Or    ; mod.lua modified
       *mod\aux\sv <> #SCANNER_VERSION Or                                 ; new program version
       *mod\aux\luaLanguage$ <> locale::getCurrentLocale()                ; language changed
      ; load info from mod.lua
      If FileSize(luaFile$) > 0
;         debugger::add("mods::loadInfo() - reload mod.lua for {"+id$+"}")
        *mod\aux\luaParseError = #False
        If luaParser::parseModLua(modFolder$, *mod) ; current language
          ; ok
          *mod\aux\sv = #SCANNER_VERSION
        Else
          *mod\aux\luaParseError = #True
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
;     localizeTags(*mod)
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
  
  Procedure clearModInfo(*mod.mod)
    ; clean info
    ClearStructure(*mod, mod)
    InitializeStructure(*mod, mod)
  EndProcedure
  
  Procedure addToMap(id$, type$ = "mod")
    Protected *mod.mod
    
    LockMutex(mutexMods)
    If FindMapElement(mods(), id$) 
      debugger::Add("mods::addToMap() - WARNING: mod {"+id$+"} already in hash table -> delete old mod and overwrite with new")
      DeleteMapElement(mods())
    EndIf
    
    debugger::add("mods::addToMap() - add new mod {"+id$+"} to internal hash table")
    AddMapElement(mods(), id$)
    
    ; only basic information required here
    ; later, a check tests if info in list is up to date with mod.lua file
    ; only indicate type and location of mod here!
    
    mods()\tpf_id$    = id$
    mods()\aux\type$  = type$
    
    *mod = mods()
    
    UnlockMutex(mutexMods)
    
    ProcedureReturn *mod
  EndProcedure
  
  Procedure exportListHTML(file$, all)
    debugger::add("mods::exportListHTML("+file$+")")
    Protected file
    Protected *mod.mod
    Protected name$, author$, authors$
    Protected count, i, author.author
    
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
    ForEach mods()
      *mod = mods()
      With *mod
          name$ = \name$
          authors$ = ""
          
          If \url$
            name$ = "<a href='"+ \url$ + "'>" + name$ + "</a>"
          ElseIf \aux\tfnetID
            name$ = "<a href='https://www.transportfever.net/filebase/index.php/Entry/" + \aux\tfnetID + "'>" + name$ + "</a>"
          ElseIf \aux\workshopID
            name$ = "<a href='http://steamcommunity.com/sharedfiles/filedetails/?id=" + \aux\workshopID + "'>" + name$ + "</a>"
          EndIf
          
          count = modCountAuthors(*mod)
          For i = 0 To count-1
            If modGetAuthor(*mod, i, @author)
              author$ = author\name$
              If author\tfnetId
                author$ = "<a href='https://www.transportfever.net/index.php/User/" + author\tfnetId + "'>" + author$ + "</a>"
              EndIf
              authors$ + author$ + ", "
            EndIf
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
  
  Procedure exportListTXT(File$, all)
    debugger::add("mods::exportListTXT("+file$+")")
    Protected file, i, authors$
    Protected *mod.mod
    Protected count, author.author
    
    file = CreateFile(#PB_Any, File$)
    If Not file
      debugger::add("mods::exportListTXT() - ERROR: cannot create file {"+file$+"}")
      ProcedureReturn #False
    EndIf
    
    LockMutex(mutexMods)
    ForEach mods()
      *mod = mods()
      With *mod
        authors$ = ""
        count = modCountAuthors(*mod)
        For i = 0 To count-1
          If modGetAuthor(*mod, i, @author)
            authors$ + author\name$ + ", "
          EndIf
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
  
  Procedure.s getAuthorsString(*mod.mod)
    Protected authors$
    Protected count, i
    Protected author.author
    count = modCountAuthors(*mod)
    
    If count
      For i = 0 To count-1
        If modGetAuthor(*mod, i, @author)
          authors$ + author\name$ + ", "
        EndIf
      Next
      If Len(authors$) > 2 ; remove lat ", "
        authors$ = Left(authors$, Len(authors$)-2)
      EndIf
    EndIf
    ProcedureReturn authors$
  EndProcedure
  
  Procedure.s modGetTags(*mod.mod)
    Protected str$, tag$
    Protected count, i
    
    count = modCountTags(*mod)
    If count
      For i = 0 To count-1
        tag$ = modGetTag(*mod, i)
        If tag$
          str$ + tag$ + ", "
        EndIf
      Next
      If Len(str$) > 2
        str$ = Left(str$, Len(str$)-2)
      EndIf
    EndIf
    
    ProcedureReturn str$
  EndProcedure
  
  ; Backups
  
  Procedure.s getBackupFolder()
    Protected backupFolder$
    
    If main::gameDirectory$ = ""
      ProcedureReturn ""
    EndIf
    
    backupFolder$ = settings::getString("backup", "folder")
    If backupFolder$ = ""
      backupFolder$ = misc::path(main::gameDirectory$ + "TPFMM/backups/")
    EndIf
    
    ProcedureReturn backupFolder$
    
  EndProcedure
  
  Procedure moveBackupFolder(newFolder$)
    Protected oldFolder$, entry$
    Protected dir, error, count
    
    newFolder$ = misc::path(newFolder$)
    oldFolder$ = getBackupFolder()
    
    misc::CreateDirectoryAll(newFolder$)
    
    ; check if new folder is empty (only use empty folder)
    count = 0
    dir = ExamineDirectory(#PB_Any, newFolder$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          count + 1
        EndIf
      Wend
      FinishDirectory(dir)
    Else
      debugger::add("mods::moveBackupFolder() - ERROR: failed to examine directory "+newFolder$)
      error = #True
    EndIf
    
    If count
      debugger::add("mods::moveBackupFolder() - ERROR: target directory not empty")
      ProcedureReturn #False  
    EndIf
    
    ; move all *.zip and *.backup files from oldFolder$ to newFolder
    dir = ExamineDirectory(#PB_Any, oldFolder$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          entry$ = DirectoryEntryName(dir)
          If LCase(GetExtensionPart(entry$)) = "zip" Or
             LCase(GetExtensionPart(entry$)) = "backup"
            If Not RenameFile(oldFolder$ + entry$, newFolder$ + entry$)
              debugger::add("mods::moveBackupFolder() - ERROR: failed to move file "+entry$)
              error = #True
            EndIf
          EndIf
        EndIf
      Wend
      FinishDirectory(dir)
    Else
      debugger::add("mods::moveBackupFolder() - ERROR: failed to examine directory "+oldFolder$)
      error = #True
    EndIf
    
    
    If Not error
      settings::setString("backup", "folder", newFolder$)
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
    
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
  
  
  ; functions working on individual mods
  
  Global mutexModAuthors  = CreateMutex()
  Global mutexModTags     = CreateMutex()
  
  Procedure modCountAuthors(*mod.mod)
    Protected count.i
    LockMutex(mutexModAuthors)
    count = ListSize(*mod\authors())
    UnlockMutex(mutexModAuthors)
    ProcedureReturn count
  EndProcedure
  
  Procedure modGetAuthor(*mod.mod, n.i, *author.author)
    ; extract author #n from the list and save in *author
    Protected valid.i
    LockMutex(mutexModAuthors)
    If n <= ListSize(*mod\authors()) - 1
      SelectElement(*mod\authors(), n)
      CopyStructure(*mod\authors(), *author, author)
      valid = #True
    Else
      valid = #False
    EndIf
    UnlockMutex(mutexModAuthors)
    ProcedureReturn valid
  EndProcedure
  
  Procedure modCountTags(*mod.mod)
    Protected count.i
    LockMutex(mutexModTags)
    count = ListSize(*mod\tags$())
    UnlockMutex(mutexModTags)
    ProcedureReturn count
  EndProcedure
  
  Procedure.s modGetTag(*mod.mod, n.i)
    ; extract author #n from the list and save in *author
    Protected tag$
    LockMutex(mutexModTags)
    If n <= ListSize(*mod\tags$()) - 1
      SelectElement(*mod\tags$(), n)
      tag$ = *mod\tags$()
    EndIf
    UnlockMutex(mutexModTags)
    ProcedureReturn tag$
  EndProcedure
  
  
  
  ;### data structure handling
  
  Procedure init() ; allocate mod structure
    Protected *mod.mod
    *mod = AllocateStructure(mod)
;     debugger::Add("mods::initMod() - new mod: {"+Str(*mod)+"}")
    ProcedureReturn *mod
  EndProcedure
  
  Procedure freeAll()
    debugger::Add("mods::freeAll()")
    
    LockMutex(mutexMods)
    ForEach mods()
      DeleteMapElement(mods())
    Next
    UnlockMutex(mutexMods)
    
  EndProcedure
  
  ;### Load and Save
  
  Procedure doLoad() ; load mod list from file and scan for installed mods
    debugger::Add("mods::doLoad()")
    
    isLoaded = #False
    
    Protected json, NewMap mods_json.mod(), *mod.mod
    Protected dir, entry$
    Protected NewMap scanner.scanner()
    Protected count, n, id$, modFolder$, luaFile$
    
    defineFolder()
    
    windowMain::progressMod(0, locale::l("progress","load")) ; 0%
    
    LockMutex(mutexMods)
    
    ; load list from json file
    json = LoadJSON(#PB_Any, pTPFMM$ + "mods.json")
    If json
      debugger::add("mods::doLoad() - load mods from json file")
      ExtractJSONMap(JSONValue(json), mods_json())
      FreeJSON(json)
      
      ForEach mods_json()
        id$ = MapKey(mods_json())
        AddMapElement(mods(), id$)
        *mod = mods() ; work in pointer, manipulates also data in the map
        CopyStructure(mods_json(), *mod, mod)
        If Not *mod\aux\installDate
          *mod\aux\installDate = misc::time()
        EndIf
        ; debugger::add("mods::doLoad() - address {"+*mod+"} - id {"+*mod\tpf_id$+"} - name {"+*mod\name$+"}")
      Next
      
      debugger::Add("mods::doLoad() - loaded "+MapSize(mods_json())+" mods from mods.json")
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
    debugger::add("mods::doLoad() - check for removed mods")
    ForEach mods()
      If Not FindMapElement(scanner(), MapKey(mods()))
        debugger::add("mods::doLoad() - remove {"+MapKey(mods())+"} from list (folder removed)")
        DeleteMapElement(mods())
      EndIf
    Next
    
    
    ; second check: existing & added mods
    debugger::add("mods::doLoad() - check for added mods")
    count = MapSize(scanner())
    n = 0
    debugger::Add("mods::doLoad() - found "+MapSize(scanner())+" mods in folders")
    If count > 0
      
      ForEach scanner() ; for each mod found in any of the known mod folders:
        n + 1 ; update progress bar
        windowMain::progressMod(100*n/count)
        
        id$ = MapKey(scanner())
        
        If FindMapElement(mods(), id$)
          ; select existing element or
          *mod = mods()
        Else
          ; create new element
          *mod = addToMap(id$, scanner()\type$)
        EndIf
        
        If Not *mod Or Not FindMapElement(mods(), id$)
          ; this should never be reached
          debugger::add("mods::doLoad() - ERROR: failed to add mod to map")
          End
        EndIf
        
        loadInfo(*mod)
        
        ; no need to load images now, is handled dynamically if mod is selected
        
        If *mod\name$ = ""
          debugger::add("mods::doLoad() - ERROR: no name for mod {"+id$+"}")
        EndIf
        
      Next
    EndIf
    
    
    
    ; Final Check
    debugger::add("mods::doLoad() - final checkup")
    ForEach mods()
      *mod = mods()
      If *mod\tpf_id$ = "" Or MapKey(mods()) = ""
        debugger::add("mods::doLoad() - CRITICAL ERROR: mod without ID in list: key={"+MapKey(mods())+"} tf_id$={"+*mod\tpf_id$+"}")
        End
      EndIf
    Next
    
    debugger::add("mods::doLoad() - finished")
    windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","loaded"))
    
    UnlockMutex(mutexMods)
    
    ; Display mods in list gadget
    displayMods()
    
    isLoaded = #True
  EndProcedure
  
  Procedure saveList()
    Protected gameDirectory$ = main::gameDirectory$
    
    If Not isLoaded
      ; do not save list when it is not loaded
      ProcedureReturn #False
    EndIf
    
    If gameDirectory$ = ""
      debugger::add("mods::saveList() - gameDirectory$ not defined - do not save list")
      ProcedureReturn #False
    EndIf
    
    defineFolder()
    
    If FileSize(pTPFMM$) <> -2
      misc::CreateDirectoryAll(pTPFMM$)
    EndIf
    
    LockMutex(mutexMods)
    Protected json
    json = CreateJSON(#PB_Any)
    InsertJSONMap(JSONValue(json), mods())
    SaveJSON(json, pTPFMM$ + "mods.json", #PB_JSON_PrettyPrint)
    FreeJSON(json)
    
    UnlockMutex(mutexMods)
    
    ProcedureReturn #True
  EndProcedure
  
  ;### mod handling
  
  Procedure.s generateNewID(*mod.mod) ; return new ID as string
    Protected author$, name$, version$
    Protected author.author
    ; ID = author_mod_version
    
    Static RegExpNonAlphaNum
    If Not RegExpNonAlphaNum
      RegExpNonAlphaNum  = CreateRegularExpression(#PB_Any, "[^a-z0-9]") ; non-alphanumeric characters
      ; regexp matches all non alphanum characters including spaces etc.
    EndIf
    
    With *mod
      If modCountAuthors(*mod) > 0
        modGetAuthor(*mod, 0, @author)
        author$ = ReplaceRegularExpression(RegExpNonAlphaNum, LCase(author\name$), "") ; remove all non alphanum + make lowercase
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
    If Left(*mod\tpf_id$, 1) = "*" Or Left(*mod\tpf_id$, 1) = "?"
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
  
  Procedure isInstalledByRemote(source$, id)
    Protected installed = #False
    
    If Not id
      ProcedureReturn #False
    EndIf
    If source$ <> "tfnet" And
       source$ <> "tpfnet" And
       source$ <> "workshop"
      ProcedureReturn #False
    EndIf
    
    
    ; search for mod in list of installed mods
    LockMutex(mutexMods)
    ForEach mods()
      If StringField(mods()\aux\installSource$, 1, "/") = source$ And 
         Val(StringField(mods()\aux\installSource$, 2, "/")) = id
        installed = #True
        Break
      EndIf
      
      If source$ = "tfnet" Or source$ = "tpfnet"
        If mods()\aux\tfnetID = id
          installed = #True
          Break
        EndIf
        
      ElseIf source$ = "workshop"
        If mods()\aux\workshopID = id
          installed = #True
          Break
        EndIf
      EndIf
      
    Next
    UnlockMutex(mutexMods)
    
    ProcedureReturn installed
    
  EndProcedure
  
  Procedure isInstalled(id$)
    Protected installed = #False
    
    If id$ = ""
      ProcedureReturn #False
    EndIf
    
    LockMutex(mutexMods)
    If FindMapElement(mods(), id$)
      installed = #True
    EndIf
    UnlockMutex(mutexMods)
    
    ProcedureReturn installed
  EndProcedure
  
  Procedure.s getDownloadLink(*mod.mod)
    ; try to get a download link in form of source/id[/fileID]
    
    Protected source$
    Protected id.q, fileID.q
    
    If *mod\aux\installSource$
      source$ = StringField(*mod\aux\installSource$, 1, "/")
      id      = Val(StringField(*mod\aux\installSource$, 2, "/"))
      fileID  = Val(StringField(*mod\aux\installSource$, 3, "/"))
    EndIf
    
    If source$ And fileID
      ProcedureReturn source$+"/"+id+"/"+fileID
    EndIf
    
    If source$ And id
      ProcedureReturn source$+"/"+id
    EndIf
    
    If (source$ = "tpfnet" Or source$ = "tfnet") And *mod\aux\tfnetID
      ProcedureReturn "tpfnet/"+*mod\aux\tfnetID
    ElseIf source$ = "workshop" And *mod\aux\workshopID
      ProcedureReturn "workshop/"+*mod\aux\workshopID
    EndIf
    
    If *mod\aux\tfnetID
      ProcedureReturn "tpfnet/"+*mod\aux\tfnetID
    ElseIf *mod\aux\workshopID
      ProcedureReturn "workshop/"+*mod\aux\workshopID
    EndIf
    
    ProcedureReturn ""
  EndProcedure
  
  Procedure getRepoMod(*mod.mod)
    Protected *repoMod
    *repoMod = repository::getModByFoldername(*mod\tpf_id$)
    If Not *repoMod
      *repoMod  = repository::getModByLink(getDownloadLink(*mod))
    EndIf
    
    If Not *repoMod
      ;debugger::add("mods::getRepoMod() Could not find a mod for "+*mod\name$+" in online repository")
    EndIf
    
    ProcedureReturn *repoMod
  EndProcedure
  
  ; actions
  
  Procedure doInstall(file$) ; install mod from file (archive)
    debugger::Add("mods::doInstall("+file$+")")
    
    Protected source$, target$
    Protected id$
    Protected modRoot$, modFolder$
    Protected i
    Protected backup
    Protected *installedMod.mod
    Protected *mod.mod
    Protected json
    
    ; check if file exists
    If FileSize(file$) <= 0
      debugger::Add("mods::install() - file {"+file$+"} does not exist or is empty")
      ProcedureReturn #False
    EndIf
    
    windowMain::progressMod(20, locale::l("progress", "install"))
    
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
        debugger::Add("mods::doInstall() - ERROR - failed to extract files")
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","install_fail"))
        ProcedureReturn #False
    EndIf
    
    ; archive is extracted to target$
    ; (2) try to find mod in target$ (may be in some sub-directory)...
    windowMain::progressMod(40)
    modRoot$ = getModRoot(target$)
    
    If modRoot$ = ""
      debugger::add("mods::doInstall() - ERROR: getModRoot("+target$+") failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","install_fail"))
      ProcedureReturn #False
    EndIf
    
    ; modRoot folder found. 
    ; try to get ID from folder name
    id$ = misc::getDirectoryName(modRoot$)
    
    If Not checkID(id$) And checkWorkshopID(id$)
      ; backuped mods from workshop only have number, add _1
      id$ = id$ + "_1"
    EndIf
    
    If Not checkID(id$)
      debugger::add("mods::doInstall() - folder name not valid id ("+id$+")")
      
      ; try to get ID from archive file name
      id$ = GetFilePart(source$, #PB_FileSystem_NoExtension)
      If Not checkID(id$)
        debugger::add("mods::doInstall() - archive name not valid id ("+id$+")")
        ;TODO: backuped archives are "folder_id.<date>.zip" -> remove .<date> part to get ID?
        
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","install_fail_id"))
        ProcedureReturn #False
      EndIf
    EndIf
    
    
    modFolder$ = getModFolder(id$, "mod") ;- TODO handle installation of maps and DLCs
    
    ; check if mod already installed?
    LockMutex(mutexMods)
    *installedMod = FindMapElement(mods(), id$)
    UnlockMutex(mutexMods)
    
    If *installedMod
      debugger::add("mods::doInstall() - WARNING: mod {"+id$+"} is already installed, overwrite with new mod")
      
      ; backup before overwrite with new mod if activated in settings...
      If settings::getInteger("backup", "before_update")
        doBackup(id$)
      EndIf
      
      ; remove mod from internal map.
      LockMutex(mutexMods)
      DeleteMapElement(mods(), id$)
      UnlockMutex(mutexMods)
    EndIf
    
    ; if directory exists, remove
    Protected settingsLua$ = ""
    Protected file
    If FileSize(modFolder$) = -2
      ; keep settings.lua if present.
      If FileSize(modFolder$+"settings.lua") > 0
        file = ReadFile(#PB_Any, modFolder$+"settings.lua")
        If file
          settingsLua$ = ReadString(file, #PB_File_IgnoreEOL)
          CloseFile(file)
        EndIf
      EndIf
      
      DeleteDirectory(modFolder$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    EndIf
    
    
    ; (3) copy mod to game folder
    windowMain::progressMod(60)
    If Not RenameFile(modRoot$, modFolder$) ; RenameFile also works with directories!
      debugger::add("mods::doInstall() - ERROR: MoveDirectory() failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","install_fail"))
      ProcedureReturn #False
    EndIf
    
    ; restore mod settings
    If settingsLua$
      file = CreateFile(#PB_Any, modFolder$+"settings.lua")
      If file
        WriteString(file, settingsLua$)
        CloseFile(file)
      EndIf
    EndIf
    settingsLua$ = ""
    
    
    ; (4) create reference to mod and load info
    windowMain::progressMod(80)
    *mod = addToMap(id$, "mod")
    loadInfo(*mod)
    *mod\aux\installDate = misc::time()
    
    ; is mod installed from a repository? -> read .meta file
    If FileSize(file$+".meta") > 0
      ;-WIP! (load repository meta data...)
      ;TODO: change to direct passing of information via function parameter?
      ; pro of using file: information is also used when installing the file manually. (manually drag&drop from "download/" folder)
      ; read info from meta file and add information to file reference...
      ; IMPORTANT: tpfnetID / workshop id!
      json = LoadJSON(#PB_Any, file$+".meta")
      If json
        Protected repo_mod.repository::mod
        If JSONType(JSONValue(json)) = #PB_JSON_Object
          ExtractJSONStructure(JSONValue(json), repo_mod, repository::mod)
          FreeJSON(json)
          *mod\aux\repoTimeChanged = repo_mod\timechanged
          *mod\aux\installSource$ = repo_mod\installSource$
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
    windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","installed"))
    debugger::Add("mods::doInstall() - finish installation...")
    DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
    displayMods()
    debugger::Add("mods::doInstall() - finished")
    
    
    ; start backup if required
    If settings::getInteger("backup", "after_install")
      backup(id$)
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure doUninstall(id$) ; remove from Train Fever Mod folder
    debugger::Add("mods::doUninstall("+id$+")")
    
    
    Protected *mod.mod
    LockMutex(mutexMods)
    *mod = mods(id$)
    UnlockMutex(mutexMods)
    
    If Not *mod
      debugger::add("mods::doUninstall() - ERROR: cannot find *mod in list")
      ProcedureReturn #False
    EndIf
    
    If Not canUninstall(*mod)
      debugger::add("mods::doUninstall() - ERROR: can not uninstall {"+id$+"}")
      ProcedureReturn #False
    EndIf
    
    If Left(id$, 1) = "*"
      debugger::add("mods::doUninstall() - WARNING: uninstalling Steam Workshop mod - may be added automatically again by Steam client")
    EndIf
    

    If settings::getInteger("backup", "before_uninstall")
      doBackup(id$)
    EndIf
    
    
    Protected modFolder$
    modFolder$ = getModFolder(id$, *mod\aux\type$)
    
    debugger::add("mods::doUninstall() - delete {"+modFolder$+"} and all subfolders")
    DeleteDirectory(modFolder$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    DeleteMapElement(mods())
    
    windowMain::progressMod(windowMain::#Progress_Hide, locale::l("management", "uninstall_done"))
    
    displayMods()
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure doBackup(id$)
    debugger::add("mods::doBackup("+id$+")")
    Protected backupFolder$, modFolder$, backupFile$, backupInfoFile$
    Protected *mod.mod
    Protected time
    
    _backupActive = #True
    
    ; use local time, as this is displayed and only used to determine age of backup files...
    time = Date()
    
    backupFolder$ = getBackupFolder()
    If backupFolder$ = ""
      ProcedureReturn #False
    EndIf
    
    misc::CreateDirectoryAll(backupFolder$)
    
    LockMutex(mutexMods)
    If FindMapElement(mods(), id$)
      *mod = mods(id$)
      UnlockMutex(mutexMods)
    Else
      UnlockMutex(mutexMods)
      debugger::add("mods::doBackup() - ERROR: cannot find mod {"+id$+"}")
      _backupActive = #False
      ProcedureReturn #False
    EndIf
    
    
    If FileSize(backupFolder$) <> -2
      debugger::add("mods::doBackup() - ERROR: target directory does not exist {"+backupFolder$+"}")
      _backupActive = #False
      ProcedureReturn #False
    EndIf
    
    modFolder$ = getModFolder(id$, *mod\aux\type$)
    
    If FileSize(modFolder$) <> -2
      debugger::add("mods::doBackup() - ERROR: mod directory does not exist {"+modFolder$+"}")
      _backupActive = #False
      ProcedureReturn #False
    EndIf
    
    ; normally, use id$ as filename.
    backupFile$ = id$
    ; adjust name for workshop and staging area mods
    If Left(id$, 1) = "*"     ; workshop
      backupFile$ = Right(id$, Len(id$)-1)+"_1"
    ElseIf Left(id$, 1) = "?" ; staging area
      backupFile$ = Right(id$, Len(id$)-1)
    EndIf
    
    backupFile$     = backupFolder$ + backupFile$ + "." + FormatDate("%yyyy%mm%dd-%hh%ii%ss", time) + ".zip"
    backupInfoFile$ = backupFile$ + ".backup"
    
    ; start backup now: modFolder$ -> zip -> backupFile$
    Protected NewMap strings$()
    strings$("mod") = *mod\name$
    windowMain::progressMod(80, locale::getEx("progress", "backup_mod", strings$()))
    
    If archive::pack(backupFile$, modFolder$)
      debugger::add("mods::doBackup() - success")
      *mod\aux\backup\time = misc::time()
      *mod\aux\backup\filename$ = GetFilePart(backupFile$)
      
      ;TODO check for older backups with identical checksum...
      
      ; save mod information with the backup file
      Protected json
      Protected backupInfo.backupInfo
      json = CreateJSON(#PB_Any)
      If json
        backupInfo\name$      = *mod\name$
        backupInfo\version$   = *mod\version$
        backupInfo\author$    = getAuthorsString(*mod)
        backupInfo\tpf_id$    = *mod\tpf_id$
        backupInfo\filename$  = GetFilePart(backupFile$)
        backupInfo\time       = time
        backupInfo\size       = FileSize(backupFile$)
        backupInfo\checksum$  = FileFingerprint(backupFile$, #PB_Cipher_MD5)
        InsertJSONStructure(JSONValue(json), backupInfo, backupInfo)
        SaveJSON(json, backupInfoFile$, #PB_JSON_PrettyPrint)
        FreeJSON(json)
        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
          SetFileAttributes(backupInfoFile$, #PB_FileSystem_Hidden)
        CompilerEndIf
      Else
        debugger::add("mods::doBackup() - ERROR: failed to create backup meta data file: "+backupInfoFile$)
      EndIf
      
      ; finished
      windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress", "backup_fin"))
      _backupActive = #False
      ProcedureReturn #True
    Else
      debugger::add("mods::doBackup() - failed")
      windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress", "backup_fail"))
      _backupActive = #False
      ProcedureReturn #False
    EndIf
    
  EndProcedure
  
  Procedure doUpdate(id$)
    debugger::add("mods::doUpdate("+id$+")")
    Protected *mod.mod
    Protected link$
    
    link$ = repository::getLinkByFoldername(id$)
    
    If link$ = ""
      LockMutex(mutexMods)
      *mod = FindMapElement(mods(), id$)
      UnlockMutex(mutexMods)
      link$ = getDownloadLink(*mod)
    EndIf
    
    ; send back to windowMain, as there may be the need for a selection window (if mod has multiple files) 
    windowMain::repoFindModAndDownload(link$)
  EndProcedure
  
  Procedure handleQueue(*dummy)
    Protected action
    Protected string$
    
    debugger::add("mods::handleQueue()")
    
    Repeat
      working = #True
      LockMutex(mutexQueue)
      If ListSize(queue()) = 0
        working = #False
        UnlockMutex(mutexQueue)
        Delay(100)
        Continue
      EndIf
      
      ; get top item from queue
      FirstElement(queue())
      action = queue()\action
      string$ = queue()\string$
      DeleteElement(queue(), 1)
      UnlockMutex(mutexQueue)
      
      Select action
        Case #QUEUE_LOAD
          doLoad()
          
        Case #QUEUE_INSTALL
          doInstall(string$)
          
        Case #QUEUE_UNINSTALL
          doUninstall(string$)
          
        Case #QUEUE_BACKUP
          doBackup(string$)
          
        Case #QUEUE_UPDATE
          doUpdate(string$)
          
      EndSelect
      Delay(100)
    ForEver
  EndProcedure
  
  Procedure addToQueue(action, string$="")
    Debug "add to queue- wait for mutex"
    LockMutex(mutexQueue)
    Debug "got mutex - add"
    LastElement(queue())
    AddElement(queue())
    queue()\action  = action
    queue()\string$ = string$
    
    If Not threadQueue Or Not IsThread(threadQueue)
      Debug "start thread"
      threadQueue = CreateThread(@handleQueue(), 0)
    EndIf
    
    UnlockMutex(mutexQueue)
  EndProcedure
  
  ; actions (public)
  
  Procedure load()
    Debug "load"
    addToQueue(#QUEUE_LOAD)
  EndProcedure
  
  Procedure install(file$)
    addToQueue(#QUEUE_INSTALL, file$)
  EndProcedure
  
  Procedure uninstall(id$)
    addToQueue(#QUEUE_UNINSTALL, id$)
  EndProcedure
  
  Procedure backup(id$)
    addToQueue(#QUEUE_BACKUP, id$)
  EndProcedure
  
  Procedure update(id$)
    ; just add task, check later
    addToQueue(#QUEUE_UPDATE, id$)
    ProcedureReturn #True
  EndProcedure
  
  Procedure isUpdateAvailable(*mod.mod, *repo_mod.repository::mod = 0)
    Protected compare
    
    If Not *repo_mod
      *repo_mod = getRepoMod(*mod)
      If Not *repo_mod
        ; no online mod found -> no update available
        ProcedureReturn #False
      EndIf
    EndIf
    
    If settings::getInteger("", "compareVersion") And *repo_mod\version$
      ; use alternative comparison method: version check
      compare = Bool(*repo_mod\version$ And *mod\version$ And ValD(*mod\version$) < ValD(*repo_mod\version$))
    Else
      ; default compare: date check
      compare = Bool((*mod\aux\repoTimeChanged And *repo_mod\timechanged > *mod\aux\repoTimeChanged) Or
                     (*mod\aux\installDate And *repo_mod\timechanged > *mod\aux\installDate))
    EndIf
    ProcedureReturn compare
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
    
    file$ = SaveFileRequester(locale::l("management", "export_list"), "mods", "HTML|*.html|Text|*.txt", 0)
    If file$ = ""
      ProcedureReturn #False
    EndIf
    
    ; get selected file pattern (from dropdown in save file dialog)
    Select SelectedFilePattern()
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
        ExportListHTML(file$, all)
      Case "txt"
        ExportListTXT(file$, all)
      Default
        ProcedureReturn #False
    EndSelect
    ProcedureReturn #True
  EndProcedure
  
  Procedure displayMods()
    Protected filterString$, showHidden, showVanilla, filterFolder
    Protected text$, mod_ok, tmp_ok, count, item, k, col, str$
    Protected NewList *mods_to_display(), *mod.mod
    Protected *selectedMod.mod
    Protected i, n, author.author
    
;     debugger::add("mods::displayMods()")
    
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
    
    If GetGadgetState(_gadgetModList) <> -1
      *selectedMod = GetGadgetItemData(_gadgetModList, GetGadgetState(_gadgetModList))
      Debug "selected mod: "+*selectedMod\name$
    EndIf
    
    windowMain::stopGUIupdate()
    HideGadget(_gadgetModList, #True)
    ClearGadgetItems(_gadgetModList)
    
    
    ; count = number of individual parts of search string
    ; only if all parts are found, show result!
    count = CountString(filterString$, " ") + 1 
    LockMutex(mutexMods)
    ForEach mods()
      *mod = mods()
      With *mod
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
              
              ; mod settings
              If LCase(str$) = "!settings"
                If ListSize(*mod\settings()) > 0
                  tmp_ok = 1
                EndIf
              EndIf
              
              ; update available
              If LCase(str$) = "!update"
                ; do not search updates for workshop and staging_area
                If Left(*mod\tpf_id$, 1) <> "*" And Left(*mod\tpf_id$, 1) <> "?"
                  If isUpdateAvailable(*mod)
                    tmp_ok = 1
                  EndIf
                EndIf
              EndIf
              
              ; lua error
              If LCase(str$) = "!error"
                If *mod\aux\luaParseError
                  tmp_ok = 1
                EndIf
              EndIf
              
              ; name
              If FindString(\name$, str$, 1, #PB_String_NoCase)
                tmp_ok = 1
              EndIf
              
              ; authors
              If Not tmp_ok
                n = modCountAuthors(*mod)
                For i = 0 To n-1
                  If modGetAuthor(*mod, i, @author)
                    If FindString(author\name$, str$, 1, #PB_String_NoCase)
                      tmp_ok = 1
                      Break
                    EndIf
                  EndIf
                Next
              EndIf
              
              ; tags
              If Not tmp_ok
                n = modCountTags(*mod)
                For i = 0 To n-1
                  If FindString(modGetTag(*mod, i), str$, 1, #PB_String_NoCase)
                    tmp_ok = 1
                    Break
                  EndIf
                Next
              EndIf
              
            Else
              tmp_ok = 1 ; empty search string is just ignored (ok)
            EndIf
            
            If tmp_ok
              mod_ok + 1
            Else
              ; this substring was not found.
              ; currently: all parts of search string are "AND", so skip this mod
              Break ; break out of "For k = 1 To count"
            EndIf
          Next ; For k = 1 To count
        EndIf
        
        If mod_ok And mod_ok = count ; all substrings have to be found (ok-counter == count of substrings)
          
          AddElement(*mods_to_display())
          *mods_to_display() = mods()
          
        EndIf
      EndWith
    Next
    
    UnlockMutex(mutexMods)
    
    misc::SortStructuredPointerList(*mods_to_display(), #PB_Sort_Ascending|#PB_Sort_NoCase, OffsetOf(mod\name$), #PB_String)
    
    ForEach *mods_to_display()
      *mod = *mods_to_display()
      
      With *mod
        Protected supportsModSettings$ = ""
        If ListSize(\settings()) > 0
          supportsModSettings$ = locale::l("main","mod_options")
        EndIf 
        text$ = \name$ + #LF$ + getAuthorsString(*mod) + #LF$ + modGetTags(*mod) + #LF$ + \version$ + #LF$ + supportsModSettings$
        
        AddGadgetItem(_gadgetModList, item, text$)
        SetGadgetItemData(_gadgetModList, item, *mod)
        ; ListIcon::SetListItemImage(_gadgetModList, item, ImageID(images::Images("yes")))
        ;- TODO: image based on online update status or something else?
        If Left(\tpf_id$, 1) = "*"
          SetGadgetItemImage(_gadgetModList, item, ImageID(images::Images("icon_workshop")))
        Else
          If \aux\isVanilla
            SetGadgetItemImage(_gadgetModList, item, ImageID(images::Images("icon_mod_official")))
          Else
            SetGadgetItemImage(_gadgetModList, item, ImageID(images::Images("icon_mod")))
          EndIf
        EndIf
        
        If \aux\hidden
          ; RGB(100, 100, 100)
          SetGadgetItemColor(_gadgetModList, item, #PB_Gadget_FrontColor, settings::getInteger("color", "mod_hidden"))
        EndIf
        
        
        Protected *repo_mod.repository::mod
        If Left(\tpf_id$, 1) <> "*" And Left(\tpf_id$, 1) <> "?" ; do not search updates for workshop and staging_area
          *repo_mod = getRepoMod(*mod)
          If *repo_mod
            If isUpdateAvailable(*mod, *repo_mod)
              ; update available (most likely)
              ; RGB($FF, $99, $00)
              SetGadgetItemColor(_gadgetModList, item, #PB_Gadget_FrontColor, settings::getInteger("color", "mod_update_available"))
            Else
              ; no update available (most likely)
              ; RGB($00, $66, $00)
              SetGadgetItemColor(_gadgetModList, item, #PB_Gadget_FrontColor, settings::getInteger("color", "mod_up_to_date"))
            EndIf
          EndIf
        EndIf
        
        If \aux\luaParseError
          ; RGB($ff, $cc, $cc)
          SetGadgetItemColor(_gadgetModList, item, #PB_Gadget_BackColor, settings::getInteger("color", "mod_lua_error"))
        EndIf
        
        
        If *selectedMod And *selectedMod = *mod
          Debug "reselect mod: "+*mod\name$
          SetGadgetState(_gadgetModList, item)
        EndIf
        
        item + 1
      EndWith
    Next
    
    
    HideGadget(_gadgetModList, #False)
    windowMain::stopGUIupdate(#False)
    
  EndProcedure
  
  Procedure getMods(List *mods.mod())
    Protected count = 0
    ClearList(*mods())
    
    LockMutex(mutexMods)
    ForEach mods()
      AddElement(*mods())
      *mods() = mods()
      count +1 
    Next
    UnlockMutex(mutexMods)
    
    ProcedureReturn count
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
  
  ; backup stuff
  
  Procedure backupCleanFolder()
    Protected backupFolder$, infoFile$, zipFile$, entry$
    Protected dir, json, writeInfo
    Protected NewList backups.backupInfo()
    
    debugger::add("mods::backupCleanFolder()")
    
    If main::gameDirectory$ = ""
      ProcedureReturn #False
    EndIf
    
    If _backupActive
      ProcedureReturn #False
    EndIf
    
    
    backupFolder$ = getBackupFolder()
    If backupFolder$ = ""
      ProcedureReturn #False
    EndIf
    
    
    ; delete all .backup files without a corresponding .zip file
    dir = ExamineDirectory(#PB_Any, backupFolder$, "*.backup")
    If dir
      While NextDirectoryEntry(dir)
        entry$ = DirectoryEntryName(dir)
        
        infoFile$ = backupFolder$ + entry$
        zipFile$ = Left(infoFile$, Len(infoFile$) - Len(".backup"))
        
        If FileSize(zipFile$) <= 0
          DeleteFile(infoFile$)
          Continue
        EndIf
        
      Wend
      FinishDirectory(dir)
    EndIf
    
    ; create missing .backup files or fill in missing information
    dir = ExamineDirectory(#PB_Any, backupFolder$, "*.zip")
    If dir
      While NextDirectoryEntry(dir)
        entry$ = DirectoryEntryName(dir)
        AddElement(backups())
        
        zipFile$  = backupFolder$ + entry$
        infoFile$ = zipFile$ + ".backup"
        
        ; read .backup file (meta data like name, author, version, original ID, etc...
        json = LoadJSON(#PB_Any, infoFile$)
        If json
          ExtractJSONStructure(JSONValue(json), backups(), backupInfo)
          FreeJSON(json)
        EndIf
       
        
        With backups()
          ; add missing information
          writeInfo = #False
          If \filename$ = ""
            \filename$ = entry$
            writeInfo = #True
          EndIf
          If \tpf_id$ = ""
            \tpf_id$ = StringField(entry$, 1, ".") ; read filename up to first dot as tpf_id
            writeInfo = #True
          EndIf
          If \name$ = ""
            \name$ = \tpf_id$
            writeInfo = #True
          EndIf
          If Not \size
            \size = FileSize(zipFile$)
            writeInfo = #True
          EndIf
          If Not \time
            \time = GetFileDate(zipFile$, #PB_Date_Created)
            writeInfo = #True
          EndIf
          If \checksum$ = ""
            \checksum$ = FileFingerprint(zipFile$, #PB_Cipher_MD5)
            writeInfo = #True
          EndIf
          
          If writeInfo
            json = CreateJSON(#PB_Any)
            If json
              InsertJSONStructure(JSONValue(json), backups(), backupInfo)
              Debug infoFile$
              DeleteFile(infoFile$)
              SaveJSON(json, infoFile$, #PB_JSON_PrettyPrint)
              FreeJSON(json)
              CompilerIf #PB_Compiler_OS = #PB_OS_Windows
                SetFileAttributes(infoFile$, #PB_FileSystem_Hidden)
              CompilerEndIf
            EndIf
          EndIf
        EndWith
        
      Wend
      FinishDirectory(dir)
    EndIf
    
    
    ; delete duplicates (same fingerprint)
    Protected checksum$
    SortStructuredList(backups(), #PB_Sort_Descending, OffsetOf(backupInfo\time), TypeOf(backupInfo\time))
    ForEach backups()
      PushListPosition(backups())
      checksum$ = backups()\checksum$
      While NextElement(backups())
        If checksum$ = backups()\checksum$
          backupDelete(backups()\filename$)
          DeleteElement(backups())
        EndIf
      Wend
      PopListPosition(backups())
    Next
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure getBackupList(List backups.backupInfoLocal(), filter$ = "")
    Protected backupFolder$, entry$
    Protected zipFile$, infoFile$
    Protected dir, json, writeInfo
    
    debugger::add("mods::getBackupList()")
    
    ClearList(backups())
    
    If main::gameDirectory$ = ""
      ProcedureReturn #False
    EndIf
    
    backupFolder$ = getBackupFolder()
    If backupFolder$ = ""
      ProcedureReturn #False
    EndIf
    
    
    If Not backupCleanFolder()
      ProcedureReturn #False
    EndIf
    
    ; find all zip files in backup folder
    dir = ExamineDirectory(#PB_Any, backupFolder$, "*.zip")
    If dir
      While NextDirectoryEntry(dir)
        entry$ = DirectoryEntryName(dir)
        AddElement(backups())
        
        zipFile$  = backupFolder$ + entry$
        infoFile$ = zipFile$ + ".backup"
        
        ; read .backup file (meta data like name, author, version, original ID, etc...)
        json = LoadJSON(#PB_Any, infoFile$)
        If json
          ExtractJSONStructure(JSONValue(json), backups(), backupInfo)
          FreeJSON(json)
        EndIf
        
        backups()\installed = isInstalled(backups()\tpf_id$)
        
      Wend
      FinishDirectory(dir)
    EndIf
    
    If ListSize(backups()) = 0
      ProcedureReturn #False
    EndIf
    
;     SortStructuredList(backups(), #PB_Sort_Ascending|#PB_Sort_NoCase, OffsetOf(backupInfoLocal\tpf_id$), #PB_String)
    filter$ = Trim(filter$)
    If filter$
      ForEach backups()
        If Not FindString(backups()\name$, filter$, 1, #PB_String_NoCase) And
           Not FindString(backups()\tpf_id$, filter$, 1, #PB_String_NoCase) And
           Not FindString(backups()\filename$, filter$, 1, #PB_String_NoCase) And
           Not FindString(backups()\author$, filter$, 1, #PB_String_NoCase)
          DeleteElement(backups())
        EndIf
      Next
    EndIf
    
    
    ProcedureReturn #True
    
  EndProcedure
  
  Procedure backupDelete(file$)
    Protected backupFolder$
    Protected val = #False
    
    If _backupActive
      ProcedureReturn #False
    EndIf
    
    backupFolder$ = getBackupFolder()
    If backupFolder$
      file$ = backupFolder$ + file$
      If FileSize(file$) > 0
        DeleteFile(file$)
        DeleteFile(file$+".backup")
        val = #True
      EndIf
    EndIf
    
    ProcedureReturn val
  EndProcedure
  
  
EndModule
