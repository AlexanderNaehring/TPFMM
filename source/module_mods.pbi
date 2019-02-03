XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_luaParser.pbi"
XIncludeFile "module_archive.pbi"

XIncludeFile "module_mods.h.pbi"

Module mods
  UseModule debugger
  UseModule locale
  
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
    Data.i @modIsDecrepated()
    Data.i @modIsLuaError()
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
    
    vtBackup:
    Data.i @backupGetFilename()
    Data.i @backupGetFoldername()
    Data.i @backupGetName()
    Data.i @backupGetVersion()
    Data.i @backupGetAuthors()
    Data.i @backupGetDate()
    Data.i @backupIsInstalled()
    Data.i @backupInstall()
    Data.i @backupDelete()
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
;     backup.backup     ; backup information (local)
    luaParseError.b   ; set true if parsing of mod.lua failed
    deprecated.b      ; set true if no mod.lua found or otherwise incorrect mod format
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
  
  Structure backupInfo
    filename$
    tpf_id$
    name$
    version$
    author$
    time.i
    size.q
    checksum$
  EndStructure
  
  Structure backup
    vt.BackupMod
    info.backupInfo
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
  Global semaphoreBackup  = CreateSemaphore(1) ; max number of concurrent backups
  Global threadQueue
  Global NewMap mods.mod()
  Global NewMap backups.backup()
  Global NewList queue.queue()
  Global isLoaded.b
  Global exit.b
  
  Global callbackNewMod.callbackNewMod
  Global callbackRemoveMod.callbackRemoveMod
  Global callbackStopDraw.callbackStopDraw
  Global callbackNewBackup.callbackNewbackup
  Global callbackRemoveBackup.callbackRemovebackup
  Global callbackClearBackups.callbackClearBackups
  
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
  
  Enumeration
    #FolderGame
    #FolderTPFMM
    #FolderMods
    #FolderWorkshop
    #FolderStagingArea
  EndEnumeration
    
  Procedure.s getFolder(folder.b)
    Protected gameDirectory$
    gameDirectory$ = settings::getString("", "path")
    Select folder
      Case #FolderGame
        ProcedureReturn misc::Path(gameDirectory$)
      Case #FolderTPFMM
        ProcedureReturn misc::Path(gameDirectory$ + "/TPFMM/")
      Case #FolderMods
        ProcedureReturn misc::Path(gameDirectory$ + "/mods/")
      Case #FolderWorkshop
        ProcedureReturn misc::Path(gameDirectory$ + "/../../workshop/content/446800/")
      Case #FolderStagingArea
        ProcedureReturn misc::Path(gameDirectory$ + "/userdata/staging_area/")
      Default
        deb("mods:: unkown folder id: getFolder("+folder+")")
    EndSelect
  EndProcedure
  
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
    If id$ = ""
      ProcedureReturn getFolder(#FolderMods)
    EndIf
    
    If Left(id$, 1) = "*"
      ProcedureReturn getFolder(#FolderWorkshop) + Mid(id$, 2, Len(id$)-3) + #PS$
    ElseIf Left(id$, 1) = "?"
      ProcedureReturn getFolder(#FolderStagingArea) + Mid(id$, 2) + #PS$
    Else
      ProcedureReturn getFolder(#FolderMods) + id$ + #PS$
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
  
  Procedure modCheckRoot(path$)
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
    
    If FileSize(path$ + "mod.lua") > 0
      ProcedureReturn #True
    EndIf
    deb("mods:: {"+path$+"} has no mod.lua")
    
    ; every mod should have a mod.lua file
    ; if not, may still be a mod with deprecated mod format:
    
    ; folder has res/ folder, may be a TF mod
    If FileSize(path$ + "res") = -2
      ProcedureReturn #True
    EndIf
    deb("mods:: {"+path$+"} has not mod.lua")
    
    If FileSize(path$ + "info.lua") > 0 ; old TF mod
      ProcedureReturn #True
    EndIf
    deb("mods:: {"+path$+"} has no info.lua")
    
    
    If FileSize(path$ + "tfmm.ini") > 0
      ProcedureReturn #True
    EndIf
    deb("mods:: {"+path$+"} is not a TPF or TF mod")
    
  EndProcedure
  
  Procedure.s modGetRoot(path$) ; try to find mod.lua to determine the root location of the mod
    Protected dir
    Protected entry$, result$
    path$ = misc::path(path$)
    
    dir = ExamineDirectory(#PB_Any, path$, "")
    If dir
      While NextDirectoryEntry(dir)
        entry$ = DirectoryEntryName(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_Directory
          If entry$ = "." Or entry$ = ".."
            Continue
          EndIf
          If #False ; entry$ = "res" ; must have any info file!
            FinishDirectory(dir)
            ProcedureReturn path$
          Else ; any directory > recurse
            result$ = modGetRoot(path$ + entry$)
            If result$
              FinishDirectory(dir)
              ProcedureReturn result$
            EndIf
          EndIf
        Else ; file
          If entry$ = "mod.lua" Or  ; tpf mod
             entry$ = "info.lua" Or ; tf mod (new)
             entry$ = "tfmm.ini"    ; tf mod (old)
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
    
    ; for all mods found in folder: get location of folder and check mod.lua for changes
    ; folder may be workshop, mods/ or dlcs/
    modFolder$ = getModFolder(id$)
    
    If FileSize(modFolder$ + "mod.lua") > 0
      luaFile$ = modFolder$ + "mod.lua"
      *mod\aux\deprecated = #False
    ElseIf FileSize(modFolder$ + "info.lua") > 0
      luaFile$ = modFolder$ + "info.lua"
      *mod\aux\deprecated = #True
    Else
      ; no mod.lua or info.lua
      *mod\aux\deprecated = #True
      If FileSize(modFolder$ + "tfmm.ini")
        If OpenPreferences(modFolder$ + "tfmm.ini")
          *mod\name$ = ReadPreferenceString("name", "")
          *mod\version$ = ReadPreferenceString("version", "")
          ClearList(*mod\authors())
          AddElement(*mod\authors())
          *mod\authors()\name$ = ReadPreferenceString("author", "")
          If *mod\authors()\name$ = ""
            ClearList(*mod\authors())
          EndIf
          ClosePreferences()
        EndIf
      EndIf
    EndIf
    
    If luaFile$
      ; read mod.lua (or info.lua) if required
      If *mod\name$ = "" Or                                                 ; no name
         *mod\aux\luaDate <> GetFileDate(luaFile$, #PB_Date_Modified) Or    ; mod.lua modified
         *mod\aux\sv <> #SCANNER_VERSION Or                                 ; new program version
         *mod\aux\luaLanguage$ <> locale::getCurrentLocale()                ; language changed
        ; load info from mod.lua
        *mod\aux\luaParseError = #False
        If luaParser::parseModLua(luaFile$, *mod)
          *mod\aux\sv = #SCANNER_VERSION
          modInfoProcessing(*mod)
        Else
          *mod\aux\luaParseError = #True
        EndIf
        
        If *mod\name$ = ""
          deb("mods:: mod {"+id$+"} has no name")
        EndIf
      EndIf
    Else
      deb("mods:: no mod.lua for mod {"+id$+"} found!")
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
    
    If FileSize(modFolder$ + "mod.lua") <= 0
      ;TODO maybe write mod.lua file to increase compatibility with game?
    EndIf
  EndProcedure
  
  Procedure modClearInfo(*mod.mod)
    ; clean info
    ClearStructure(*mod, mod)
    InitializeStructure(*mod, mod)
  EndProcedure
  
  
  Procedure backupsReadBackupInformation(filename$, root$="")
    Protected *this.backup
    Protected json
    
    If root$ = ""
      root$ = backupsGetFolder()
    EndIf
    root$ = misc::path(root$)
    
    If FindMapElement(backups(), filename$)
      deb("mods:: backupLoadList() backup file "+filename$+" already in map")
      DebuggerError("this should not happen")
      ; TODO: use md5 fingerprint as key instead of filename
    Else
      AddMapElement(backups(), filename$, #PB_Map_ElementCheck)
    EndIf
    *this = backups()
    *this\vt = ?vtBackup
    
    json = LoadJSON(#PB_Any, root$ + filename$ + ".backup")
    If json
      ExtractJSONStructure(JSONValue(json), *this\info, backupInfo)
      FreeJSON(json)
    Else
      deb("mods:: backup scan not able to open metadata file for "+filename$)
    EndIf
    
    With *this\info
      If \filename$ <> filename$
        deb("mods:: file was moved after backup: "+filename$+"")
        ;TODO fix information?
      EndIf
      \filename$ = filename$
      If Not \size
        \size = FileSize(backupsGetFolder() + filename$)
      EndIf
      If \tpf_id$ = ""
        \tpf_id$ = StringField(GetFilePart(filename$, #PB_FileSystem_NoExtension), 1, ".")
      EndIf
    EndWith
      
    If callbackNewBackup : callbackNewBackup(*this) : EndIf
    If events(#EventNewBackup) : PostEvent(events(#EventNewBackup), *this, 0) : EndIf
  EndProcedure
  
  Procedure backupsScanRecursive(root$, folder$="")
    Protected dir, json
    Protected filename$
    Protected *this.backup
    Protected num
    
    root$ = misc::path(root$)
    folder$ = misc::path(folder$)
    
    dir = ExamineDirectory(#PB_Any, root$ + folder$, "")
    If dir
      While NextDirectoryEntry(dir)
        Select DirectoryEntryType(dir)
          Case #PB_DirectoryEntry_Directory
            If DirectoryEntryName(dir) = "." Or DirectoryEntryName(dir) = ".."
              Continue
            EndIf
            backupsScanRecursive(root$, folder$ + DirectoryEntryName(dir))
            num + 1
            
          Case #PB_DirectoryEntry_File
            num + 1
            filename$ = folder$ + DirectoryEntryName(dir)
            If LCase(GetExtensionPart(filename$)) <> "zip"
              Continue
            EndIf
            
            backupsReadBackupInformation(filename$, root$)
        EndSelect
      Wend
      FinishDirectory(dir)
      If Not num
        deb("mods:: delete empty backup folder " + root$ + folder$)
        DeleteDirectory(root$ + folder$, "")
      EndIf
      
    Else
      deb("mods:: failed to examine backup directory " + root$ + folder$)
    EndIf
  EndProcedure
  
  Procedure backupsClearFolderRecursive(folder$)
    Protected dir, file$, ext$
    Protected json, info.backupInfo, time
    Protected autoDeleteDays, backupAgeInDays
    
    folder$ = misc::path(folder$)
    dir = ExamineDirectory(#PB_Any, folder$, "")
    If dir
      While NextDirectoryEntry(dir)
        Select DirectoryEntryType(dir)
          Case #PB_DirectoryEntry_Directory
            If DirectoryEntryName(dir) = "." Or DirectoryEntryName(dir) = ".."
              Continue
            EndIf
            backupsClearFolderRecursive(folder$ + DirectoryEntryName(dir))
            
          Case #PB_DirectoryEntry_File
            file$ = folder$ + DirectoryEntryName(dir)
            ext$ = LCase(GetExtensionPart(file$))
            Select ext$
              Case "zip"
                
              Case "backup"
                Continue 
              Default
                DebuggerWarning("file of unknown file type in backup folder: "+file$)
                Continue
            EndSelect
            
            ;TODO delete all files that are not .zip or .backup (?)
            
            ;TODO delete backup files without zip
            
            ;TODO delete empty folders
            
            
            ; read backup file
            json = LoadJSON(#PB_Any, file$+".backup")
            If json
              ExtractJSONStructure(JSONValue(json), @info, backupInfo)
              FreeJSON(json)
              time = info\time
            Else
              deb("mods:: could not read "+file$+".backup")
              time = DirectoryEntryDate(dir, #PB_Date_Modified)
            EndIf
            
            ; delete old backups
            autoDeleteDays = settings::getInteger("backup", "auto_delete_days")
            If autoDeleteDays 
              backupAgeInDays = (misc::time() - time)/86400
              If backupAgeInDays > autoDeleteDays
                deb("mods:: backup "+file$+" is "+backupAgeInDays+" days old, automatically delete backups after "+autoDeleteDays+" days. Backup will be removed now.")
                DeleteFile(file$, #PB_FileSystem_Force)
                DeleteFile(file$+".backup", #PB_FileSystem_Force)
              EndIf
            EndIf
            
        EndSelect
      Wend
      FinishDirectory(dir)
    Else
      deb("mods:: failed to examine backup directory "+folder$)
    EndIf
    
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
  
  
  ;- ####################
  ;-       PUBLIC 
  ;- ####################
  
  
  ; functions working on individual mods
  
  Procedure getModByID(id$, exactMatch.b=#True) ; ID = foldername with prefix for folder location and postfix for version, e.g. *123456789_1 for a steam mod
    Protected *mod.mod, foldername$
    
    LockMutex(mutexMods)
    If FindMapElement(mods(), id$)
      *mod = mods()
    EndIf
    If Not *mod And Not exactMatch
      ; if searching for a steam mod (*123456_1) and exactMatch = #false, also find the manual version (123456_1) and vice versa
      If Left(id$, 1) = "*" Or Left(id$, 1) = "?"
        ; if searching for a prefix (workshop or staging area mod), remove prefix and search again
        foldername$ = Mid(id$, 2)
        If FindMapElement(mods(), foldername$)
          *mod = mods()
        EndIf
      Else
        ; if id$ had no prefix, use identical
        foldername$ = id$
      EndIf
      
      If Not *mod
        ; foldername$ has no prefix, search in installed mods without prefix as well
        ForEach mods()
          If modGetFoldername(mods()) = foldername$
            *mod = mods()
            Break
          EndIf
        Next
      EndIf
    EndIf
    UnlockMutex(mutexMods)
    ProcedureReturn *mod
  EndProcedure
  
  Procedure isInstalled(id$)
    ProcedureReturn Bool(getModByID(id$))
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
    If modCheckID(*mod\tpf_id$)
      ProcedureReturn *mod\name$
    Else
      ProcedureReturn *mod\name$+" ***" ; mod folder deprecated!
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
  
  Procedure modIsDecrepated(*mod.mod)
    ProcedureReturn *mod\aux\deprecated
  EndProcedure
  
  Procedure modIsLuaError(*mod.mod)
    ProcedureReturn *mod\aux\luaParseError
  EndProcedure
  
  Procedure modIsUpdateAvailable(*mod.mod) 
    Protected compare, *repo_mod.repository::RepositoryMod
    ; todo modIsUpdateAvailable() not yet threadsafe... cannot access repo mods while repositories are loaded
    
    If modIsWorkshop(*mod)
      ProcedureReturn #False
    EndIf
    
    *repo_mod = modGetRepoMod(*mod)
    If Not *repo_mod
      ProcedureReturn #False
    EndIf
    
    
    If settings::getInteger("", "compareVersion") And *repo_mod\getSource() <> "workshop" And *repo_mod\getVersion()
      compare = Bool(*repo_mod\getVersion() And *mod\version$ And ValD(*mod\version$) < ValD(*repo_mod\getVersion()))
    Else
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
    
    postProgressEvent(0, _("progress_load"))
;     windowMain::progressMod(0, _("progress_load")) ; 0%
    
    ; load list from json file
    json = LoadJSON(#PB_Any, getFolder(#FolderTPFMM) + "mods.json")
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
    Protected folderMods$ = getfolder(#FolderMods)
    deb("mods:: scan mods folder {"+folderMods$+"}")
    dir = ExamineDirectory(#PB_Any, folderMods$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If entry$ = "." Or entry$ = ".."
          Continue
        EndIf
        If modCheckRoot(folderMods$ + entry$); And modCheckID(entry$)
          scanner(entry$) = #True
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ;scan pWorkshop
    Protected folderWorkshop$ = getFolder(#FolderWorkshop)
    deb("mods:: scan workshop folder {"+folderWorkshop$+"}")
    dir = ExamineDirectory(#PB_Any, folderWorkshop$, "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          Continue
        EndIf
        entry$ = DirectoryEntryName(dir)
        If modCheckWorkshopID(entry$)
          If modCheckRoot(folderWorkshop$ + entry$)
            ; workshop mod folders only have a number.
            ; Add * as prefix and _1 as postfix
            scanner("*"+entry$+"_1") = #True
          EndIf
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    ;scan pStagingArea
    Protected folderStaging$ = getFolder(#FolderStagingArea)
    deb("mods:: scan staging area folder {"+folderStaging$+"}")
    dir = ExamineDirectory(#PB_Any, folderStaging$, "")
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
    
    ; addition: load backup files (keep between "stopDraw" calls)
    backupsClearFolder()
    backupsScan()
    
    If callbackStopDraw
      callbackStopDraw(#False)
    EndIf
    If events(#EventStopDraw)
      PostEvent(events(#EventStopDraw), #False, 0)
    EndIf
    
    postProgressEvent(-1, _("progress_loaded"))
;     windowMain::progressMod(windowMain::#Progress_Hide, _("progress_loaded"))
    
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
    
    If FileSize(getFolder(#FolderTPFMM)) <> -2
      misc::CreateDirectoryAll(getFolder(#FolderTPFMM))
    EndIf
    
    LockMutex(mutexMods)
    Protected json
    json = CreateJSON(#PB_Any)
    InsertJSONMap(JSONValue(json), mods())
    SaveJSON(json, getFolder(#FolderTPFMM) + "mods.json", #PB_JSON_PrettyPrint)
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
    
    postProgressEvent(20, _("progress_install"))
;     windowMain::progressMod(20, _("progress_install"))
    
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
        
        postProgressEvent(-1, _("progress_install_fail"))
        ProcedureReturn #False
    EndIf
    
    ; archive is extracted to target$
    ; (2) try to find mod in target$ (may be in some sub-directory)...
    
    postProgressEvent(40)
    modRoot$ = modGetRoot(target$)
    
    If modRoot$ = ""
      deb("mods:: getModRoot("+target$+") failed!")
      DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      postProgressEvent(-1, _("progress_install_fail"))
      ProcedureReturn #False
    EndIf
    
    ; modRoot folder found.
    ; try to get ID from folder name
    id$ = misc::getDirectoryName(modRoot$)
    
    If Not modCheckID(id$) And modCheckWorkshopID(id$)
      ; old backup mods from workshop only have number, add _1
      id$ = id$ + "_1"
    EndIf
    
    ; if tfmm.ini file found
    If FileSize(modRoot$ + "tfmm.ini") > 0
      ; tpfmm.ini found (old TF mods)
      If OpenPreferences(modRoot$ + "tfmm.ini")
        id$ = ReadPreferenceString("id", "")
        If id$
          id$ = ReplaceString(id$, ".", "_") + "_1"
        Else
          id$ = ReadPreferenceString("author", "unknown") + "_" + ReadPreferenceString("name", "unknown") + "_1"
          If id$ = "unknown_unknown_1"
            id$ = ""
          EndIf
        EndIf
        deb("mods:: reconstructed mod ID "+id$+" from tfmm.ini")
        ClosePreferences()
      EndIf
    EndIf
    
    If Not modCheckID(id$)
      deb("mods:: folder name not valid id ("+id$+")")
      
      ; try to get ID from archive file name
      id$ = GetFilePart(source$, #PB_FileSystem_NoExtension)
      If Not modCheckID(id$)
        deb("mods:: archive name not valid id ("+id$+")")
        ;TODO backup archives are "folder_id.<date>.zip" -> remove .<date> part to get ID?
        
        DeleteDirectory(target$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
        postProgressEvent(-1, _("progress_install_fail_id", "id="+id$))
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; get full path to mod folder based on ID (<installdir>/mods/ID)
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
        ;TODO fix this... (e.g. cannot overwrite vanilla mods...)
        deb("mods:: existing mod MUST NOT be uninstalled, still continue with overwrite...")
      EndIf
      
      If callbackRemoveMod
        callbackRemoveMod(*installedMod)
      EndIf
      If events(#EventRemoveMod)
        PostEvent(events(#EventRemoveMod), *installedMod, 0)
        ; send pointer for removal, attention: pointer may be invalid when trigger is processed
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
      postProgressEvent(-1, _("progress_install_fail"))
;       windowMain::progressMod(windowMain::#Progress_Hide, _("progress_install_fail"))
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
    postProgressEvent(-1, _("progress_installed"))
;     windowMain::progressMod(windowMain::#Progress_Hide, _("progress_installed"))
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
    
    postProgressEvent(-1, _("management_uninstall_done"))
;     windowMain::progressMod(windowMain::#Progress_Hide, _("management_uninstall_done"))
    
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
    Protected backupFolder$, modFolder$, filename$, tmpFile$, md5$, backupFile$
    Protected *mod.mod, *this.backup, *old.backup
    Protected time
    
    WaitSemaphore(semaphoreBackup)
    
    ; use UTC time
    time = misc::time()
    
    backupFolder$ = backupsGetFolder()
    misc::CreateDirectoryAll(backupFolder$)
    
    LockMutex(mutexMods)
    If FindMapElement(mods(), id$)
      *mod = mods(id$)
      UnlockMutex(mutexMods)
    Else
      UnlockMutex(mutexMods)
      deb("mods:: cannot find mod {"+id$+"}")
      SignalSemaphore(semaphoreBackup)
      ProcedureReturn #False
    EndIf
    
    If FileSize(backupFolder$) <> -2
      deb("mods:: target directory does not exist {"+backupFolder$+"}")
      SignalSemaphore(semaphoreBackup)
      ProcedureReturn #False
    EndIf
    
    modFolder$ = getModFolder(id$)
    
    If FileSize(modFolder$) <> -2
      deb("mods:: mod directory does not exist {"+modFolder$+"}")
      SignalSemaphore(semaphoreBackup)
      ProcedureReturn #False
    EndIf
    
    filename$ + modGetFoldername(*mod)+".zip"
    tmpFile$ = misc::path(GetCurrentDirectory() + #PS$ + "tmp") + filename$
    
    ; start backup now: modFolder$ -> zip -> backupFile$
    postProgressEvent(90,  _("progress_backup_mod", "mod="+*mod\name$))
    
    ; create archive in tmp folder first
    CreateDirectory(GetPathPart(tmpFile$))
    If Not archive::pack(tmpFile$, modFolder$)
      ; failed to create backup file
      deb("mods:: backup failed")
      postProgressEvent(-1, _("progress_backup_fail"))
      SignalSemaphore(semaphoreBackup)
      ProcedureReturn #False
    EndIf
    
    If FileSize(tmpFile$) <= 0
      deb("mods:: temporary backup file "+tmpFile$+" not found")
      postProgressEvent(-1, _("progress_backup_fail"))
      SignalSemaphore(semaphoreBackup)
      ProcedureReturn #False
    EndIf
    
    ; get hash of file
    md5$ = FileFingerprint(tmpFile$, #PB_Cipher_MD5)
    
    ; folder structure: <backups>/hash/mod_id.zip
    ; collision if backup with same hash and same mod_id already exists
    filename$ = misc::path(md5$) + filename$ ; filename is the filename relative to the backup folder
    backupFile$ = misc::path(backupFolder$) + filename$
    deb("mods:: target backup file "+filename$)
    If FileSize(backupFile$) > 0
      deb("mods:: backup file "+backupFile$+" already exists, delete old backup")
      *old = FindMapElement(backups(), filename$)
      If callbackRemoveBackup : callbackRemoveBackup(*old) : EndIf
      If events(#EventRemoveBackup) : PostEvent(events(#EventRemoveBackup), *old, #Null) : EndIf
      DeleteMapElement(backups(), filename$)
      DeleteFile(backupFile$, #PB_FileSystem_Force)
      DeleteFile(backupFile$+".backup", #PB_FileSystem_Force)
    Else
      misc::CreateDirectoryAll(GetPathPart(backupFile$))
    EndIf
    
    If Not RenameFile(tmpFile$, backupFile$)
      deb("mods:: renaming backup file failed!")
      postProgressEvent(-1, _("progress_backup_fail"))
      SignalSemaphore(semaphoreBackup)
      ProcedureReturn #False
    EndIf
    
;     *mod\aux\backup\time = Date()
;     *mod\aux\backup\filename$ = GetFilePart(backupFile$)
    
    ; save mod information with the backup file
    Protected json
    Protected backupInfo.backupInfo
    json = CreateJSON(#PB_Any)
    If json
      backupInfo\filename$  = filename$ ; relative to the backup folder root
      backupInfo\tpf_id$    = *mod\tpf_id$ ; or just "id$"
      backupInfo\name$      = *mod\name$
      backupInfo\version$   = *mod\version$
      backupInfo\author$    = modGetAuthorsString(*mod)
      backupInfo\time       = time
      backupInfo\size       = FileSize(backupFile$)
      backupInfo\checksum$  = md5$
      InsertJSONStructure(JSONValue(json), backupInfo, backupInfo)
      Debug ComposeJSON(json, #PB_JSON_PrettyPrint)
      DeleteFile(backupFile$+".backup")
      If Not SaveJSON(json, backupFile$+".backup", #PB_JSON_PrettyPrint)
        deb("mods:: failed to create backup meta data file: "+backupFile$+".backup")
      EndIf
      FreeJSON(json)
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        SetFileAttributes(backupFile$+".backup", #PB_FileSystem_Hidden)
      CompilerEndIf
    Else
      deb("mods:: failed to create json data for backup file")
    EndIf
    
    backupsReadBackupInformation(filename$, backupFolder$)
    
    ; finished
    postProgressEvent(-1, _("progress_backup_fin"))
    SignalSemaphore(semaphoreBackup)
    ProcedureReturn #True
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
      deb("mods:: doUpdate() found online file "+*repoFile\getFileName()+" at "+*repoFile\getLink())
      ProcedureReturn *repoFile\download() ; starts download in new thread
    EndIf
    
    ; if no direct file is found, try to find the mod (which may have multiple files as selction for the user)
    *repoMod = modGetRepoMod(*mod)
    If *repoMod
      deb("mods:: doUpdate() found online mod in source "+*repoMod\getSource()+": "+*repoMod\getName()+" at "+*repoMod\getLink())
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
  ;static
  
  Procedure.s backupsGetFolder()
    Protected backupFolder$
    
    If settings::getString("","path") = ""
      ProcedureReturn ""
    EndIf
    
    backupFolder$ = settings::getString("backup", "folder")
    If backupFolder$ = ""
      backupFolder$ = "TPFMM/backups/"
    EndIf
    
    ProcedureReturn misc::path(backupFolder$)
  EndProcedure
  
  Procedure backupsMoveFolder(newFolder$)
    Protected oldFolder$, entry$
    Protected dir, error, count
    
    newFolder$ = misc::path(newFolder$)
    oldFolder$ = backupsGetFolder()
    
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
      ; not a critical error, if old folder does not exist, simple do not move any files
    EndIf
    
    If Not error
      settings::setString("backup", "folder", newFolder$)
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
    
  EndProcedure
  
  Procedure backupsClearFolder()
    WaitSemaphore(semaphoreBackup)
    backupsClearFolderRecursive(backupsGetFolder())
    SignalSemaphore(semaphoreBackup)
  EndProcedure
  
  Procedure backupsScan()
    WaitSemaphore(semaphoreBackup)
    If callbackClearBackups : callbackClearBackups() : EndIf
    If events(#EventClearBackups) : PostEvent(events(#EventClearBackups), #Null, #Null) : EndIf
    ClearMap(backups())
    
    backupsScanRecursive(backupsGetFolder())
    
    deb("mods:: found "+MapSize(backups())+" backups")
    SignalSemaphore(semaphoreBackup)
  EndProcedure
  
  
  ;methods
  
  Procedure.s backupGetFilename(*this.backup)
    ProcedureReturn *this\info\filename$
  EndProcedure
  
  Procedure.s backupGetFoldername(*this.backup)
    ProcedureReturn *this\info\tpf_id$
  EndProcedure
  
  Procedure.s backupGetName(*this.backup)
    ProcedureReturn *this\info\name$
  EndProcedure
  
  Procedure.s backupGetVersion(*this.backup)
    ProcedureReturn *this\info\version$
  EndProcedure
  
  Procedure.s backupGetAuthors(*this.backup)
    ProcedureReturn *this\info\author$
  EndProcedure
  
  Procedure backupGetDate(*this.backup)
    ; time is saved in UTC
    ; correct by timezone offset
    ProcedureReturn *this\info\time + misc::timezone()*3600
  EndProcedure
  
  Procedure.b backupIsInstalled(*this.backup)
    DebuggerWarning("not implemented yet")
  EndProcedure
  
  Procedure backupInstall(*this.backup)
    Protected backup$
    backup$ = backupsGetFolder() + *this\info\filename$
    deb("mods:: install backup "+*this\info\filename$)
    install(backup$)
  EndProcedure
  
  Procedure backupDelete(*this.backup)
    Protected backup$, deleted.b, *element
    
    WaitSemaphore(semaphoreBackup)
    backup$ = backupsGetFolder() + *this\info\filename$
    deb("mods:: delete backup "+*this\info\filename$)
    
    ; delete file
    If FileSize(backup$) > 0
      If DeleteFile(backup$, #PB_FileSystem_Force)
        DeleteFile(backup$+".backup", #PB_FileSystem_Force)
        deleted = #True
      Else
        deb("mods:: could not delete backup file "+backup$)
      EndIf
    Else
      deb("mods:: backup file not found: "+backup$)
    EndIf
    
    ; remove from internal list
    If deleted
      If callbackRemoveBackup : callbackRemoveBackup(*this) : EndIf
      If events(#EventRemoveBackup) : PostEvent(events(#EventRemoveBackup), *this, #Null) : EndIf
      DeleteMapElement(backups(), *this\info\filename$)
    EndIf
    
    SignalSemaphore(semaphoreBackup)
    ProcedureReturn deleted
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
      Case #EventNewBackup
        callbackNewBackup = *callback
      Case #EventRemoveBackup
        callbackRemoveBackup = *callback
      Case #EventClearBackups
        callbackClearBackups = *callback
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
