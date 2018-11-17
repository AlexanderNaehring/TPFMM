XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_luaParser.pbi"
XIncludeFile "module_archive.pbi"

XIncludeFile "module_mods.h.pbi"

Module mods
  UseModule debugger
  
  ;{ VT
  DataSection
    vtMod:
    ; get
    Data.i @modGetID()
    Data.i @modGetFoldername()
    Data.i @modGetName()
    Data.i @modGetVersion()
    Data.i @modGetDescription()
    Data.i @modGetAuthorsString()
    Data.i @modGetTags()
    Data.i @modGetDownloadLink()
    Data.i @modGetRepoMod()
    Data.i @modGetRepoFile()
    Data.i @modGetSize()
    Data.i @modGetWebsite()
    Data.i @modGetTfnetID()
    Data.i @modGetWorkshopID()
    Data.i @modGetSettings()
    Data.i @modGetInstallDate()
    Data.i @modGetPreviewImage()
    
    ; set
    Data.i @modSetName()
    Data.i @modSetDescription()
    Data.i @modSetMinorVersion()
    Data.i @modSetHidden()
    Data.i @modSetTFNET()
    Data.i @modSetWorkshop()
    Data.i @modSetLuaDate()
    Data.i @modSetLuaLanguage()
    
    ; add to / clear / sort lists
    Data.i @modAddAuthor()
    Data.i @modClearAuthors()
    Data.i @modAddTag()
    Data.i @modClearTags()
    Data.i @modAddDependency()
    Data.i @modClearDependencies()
    Data.i @modAddSetting()
    Data.i @modClearSettings()
    Data.i @modSortSettings()
    
    ; check
    Data.i @modIsVanilla()
    Data.i @modIsWorkshop()
    Data.i @modIsStagingArea()
    Data.i @modIsHidden()
    Data.i @modIsUpdateAvailable()
    Data.i @modCanBackup()
    Data.i @modCanUninstall()
    Data.i @modHasSettings()
    
    ; other
    Data.i @modCountAuthors()
    Data.i @modGetAuthor()
    Data.i @modCountTags()
    Data.i @modGetTag()
    
    vtModEnd:
  EndDataSection
  
  If (?vtModEnd - ?vtMod) <> SizeOf(LocalMod)
    DebuggerError("virtual table does not fit interface")
  EndIf
  
  ;}
  
  ;{ Enumerations
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
  ;}
  
  ;{ Structures
  
  Structure backup  ;-- information about last backup if available
    time.i
    filename$
  EndStructure
  
  Structure aux     ;-- additional information about mod
    isVanilla.b       ; pre-installed mods should not be uninstalled
    luaDate.i         ; date of info.lua (reload info when newer version available)
    luaLanguage$      ; language of currently loaded info from mod.lua -> reload mod.lua when language changes
    installDate.i     ; date of first encounter of this file (added to TPFMM)
    repoTimeChanged.i ; timechanged value from repository if installed from repo (if timechanged in repo > timechanged in mod: update available
    tfnetID.i         ; entry ID in transportfever.net download section
    workshopID.q      ; fileID in Steam Workshop
    installSource$    ; name of install source (workshop, tpfnet)
    sv.i              ; scanner version, rescan if newer scanner version is used
    hidden.b          ; hidden from overview ("visible" in mod.lua)
    backup.backup     ; backup information (local)
    luaParseError.b   ; set true if parsing of mod.lua failed
    size.i
  EndStructure
  
  Structure mod           ;-- information about mod/dlc
    vt.LocalMod
    tpf_id$              ; folder name in game: author_name_version or steam workshop ID
    name$                   ; name of mod
    majorVersion.i          ; first part of version number, identical to version in ID string
    minorVersion.i          ; latter part of version number
    version$                ; version string: major.minor(.build)
    severityAdd$            ; potential impact to game when adding mod
    severityRemove$         ; potential impact to game when removeing mod
    description$            ; optional description
    List authors.author()   ; information about author(s)
    List tags$()            ; list of tags
    minGameVersion.i        ; minimum required build number of game
    List dependencies$()    ; list of required mods (folder name of required mod)
    url$                    ; website with further information
    
    List settings.modLuaSetting() ; mod settings (optional)
    aux.aux                 ; auxiliary information
  EndStructure
  
  
  Structure queue
    action.i
    string$
  EndStructure
  
  ;}
  
  ;{ Globals
  
  Global mutexMods    = CreateMutex() ; access to the mods() map
  Global mutexQueue   = CreateMutex() ; access to the queue() list
  Global mutexModAuthors  = CreateMutex()
  Global mutexModTags     = CreateMutex()
  Global _backupActive = #False
  Global threadQueue
  Global NewMap mods.mod()
  Global NewList queue.queue()
  Global isLoaded.b
  Global exit.b
  
  Global callbackNewMod.callbackNewMod
  Global callbackRemoveMod.callbackRemoveMod
  Global callbackStopDraw.callbackStopDraw
  
  Global Dim events(EventArraySize)
  
  Declare doLoad()
  Declare doInstall(file$)
  Declare doBackup(id$)
  Declare doUninstall(id$)
  Declare doUpdate(id$)
  
  ;}
  
  UseMD5Fingerprint()
  
  ;- ####################
  ;-        PRIVATE 
  ;- ####################
  
  Macro defineFolder()
    Protected pTPFMM$, pMods$, pWorkshop$, pStagingArea$, pMaps$, pDLCs$
    Protected gameDirectory$
    gameDirectory$ = settings::getString("", "path")
    pTPFMM$       = misc::Path(gameDirectory$ + "/TPFMM/") ; only used for json file
    pMods$        = misc::Path(gameDirectory$ + "/mods/")
    pWorkshop$    = misc::Path(gameDirectory$ + "/../../workshop/content/446800/")
    pStagingArea$ = misc::Path(gameDirectory$ + "/userdata/staging_area/")
  EndMacro
  
  Procedure postProgressEvent(percent, text$=Chr(1))
    Protected *buffer
    If events(#EventProgress)
      If text$ = Chr(1)
        *buffer = #Null
      Else
        *buffer = AllocateMemory(StringByteLength(text$+" "))
;         Debug "########## poke "+text$+" @ "+*buffer
        PokeS(*buffer, text$)
      EndIf
      PostEvent(events(#EventProgress), 0, 0, percent, *buffer)
    EndIf
  EndProcedure
  
  ; init mods
  
  Procedure modInit(*mod.mod)
    *mod\vt       = ?vtMod
    
    CompilerIf #PB_Compiler_Debugger And #False
      Protected i, mem, iMem
      For i = 0 To SizeOf(LocalMod) Step SizeOf(integer)
        mem = PeekI(?vtMod + i)
        iMem = PeekI(*mod\vt + i)
        
        If mem = iMem
          Debug Str(mem)+" ok"
        Else
          Debug "error: "+mem+" != "+iMem
        EndIf
      Next
      
      Debug "---"
    CompilerEndIf
    
  EndProcedure
  
  Procedure modAddtoMap(id$) ; add new element to map
    Protected *mod.mod
    
    LockMutex(mutexMods)
    If FindMapElement(mods(), id$) 
      deb("mods:: mod {"+id$+"} already in hash table -> delete old mod and overwrite with new")
      DeleteMapElement(mods())
    EndIf
    
    *mod          = AddMapElement(mods(), id$)
    UnlockMutex(mutexMods)
    
    *mod\tpf_id$  = id$
    modInit(*mod)
    
    ProcedureReturn *mod
  EndProcedure
  
  Procedure freeAll()
    deb("mods:: free all mods")
    
    ; remove all items from mod list
    
    If callbackStopDraw
      callbackStopDraw(#True)
    EndIf
    If events(#EventStopDraw)
      PostEvent(events(#EventStopDraw), #True, 0)
    EndIf
    
    LockMutex(mutexMods)
    If callbackRemoveMod
      ForEach mods()
        callbackRemoveMod(mods())
      Next
    EndIf
    If events(#EventRemoveMod)
      ForEach mods()
        PostEvent(events(#EventRemoveMod), mods(), 0)
      Next
    EndIf
    UnlockMutex(mutexMods)
    
    If callbackStopDraw
      callbackStopDraw(#False)
    EndIf
    If events(#EventStopDraw)
      PostEvent(events(#EventStopDraw), #False, 0)
    EndIf
    
    ; clean map
    LockMutex(mutexMods)
    ClearMap(mods())
    UnlockMutex(mutexMods)
    
  EndProcedure
  
  ; Queue
  
  Procedure handleQueue(*dummy)
    ; mod handling thread main loop
    ; this thread takes care of all hard actions performed on mods (install, remove, backup, ...)
    Protected action
    Protected string$
    
    Repeat
      LockMutex(mutexQueue)
      If ListSize(queue()) = 0
        UnlockMutex(mutexQueue)
        Delay(100)
        Continue
      EndIf
      
      ; there is something to do
      If events(#EventWorkerStarts)
        PostEvent(events(#EventWorkerStarts))
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
      
      ; finished
      If events(#EventWorkerStops)
        PostEvent(events(#EventWorkerStops))
      EndIf
      
    Until exit
  EndProcedure
  
  Procedure addToQueue(action, string$="")
    LockMutex(mutexQueue)
    LastElement(queue())
    AddElement(queue())
    queue()\action  = action
    queue()\string$ = string$
    
    If Not threadQueue Or Not IsThread(threadQueue)
      exit = #False
      threadQueue = CreateThread(@handleQueue(), 0)
    EndIf
    
    UnlockMutex(mutexQueue)
  EndProcedure
  
  Procedure stopQueue(timeout = 5000)
    
    
    ; wait for worker to finish or timeout
    If threadQueue And IsThread(threadQueue)
      ; set exit flag for worker
      exit = #True
      
      WaitThread(threadQueue, timeout)
      
      If IsThread(threadQueue)
        deb("mods:: kill worker")
        KillThread(threadQueue)
        ; WARNING: killing will potentially leave mutexes and other resources locked/allocated
      EndIf
      
      exit = #False
    EndIf
    
    
    ProcedureReturn #True
  EndProcedure
  
  ; other procedures
  
  Procedure.s getModFolder(id$="")
    defineFolder()
    
    If id$ = ""
      ProcedureReturn pMods$
    EndIf
    
    If Left(id$, 1) = "*"
      ProcedureReturn misc::Path(pWorkshop$ + Mid(id$, 2, Len(id$)-3) + "/")
    ElseIf Left(id$, 1) = "?"
      ProcedureReturn misc::Path(pStagingArea$ + Mid(id$, 2) + "/")
    Else
      ProcedureReturn misc::path(pMods$ + id$ + "/")
    EndIf
  EndProcedure
  
  Procedure modCheckID(id$)
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
  
  Procedure modCheckWorkshopID(id$)
    ; workshop folder only have a number as 
    
    Static regexp
    If Not IsRegularExpression(regexp)
      regexp = CreateRegularExpression(#PB_Any, "^([0-9]+)$")
    EndIf
    
    ProcedureReturn MatchRegularExpression(regexp, id$)
  EndProcedure
  
  Procedure modCheckValidTPF(path$)
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
      deb("mods:: {"+path$+"} does not exist")
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
  
  Procedure.s modGetRoot(path$) ; try to find mod.lua to determine the root location of the mod
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
            result$ = modGetRoot(path$ + entry$)
            If result$
              FinishDirectory(dir)
              ProcedureReturn result$
            EndIf
          EndIf
          
        Else
          If entry$ = "mod.lua"
            FinishDirectory(dir)
            ProcedureReturn path$
          EndIf
        EndIf
      Wend
    EndIf
    
    FinishDirectory(dir)
    ProcedureReturn ""
    
  EndProcedure
  
  Procedure modInfoProcessing(*mod.mod)    ; post processing
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
  
  Procedure modLoadInfo(*mod.mod) ; load all (missing) information for this mod
                               ; first: read mod.lua if stored information is not up to date
                               ; second: update all volatile information (localized tags, etc...)
    If Not *mod
      ProcedureReturn
    EndIf
    
    
    Protected id$ = *mod\tpf_id$
    Protected modFolder$, luaFile$
    Protected file
    
    ; debugger::add("mods::loadInfo() - {"+id$+"}");
    
    ; for all mods found in folder: get location of folder and check mod.lua for changes
    ; folder may be workshop, mods/ or dlcs/
    modFolder$ = getModFolder(id$)
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
        deb("mods:: no mod.lua for mod {"+id$+"} found!")
      EndIf
      
      modInfoProcessing(*mod) ; IMPORTANT
      
      If *mod\name$ = ""
        deb("mods:: mod {"+id$+"} has no name")
      EndIf
    EndIf
    
    
    ; do this always
;     localizeTags(*mod)
    *mod\aux\isVanilla = modIsVanilla(*mod)
    
    
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
  
  Procedure modClearInfo(*mod.mod)
    ; clean info
    ClearStructure(*mod, mod)
    InitializeStructure(*mod, mod)
  EndProcedure
  
  
  
  Procedure convertToTGA(imageFile$)
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
      deb("mods:: cannot examine "+path$)
    EndIf
    ProcedureReturn entry$
  EndProcedure
  
  ; Backups
  
  Procedure.s getBackupFolder()
    Protected backupFolder$
    
    If settings::getString("","path") = ""
      ProcedureReturn ""
    EndIf
    
    backupFolder$ = settings::getString("backup", "folder")
    If backupFolder$ = ""
      backupFolder$ = misc::path(settings::getString("","path") + "TPFMM/backups/")
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
      deb("mods:: failed to examine directory "+newFolder$)
      error = #True
    EndIf
    
    If count
      deb("mods:: target directory not empty")
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
              deb("mods:: failed to move file "+entry$)
              error = #True
            EndIf
          EndIf
        EndIf
      Wend
      FinishDirectory(dir)
    Else
      deb("mods:: failed to examine directory "+oldFolder$)
      error = #True
    EndIf
    
    
    If Not error
      settings::setString("backup", "folder", newFolder$)
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
    
  EndProcedure
  
  
  ;- ####################
  ;-       PUBLIC 
  ;- ####################
  
  
  ; functions working on individual mods
  
  Procedure getModByFoldername(foldername$)
    Protected *mod.mod, regExpFolder, version
    Static regexp
    If Not regexp
      regexp = CreateRegularExpression(#PB_Any, "_[0-9]+$")
    EndIf
    
    LockMutex(mutexMods)
    ; check if "foldername" is version independend, e.g. "urbangames_vehicles_no_end_year" (no _1 at the end)
    If Not MatchRegularExpression(regexp, foldername$)
      ; "foldername" search string is NOT ending on _1 (or similar) ...
      ; add the _1 part to the foldername in a regexp and search
      regExpFolder = CreateRegularExpression(#PB_Any, "^"+foldername$+"_([0-9]+)$", #PB_RegularExpression_NoCase) ; no case only valid on Windows, but may be fixed by removing and adding mod in game
      If regExpFolder
        version = -1
        ForEach mods()
          If MatchRegularExpression(regExpFolder, MapKey(mods()))
            ; found a match, keep on searching for a higher version number (e.g.: if version _1 and _2 are found, use _2)
            ; try to extract version number
            If ExamineRegularExpression(regExpFolder, MapKey(mods()))
              If NextRegularExpressionMatch(regExpFolder)
                If Val(RegularExpressionGroup(regExpFolder, 1)) > version
                  ; if version is higher, save version and file link
                  version = Val(RegularExpressionGroup(regExpFolder, 1))
                  *mod = mods()
                EndIf
              EndIf
            EndIf
          EndIf
        Next
        FreeRegularExpression(regExpFolder)
      Else
        deb("repository:: could not create regexp "+#DQUOTE$+"^"+foldername$+"_([0-9]+)$"+#DQUOTE$+" "+RegularExpressionError())
      EndIf
    Else
      If FindMapElement(mods(), foldername$)
        *mod = mods()
      EndIf
    EndIf
    UnlockMutex(mutexMods)
    ProcedureReturn *mod
  EndProcedure
  
  Procedure isInstalled(foldername$)
    ProcedureReturn Bool(getModByFoldername(foldername$))
  EndProcedure
  
  ;- ####################
  ;- get
  
  Procedure.s modGetID(*mod.mod)
    If *mod
      ProcedureReturn *mod\tpf_id$
    EndIf
  EndProcedure
  
  Procedure.s modGetFoldername(*mod.mod)
    ; foldername = id without location information (e.g. workshop starts with *, folder name has no *
    If *mod
      If Left(*mod\tpf_id$, 1) = "*" Or Left(*mod\tpf_id$, 1) = "?"
        ProcedureReturn Mid(*mod\tpf_id$, 2)
      Else
        ProcedureReturn *mod\tpf_id$
      EndIf
    EndIf
  EndProcedure
  
  Procedure.s modGetName(*mod.mod)
    If *mod
      ProcedureReturn *mod\name$
    EndIf
  EndProcedure
  
  Procedure.s modGetVersion(*mod.mod)
    If *mod
      ProcedureReturn *mod\version$
    EndIf
  EndProcedure
  
  Procedure.s modGetDescription(*mod.mod)
    If *mod
      ProcedureReturn *mod\description$
    EndIf
  EndProcedure
  
  Procedure.s modGetAuthorsString(*mod.mod)
    Protected authors$
    Protected count, i
    Protected *author.author
    count = modCountAuthors(*mod)
    
    If count
      For i = 0 To count-1
        *author = modGetAuthor(*mod, i)
        If *author
          authors$ + *author\name$ + ", "
        EndIf
      Next
      If Len(authors$) > 2 ; remove last ", "
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
  
  Procedure.s modGetDownloadLink(*mod.mod)
    ; try to get a download link in form of source/id[/fileID]
    
    Protected source$
    Protected id.q, fileID.q
    Protected *repoFile.repository::RepositoryFile
    
    ; source saved by TPFMM during installation
    If *mod\aux\installSource$
      source$ = StringField(*mod\aux\installSource$, 1, "/")
      id      = Val(StringField(*mod\aux\installSource$, 2, "/"))
      fileID  = Val(StringField(*mod\aux\installSource$, 3, "/"))
      If source$ And id And fileID
        ProcedureReturn source$+"/"+id+"/"+fileID
      EndIf
      If source$ And id
        ProcedureReturn source$+"/"+id
      EndIf
    EndIf
    
    ; try to find a matching mod by foldername in current online sources
    *repoFile = repository::getFileByFoldername(modGetFoldername(*mod))
    If *repoFile
      ProcedureReturn *repoFile\getLink()
    EndIf
    
    ; try to build link using local information in mod.lua
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
    
    ; no link available
    ProcedureReturn ""
  EndProcedure
  
  Procedure modGetRepoMod(*mod.mod)
    Protected *repoMod
    *repoMod = repository::getModByFoldername(modGetFoldername(*mod))
    If Not *repoMod
      *repoMod  = repository::getModByLink(modGetDownloadLink(*mod))
    EndIf
    ProcedureReturn *repoMod
  EndProcedure
  
  Procedure modGetRepoFile(*mod.mod)
    Protected *repoFile
    *repoFile = repository::getFileByFoldername(modGetFoldername(*mod))
    If Not *repoFile
      *repoFile = repository::getFileByLink(modGetDownloadLink(*mod))
    EndIf
    ProcedureReturn *repoFile
  EndProcedure
  
  Procedure modGetSize(*mod.mod, refresh=#False)
    If Not *mod\aux\size Or refresh
      *mod\aux\size = misc::getDirectorySize(getModFolder(*mod\tpf_id$))
    EndIf
    ProcedureReturn *mod\aux\size
  EndProcedure
  
  Procedure.s modGetWebsite(*mod.mod)
    Protected website$, *repoMod.repository::RepositoryMod
    If *mod\url$
      website$ = *mod\url$
    ElseIf *mod\aux\tfnetID
      website$ = "https://www.transportfever.net/filebase/index.php/Entry/"+*mod\aux\tfnetID
    ElseIf *mod\aux\workshopID
      website$ = "http://steamcommunity.com/sharedfiles/filedetails/?id="+*mod\aux\workshopID
    Else
      *repoMod = modGetRepoMod(*mod)
      If *repoMod
        website$ = *repoMod\getWebsite()
      EndIf
    EndIf
    
    ProcedureReturn website$
  EndProcedure
  
  Procedure modGetTfnetID(*mod.mod)
    If *mod
      ProcedureReturn *mod\aux\tfnetID
    EndIf
  EndProcedure
  
  Procedure.q modGetWorkshopID(*mod.mod)
    If *mod
      ProcedureReturn *mod\aux\workshopID
    EndIf
  EndProcedure
  
  Procedure modGetSettings(*mod.mod, List *settings.modLuaSetting())
    If *mod
      ClearList(*settings())
      ForEach *mod\settings()
        AddElement(*settings())
        *settings() = *mod\settings()
      Next
      ProcedureReturn #True
    EndIf
  EndProcedure
  
  Procedure modGetInstallDate(*mod.mod)
    If *mod
      ProcedureReturn *mod\aux\installDate
    EndIf
  EndProcedure
  
  Procedure modGetPreviewImage(*mod.mod)
    ; the previewImages() map stores resized and centered (320x180, 16:9) versions of the original image in the mod folder (tga, jpg or png)
    Static NewMap previewImages()
    
    If Not IsImage(previewImages(*mod\tpf_id$))
      ; if image is not yet loaded
      
      Protected im.i, modFolder$
      modFolder$ = getModFolder(*mod\tpf_id$)
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
      
      ; mod images: 210x118 / 240x135 / 320x180
      ; dlc images: 120x80
      previewImages(*mod\tpf_id$) = misc::ResizeCenterImage(im, 320, 180)
    EndIf
    
    ProcedureReturn previewImages(*mod\tpf_id$)
  EndProcedure
  
  ;- ####################
  ;- set
  
  Procedure modSetName(*mod.mod, name$)
    If *mod
      *mod\name$ = name$
    EndIf
  EndProcedure
  
  Procedure modSetDescription(*mod.mod, description$)
    If *mod
      *mod\description$ = description$
    EndIf
  EndProcedure
  
  Procedure modSetMinorVersion(*mod.mod, version)
    If *mod
      *mod\minorVersion = version
    EndIf
  EndProcedure
  
  Procedure modSetHidden(*mod.mod, hidden)
    If *mod
      *mod\aux\hidden = hidden
    EndIf
  EndProcedure
  
  Procedure modSetTFNET(*mod.mod, id)
    If *mod
      *mod\aux\tfnetID = id
    EndIf
  EndProcedure
  
  Procedure modSetWorkshop(*mod.mod, id.q)
    If *mod
      *mod\aux\workshopID = id
    EndIf
  EndProcedure
  
  Procedure modSetLuaDate(*mod.mod, date)
    If *mod
      *mod\aux\luaDate = date
    EndIf
  EndProcedure
 
  Procedure modSetLuaLanguage(*mod.mod, language$)
    If *mod
      *mod\aux\luaLanguage$ = language$
    EndIf
  EndProcedure
  
  
  ;- ####################
  ;- add / clear / sort
  
  Procedure modAddAuthor(*mod.mod)
    Protected *author.author
    If *mod
      *author = AddElement(*mod\authors())
      ProcedureReturn *author
    EndIf
  EndProcedure
  
  Procedure modClearAuthors(*mod.mod)
    If *mod
      ClearList(*mod\authors())
    EndIf
  EndProcedure
  
  Procedure modAddTag(*mod.mod, tag$)
    If *mod
      AddElement(*mod\tags$())
      *mod\tags$() = tag$
    EndIf
  EndProcedure
  
  Procedure modClearTags(*mod.mod)
    If *mod
      ClearList(*mod\tags$())
    EndIf
  EndProcedure
  
  Procedure modAddDependency(*mod.mod, dependency$)
    If *mod
      AddElement(*mod\dependencies$())
      *mod\dependencies$() = dependency$
    EndIf
  EndProcedure
  
  Procedure modClearDependencies(*mod.mod)
    If *mod
      ClearList(*mod\dependencies$())
    EndIf
  EndProcedure
  
  Procedure modAddSetting(*mod.mod)
    Protected *setting
    If *mod
      *setting = AddElement(*mod\settings())
      ProcedureReturn *setting
    EndIf
  EndProcedure
  
  Procedure modClearSettings(*mod.mod)
    If *mod
      ClearList(*mod\settings())
    EndIf
  EndProcedure
  
  Procedure modSortSettings(*mod.mod)
    If *mod
      SortStructuredList(*mod\settings(), #PB_Sort_Ascending, OffsetOf(modLuaSetting\order), TypeOf(modLuaSetting\order))
    EndIf
  EndProcedure
  
  
  ;- ####################
  ;- check
  
  Procedure modIsVanilla(*mod.mod) ; check whether id$ belongs to official mod
    Static NewMap vanillaMods()
    If MapSize(vanillaMods()) = 0
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_01_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_02_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_03_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_03_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_04_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_05_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_06_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_eu_mission_07_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_01_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_02_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_03_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_04_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_05_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_06_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_campaign_usa_mission_07_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_no_costs_1", #PB_Map_NoElementCheck)
      AddMapElement(vanillaMods(), "urbangames_vehicles_no_end_year_1", #PB_Map_NoElementCheck)
    EndIf
    *mod\aux\isVanilla = Bool(FindMapElement(vanillaMods(), *mod\tpf_id$))
    ProcedureReturn *mod\aux\isVanilla
  EndProcedure
  
  Procedure modIsWorkshop(*mod.mod)
    ProcedureReturn Bool(Left(*mod\tpf_id$, 1) = "*")
  EndProcedure
  
  Procedure modIsStagingArea(*mod.mod)
    ProcedureReturn Bool(Left(*mod\tpf_id$, 1) = "?")
  EndProcedure
  
  Procedure modIsHidden(*mod.mod)
    If *mod
      ProcedureReturn *mod\aux\hidden
    EndIf
  EndProcedure
  
  Procedure modIsUpdateAvailable(*mod.mod) 
    ; TODO modIsUpateAvailable()
    Protected compare, *repo_mod.repository::RepositoryMod
    
;     todo repo mods Not yet threadsafe... cannot access repo mods While repositories are loaded
    
    *repo_mod = modGetRepoMod(*mod)
    
    If Not *repo_mod
      ; no online mod found -> no update available
      ProcedureReturn #False
    EndIf
    
    If settings::getInteger("", "compareVersion") And *repo_mod\getVersion()
      ; use alternative comparison method: version check
      compare = Bool(*repo_mod\getVersion() And *mod\version$ And ValD(*mod\version$) < ValD(*repo_mod\getVersion()))
    Else
      ; default compare: date check
      compare = Bool((*mod\aux\repoTimeChanged And *repo_mod\getTimeChanged() > *mod\aux\repoTimeChanged) Or
                     (*mod\aux\installDate And *repo_mod\getTimeChanged() > *mod\aux\installDate))
    EndIf
    ProcedureReturn compare
  EndProcedure
  
  Procedure modCanBackup(*mod.mod)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    If *mod\aux\isVanilla
      ProcedureReturn #False
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure modCanUninstall(*mod.mod)
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
  
  Procedure modHasSettings(*mod.mod)
    If *mod
      If ListSize(*mod\settings())
        ProcedureReturn #True
      EndIf
    EndIf
  EndProcedure
  
  ;- ####################
  ;- other
  
  Procedure modCountAuthors(*mod.mod)
    Protected count.i
    LockMutex(mutexModAuthors)
    count = ListSize(*mod\authors())
    UnlockMutex(mutexModAuthors)
    ProcedureReturn count
  EndProcedure
  
  Procedure modGetAuthor(*mod.mod, n.i)
    ; extract author #n from the list and save in *author
    Protected *author
    LockMutex(mutexModAuthors)
    If n <= ListSize(*mod\authors()) - 1
      *author= SelectElement(*mod\authors(), n)
    EndIf
    UnlockMutex(mutexModAuthors)
    ProcedureReturn *author
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
  
  ;- ####################
  ;- ####################
  
  
  ;- Load and Save
  
  Procedure doLoad() ; load mod list from file and scan for installed mods
    isLoaded = #False
    
    Protected json, NewMap mods_json.mod(), *mod.mod
    Protected dir, entry$
    Protected NewMap scanner()
    Protected count, n, id$, modFolder$, luaFile$
    
    LockMutex(mutexMods)
    
    defineFolder()
    
    
    postProgressEvent(0, locale::l("progress", "load"))
;     windowMain::progressMod(0, locale::l("progress","load")) ; 0%
    
    ; load list from json file
    json = LoadJSON(#PB_Any, pTPFMM$ + "mods.json")
    If json
      ExtractJSONMap(JSONValue(json), mods_json())
      FreeJSON(json)
      
      ForEach mods_json()
        id$ = MapKey(mods_json())
        AddMapElement(mods(), id$)
        *mod = mods() ; work in pointer, manipulates also data in the map
        CopyStructure(mods_json(), *mod, mod)
        modInit(*mod)
        ; debugger::add("mods::doLoad() - address {"+*mod+"} - id {"+*mod\tpf_id$+"} - name {"+*mod\name$+"}")
      Next
      
      deb("mods:: loaded "+MapSize(mods_json())+" mods from mods.json")
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
    deb("mods:: scan mods folder {"+pMods$+"}")
    dir = ExamineDirectory(#PB_Any, pMods$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If modCheckID(entry$) And modCheckValidTPF(pMods$ + entry$)
          scanner(entry$) = #True
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ;scan pWorkshop
    deb("mods:: scan workshop folder {"+pWorkshop$+"}")
    dir = ExamineDirectory(#PB_Any, pWorkshop$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If modCheckWorkshopID(entry$)
          If modCheckValidTPF(pWorkshop$ + entry$)
            ; workshop mod folders only have a number.
            ; Add * as prefix and _1 as postfix
            scanner("*"+entry$+"_1") = #True
          EndIf
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ;scan pStagingArea
    deb("mods:: scan staging area folder {"+pStagingArea$+"}")
    dir = ExamineDirectory(#PB_Any, pStagingArea$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If modCheckID(entry$)
          ; staging area mod have to comply to format (name_version)
          ; Add ? as prefix
          scanner("?"+entry$) = #True
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ;}
    ; scanning finished - now check if new mods have been added or mods have been removed
    
    
    ; first check:  deleted mods
    deb("mods:: check for removed mods")
    ForEach mods()
      If Not FindMapElement(scanner(), MapKey(mods()))
        deb("mods:: remove {"+MapKey(mods())+"} from list (folder removed)")
        DeleteMapElement(mods())
      EndIf
    Next
    
    
    ; second check: existing & added mods
    count = MapSize(scanner())
    n = 0
    deb("mods:: found "+MapSize(scanner())+" mods in folders")
    If count > 0
      ForEach scanner() ; for each mod found in any of the known mod folders:
        n + 1 ; update progress bar
;         windowMain::progressMod(100*n/count)
        postProgressEvent(100*n/count)
        
        id$ = MapKey(scanner())
        
        If FindMapElement(mods(), id$)
          ; select existing element or
          *mod = mods()
        Else
          ; create new element
          *mod = modAddtoMap(id$)
        EndIf
        
        modLoadInfo(*mod)
        
        If *mod\name$ = ""
          deb("mods:: no name for mod {"+id$+"}")
        EndIf
      Next
    EndIf
    
    
    ; Final Check and display
    If callbackStopDraw
      callbackStopDraw(#True)
    EndIf
    If events(#EventStopDraw)
      PostEvent(events(#EventStopDraw), #True, 0)
    EndIf
    
    ; loop all mods
    ForEach mods()
      *mod = mods()
      If *mod\tpf_id$ = "" Or MapKey(mods()) = ""
        deb("mods:: mod without ID in list: key={"+MapKey(mods())+"} tf_id$={"+*mod\tpf_id$+"}")
        End
      EndIf
      
      If Not *mod\aux\installDate
        *mod\aux\installDate = Date()
      EndIf
      
      ; Display mods in list gadget
      If callbackNewMod
        callbackNewMod(*mod)
      EndIf
      If events(#EventNewMod)
        PostEvent(events(#EventNewMod), *mod, 0)
      EndIf
    Next
      
    If callbackStopDraw
      callbackStopDraw(#False)
    EndIf
    If events(#EventStopDraw)
      PostEvent(events(#EventStopDraw), #False, 0)
    EndIf
    
    postProgressEvent(-1, locale::l("progress", "loaded"))
;     windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","loaded"))
    
    UnlockMutex(mutexMods)
    
    isLoaded = #True
  EndProcedure
  
  Procedure saveList()
    deb("mods:: saveList")
    
    If Not isLoaded
      ; do not save list when it is not loaded
      ProcedureReturn #False
    EndIf
    
    If settings::getString("","path") = ""
      deb("mods:: game dir not defined")
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
  
  ;- mod handling
  
  Procedure.s generateNewID(*mod.mod) ; return new ID as string
    Protected author$, name$, version$
    Protected *author.author
    ; ID = author_mod_version
    
    Static RegExpNonAlphaNum
    If Not RegExpNonAlphaNum
      RegExpNonAlphaNum  = CreateRegularExpression(#PB_Any, "[^a-z0-9]") ; non-alphanumeric characters
      ; regexp matches all non alphanum characters, including spaces etc.
    EndIf
    
    With *mod
      *author = modGetAuthor(*mod, 0)
      If *author
        author$ = ReplaceRegularExpression(RegExpNonAlphaNum, LCase(*author\name$), "") ; remove all non alphanum + make lowercase
      Else
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
  
  ;- actions
  
  Procedure doInstall(file$) ; install mod from file (archive)
    deb("mods::doInstall("+file$+")")
    
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
      deb("mods:: {"+file$+"} does not exist or is empty")
      ProcedureReturn #False
    EndIf
    
    postProgressEvent(20, locale::l("progress", "install"))
;     windowMain::progressMod(20, locale::l("progress", "install"))
    
    ; 1) extract to temp directory (in TPF folder: /Transport Fever/TPFMM/temp/)
    ; 2) check extracted files and format
    ; 3) if not correct, delete folder and cancel install
    ;    if correct, move whole folder to mods/ or dlc/ (depending on type)
    ; 4) save information to list for faster startup of TPFMM
    
    
    ; (1) extract files to temp
    source$ = file$
    target$ = misc::Path(settings::getString("","path")+"/TPFMM/install/"+GetFilePart(file$, #PB_FileSystem_NoExtension)+"/")
    
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
        deb("mods:: failed to extract files from {"+source$+"} to {"+target$+"}")
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        
        postProgressEvent(-1, locale::l("progress","install_fail"))
;         windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","install_fail"))
        ProcedureReturn #False
    EndIf
    
    ; archive is extracted to target$
    ; (2) try to find mod in target$ (may be in some sub-directory)...
    
    postProgressEvent(40)
;     windowMain::progressMod(40)
    modRoot$ = modGetRoot(target$)
    
    If modRoot$ = ""
      deb("mods:: getModRoot("+target$+") failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      postProgressEvent(-1, locale::l("progress","install_fail"))
;       windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","install_fail"))
      ProcedureReturn #False
    EndIf
    
    ; modRoot folder found. 
    ; try to get ID from folder name
    id$ = misc::getDirectoryName(modRoot$)
    
    If Not modCheckID(id$) And modCheckWorkshopID(id$)
      ; backuped mods from workshop only have number, add _1
      id$ = id$ + "_1"
    EndIf
    
    If Not modCheckID(id$)
      deb("mods:: folder name not valid id ("+id$+")")
      
      ; try to get ID from archive file name
      id$ = GetFilePart(source$, #PB_FileSystem_NoExtension)
      If Not modCheckID(id$)
        deb("mods:: archive name not valid id ("+id$+")")
        ;TODO backuped archives are "folder_id.<date>.zip" -> remove .<date> part to get ID?
        
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        postProgressEvent(-1, locale::l("progress","install_fail_id"))
;         windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","install_fail_id"))
        ProcedureReturn #False
      EndIf
    EndIf
    
    
    modFolder$ = getModFolder(id$)
    
    ; check if mod already installed?
    LockMutex(mutexMods)
    *installedMod = FindMapElement(mods(), id$)
    UnlockMutex(mutexMods)
    
    If *installedMod
      deb("mods:: mod {"+id$+"} is already installed, overwrite with new mod")
      
      ; backup before overwrite with new mod if activated in settings...
      If settings::getInteger("backup", "before_update")
        doBackup(id$)
      EndIf
      
      If Not modCanUninstall(*installedMod)
        deb("mods:: existing mod MUST NOT be uninstalled, still continue with overwrite...")
      EndIf
      
      If callbackRemoveMod
        callbackRemoveMod(*installedMod) ; send pointe for removal, attention: pointer already invalid
      EndIf
      If events(#EventRemoveMod)
        PostEvent(events(#EventRemoveMod), *installedMod, 0)
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
    postProgressEvent(60)
;     windowMain::progressMod(60)
    If Not RenameFile(modRoot$, modFolder$) ; RenameFile also works with directories!
      deb("mods:: could not move directory to {"+modFolder$+"}")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      postProgressEvent(-1, locale::l("progress", "install_fail"))
;       windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","install_fail"))
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
    postProgressEvent(80)
;     windowMain::progressMod(80)
    *mod = modAddtoMap(id$)
    modLoadInfo(*mod)
    *mod\aux\installDate = Date()
    
    ; is mod installed from a repository? -> read .meta file
    If FileSize(file$+".meta") > 0
      ;-WIP! (load repository meta data...)
      ;TODO change to direct passing of information via function parameter?
      ; pro of using file: information is also used when installing the file manually. (manually drag&drop from "download/" folder)
      ; read info from meta file and add information to file reference...
      ; IMPORTANT: tpfnetID / workshop id!
      json = LoadJSON(#PB_Any, file$+".meta")
      If json
;         Protected repo_mod.repository::mod
;         If JSONType(JSONValue(json)) = #PB_JSON_Object
;           ExtractJSONStructure(JSONValue(json), repo_mod, repository::mod)
;           FreeJSON(json)
;           *mod\aux\repoTimeChanged = repo_mod\timechanged
;           *mod\aux\installSource$ = repo_mod\installSource$
;           Select repo_mod\source$
;             Case "tpfnet"
;               *mod\aux\tfnetID = repo_mod\id
;             Case "workshop"
;               *mod\aux\workshopID = repo_mod\id
;             Default
;               
;           EndSelect
;           ; other idea: mod\repositoryinformation = copy of repo info during time of installation/download
;           ; later: when checking for update: compare repositoryinformation stored in mod with current information in repository.
;         EndIf
        FreeJSON(json)
      EndIf
      ; could read more information... (author, thumbnail, etc...)
      ; delete files from download directory? -> for now, keep as backup / archive
    EndIf
    
    ; finish installation
    postProgressEvent(-1, locale::l("progress", "installed"))
;     windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress","installed"))
    deb("mods:: finish installation...")
    DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
    
    ; callback add mod
    
    If callbackNewMod
      callbackNewMod(*mod)
    EndIf
    If events(#EventNewMod)
      PostEvent(events(#EventNewMod), *mod, 0)
    EndIf
    
    ; start backup if required
    If settings::getInteger("backup", "after_install")
      backup(id$)
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure doUninstall(id$) ; remove from Train Fever Mod folder
    deb("mods::doUninstall("+id$+")")
    
    
    Protected *mod.mod
    LockMutex(mutexMods)
    *mod = FindMapElement(mods(), id$)
    UnlockMutex(mutexMods)
    
    If Not *mod
      deb("mods:: cannot find *mod in list")
      ProcedureReturn #False
    EndIf
    
    If Not modCanUninstall(*mod)
      deb("mods:: can not uninstall {"+id$+"}")
      ProcedureReturn #False
    EndIf
    
    If settings::getInteger("backup", "before_uninstall")
      doBackup(id$)
    EndIf
    
    
    Protected modFolder$
    modFolder$ = getModFolder(id$)
    
    deb("mods:: delete {"+modFolder$+"} and all subfolders")
    DeleteDirectory(modFolder$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
    
    DeleteMapElement(mods())
    
    postProgressEvent(-1, locale::l("management", "uninstall_done"))
;     windowMain::progressMod(windowMain::#Progress_Hide, locale::l("management", "uninstall_done"))
    
    ; callback remove mod
    If callbackRemoveMod
      callbackRemoveMod(*mod) ; send pointe for removal, attention: pointer already invalid
    EndIf
    If events(#EventRemoveMod)
      PostEvent(events(#EventRemoveMod), *mod, 0)
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure doBackup(id$)
    deb("mods::doBackup("+id$+")")
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
      deb("mods:: cannot find mod {"+id$+"}")
      _backupActive = #False
      ProcedureReturn #False
    EndIf
    
    
    If FileSize(backupFolder$) <> -2
      deb("mods:: target directory does not exist {"+backupFolder$+"}")
      _backupActive = #False
      ProcedureReturn #False
    EndIf
    
    modFolder$ = getModFolder(id$)
    
    If FileSize(modFolder$) <> -2
      deb("mods:: mod directory does not exist {"+modFolder$+"}")
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
    postProgressEvent(90,  locale::getEx("progress", "backup_mod", strings$()))
;     windowMain::progressMod(80, locale::getEx("progress", "backup_mod", strings$()))
    
    If archive::pack(backupFile$, modFolder$)
      deb("mods::doBackup() - success")
      *mod\aux\backup\time = Date()
      *mod\aux\backup\filename$ = GetFilePart(backupFile$)
      
      ;TODO check for older backups with identical checksum...
      
      ; save mod information with the backup file
      Protected json
      Protected backupInfo.backupInfo
      json = CreateJSON(#PB_Any)
      If json
        backupInfo\name$      = *mod\name$
        backupInfo\version$   = *mod\version$
        backupInfo\author$    = modGetAuthorsString(*mod)
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
        deb("mods:: failed to create backup meta data file: "+backupInfoFile$)
      EndIf
      
      ; finished
      postProgressEvent(-1, locale::l("progress", "backup_fin"))
;       windowMain::progressMod(windowMain::#Progress_Hide, )
      _backupActive = #False
      ProcedureReturn #True
    Else
      deb("mods:: backup failed")
      postProgressEvent(-1, locale::l("progress", "backup_fail"))
;       windowMain::progressMod(windowMain::#Progress_Hide, locale::l("progress", "backup_fail"))
      _backupActive = #False
      ProcedureReturn #False
    EndIf
    
  EndProcedure
  
  Procedure doUpdate(id$)
    deb("mods::doUpdate("+id$+")")
    
    Protected *mod.mod
    Protected *repoMod.repository::RepositoryMod
    Protected *repoFile.repository::RepositoryFile
    
    LockMutex(mutexMods)
    *mod = FindMapElement(mods(), id$)
    UnlockMutex(mutexMods)
    
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    ; try to find direct repo file downlaod by file ID
    ; attention: if multiple online files available for same foldername, only one is returned!
    ; TODO change which file/mod is returned, e.g. by using the latest (by date)?
    *repoFile = modGetRepoFile(*mod)
    If *repoFile
      ProcedureReturn *repoFile\download() ; starts download in new thread
    EndIf
    
    ; if no direct file is found, try to find the mod (which may have multiple files as selction for the user)
    *repoMod = modGetRepoMod(*mod)
    If *repoMod
      ProcedureReturn *repoMod\download() ; direct download or show user selection for file to download
    EndIf
    
    ProcedureReturn #False
  EndProcedure
  
  ;- actions (public)
  
  Procedure load(async=#True)
    If async
      addToQueue(#QUEUE_LOAD)
    Else
      doLoad()
    EndIf
  EndProcedure
  
  Procedure install(file$) ; check and extract archive to game folder
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
  
  Procedure generateID(*mod.mod, id$ = "")
    deb("mods::generateID("+Str(*mod)+", "+id$+")")
    Protected author$, name$, version$
    
    If Not *mod
      ProcedureReturn
    EndIf
    
    With *mod
      If id$
        ; this id$ is passed through, extracted from subfolder name
        ; if it is present, check if it is well-defined
        If modCheckID(id$)
          \tpf_id$ = id$
          ; id read from mod folder was valid, thus use it directly
          ProcedureReturn #True
        EndIf
      EndIf
      
      \tpf_id$ = LCase(\tpf_id$)
      
      ; Check if ID already correct
      If \tpf_id$ And modCheckID(\tpf_id$)
        deb("mods::generateID() - ID {"+\tpf_id$+"} (from structure)")
        ProcedureReturn #True
      EndIf
      
      ; Check if ID in old format
      author$   = StringField(\tpf_id$, 1, ".")
      name$     = StringField(\tpf_id$, CountString(\tpf_id$, ".")+1, ".")
      version$  = Str(Abs(Val(StringField(\version$, 1, "."))))
      \tpf_id$ = author$ + "_" + name$ + "_" + version$
      
      If \tpf_id$ And modCheckID(\tpf_id$)
        deb("mods::generateID() - ID {"+\tpf_id$+"} (converted from old TFFMM-id)")
        ProcedureReturn #True
      EndIf
      
      \tpf_id$ = generateNewID(*mod)
      
      If \tpf_id$ And modCheckID(\tpf_id$)
        deb("mods::generateID() - ID {"+\tpf_id$+"} (generated by TPFMM)")
        ProcedureReturn #True
      EndIf
    EndWith
    
    deb("mods:: no ID generated")
    ProcedureReturn #False
  EndProcedure
  
  Procedure.s getLUA(*mod.mod)
    
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

  ;- backup stuff
  
  Procedure backupCleanFolder()
    Protected backupFolder$, infoFile$, zipFile$, entry$
    Protected dir, json, writeInfo
    Protected NewList backups.backupInfo()
    
    If settings::getString("","path") = ""
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
    
    ClearList(backups())
    
    If settings::getString("","path") = ""
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
  
  ;- Callback
  
  Procedure BindEventCallback(Event, *callback)
    Select event
      Case #EventNewMod
        callbackNewMod = *callback
      Case #EventRemoveMod
        callbackRemoveMod = *callback
      Case #EventStopDraw
        callbackStopDraw = *callback
    EndSelect
  EndProcedure
  
  Procedure BindEventPost(ModEvent, WindowEvent, *callback)
    If ModEvent >= 0 And ModEvent <= ArraySize(events())
      events(ModEvent) = WindowEvent
      If *callback
        BindEvent(WindowEvent, *callback)
      EndIf
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
EndModule
