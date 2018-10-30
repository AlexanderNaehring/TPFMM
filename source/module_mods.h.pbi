DeclareModule mods
  EnableExplicit
  
  #SCANNER_VERSION = #PB_Editor_CompileCount
  
  
  ; callbacks for mod events
  
  Enumeration
    #EventNewMod
    #EventRemoveMod
    #EventStopDraw
    #EventWorkerStarts
    #EventWorkerStops
    #EventProgress
  EndEnumeration
  Global EventArraySize = #PB_Compiler_EnumerationValue -1
  
  
  Prototype callbackNewMod(*mod)
  Prototype callbackRemoveMod(*mod)
  Prototype callbackStopDraw(stop)
  
  Structure backupInfo
    name$
    version$
    author$
    tpf_id$
    filename$
    time.i
    size.q
    checksum$
  EndStructure
  
  Structure backupInfoLocal Extends backupInfo
    installed.b
  EndStructure
  
  ;{ modSettings Structures
  
  ; a single value for table-type setting definition in mod.lua
  Structure tableValue
    text$
    value$
  EndStructure
  
  ; mod.lua custom mod setting definition
  Structure modLuaSetting
    key$              ; internal name of the setting
    order.i           ; manual ordering of settings
    type$             ; boolean, number, string
    name$             ; display name of given setting
    Default$          ; default value, type dependent, stored as string
    List tableDefaults$()  ; default values for table type
    description$      ; tooltip / description of setting
    image$            ; path (relative to mod.lua) to a preview image to show in the settings dialog
    min.d             ; only for number, minimum value, optional
    max.d             ; only for number, maximum value, optional
    List tableValues.tableValue()
    multiSelect.b     ; for table type: if multiselect = false, allow only exactly one option, default = true
;     Step.d            ; only for number, step for spin gagdet, optional
    im.i              ; image # 
  EndStructure
  
  ; as saved in settings.lua
  Structure modSetting ; only used in "modSettings" window (for display) and luaParser (for reading)
    value$            ; single value
    List values$()    ; table type value
  EndStructure
  
  ;}
  
  ;{ Author Structure
  Structure author  ;-- information about author
    name$             ; name of author
    role$             ; CREATOR, CO_CREATOR, TESTER, BASED_ON, OTHER
    text$             ; optional, additional text to display
    tfnetId.i         ; user ID on transportfever.net
    steamId.q         ; SteamID
    steamProfile$     ; Steam profile link
  EndStructure
  ;}
  
  ;{ Interfaces
  
  Interface LocalMod
    ; get
    getID.s()
    getFoldername.s()
    getName.s()
    getVersion.s()
    getDescription.s()
    getAuthorsString.s()
    getTags.s()
    getDownloadLink.s()
    getRepoMod()
    getSize(refresh=#False)
    getWebsite.s()
    getTfnetID()
    getWorkshopID.q()
    getSettings(List *settings.modLuaSetting())
    getInstallDate()
    getPreviewImage()
    
    ; set
    setName(name$)
    setDescription(description$)
    setMinorVersion(version)
    setHidden(hidden)
    setTFNET(id)
    setWorkshop(id.q)
    setLuaDate(date)
    setLuaLanguage(language$)
    
    ; add to / clear / sort lists
    addAuthor()
    clearAuthors()
    addTag(tag$)
    clearTags()
    addDependency(dependency$)
    clearDependencies()
    addSetting()
    clearSettings()
    sortSettings()
    
    ; check
    isVanilla()
    isWorkshop()
    isStagingArea()
    isHidden()
    isUpdateAvailable()
    canBackup()
    canUninstall()
    hasSettings()
    
    ; other
    countAuthors()
    getAuthor(n)
    countTags()
    getTag.s(n)
    
  EndInterface
  ;}
  
  ;{ Functions
  ; static functions:
  Declare freeAll()   ; free all mods in map
  Declare saveList()  ; save list of current mods to json
  Declare generateID(*mod, id$ = "")
  Declare.s getModFolder(id$="") ; location on disc, depending on "workshop, staging area, manual mod"
  Declare stopQueue(timeout = 5000)
  
  ; actions - all actions will be handled by mod main thread
  Declare load(async=#True)     ; load mods.json and find installed mods
  Declare install(file$)        ; check and extract archive to game folder
  Declare uninstall(folderID$)  ; remove mod folder from game, maybe create a security backup by zipping content
  Declare backup(folderID$)     ; backup installed mod
  Declare update(folderID$)     ; request update from repository and install
  
  ; backup functions
  Declare getBackupList(List backups.backupInfoLocal(), filter$="")
  Declare backupDelete(file$)
  Declare.s getBackupFolder()
  Declare moveBackupFolder(newFolder$)
  
  ; mod static functions:
  Declare getMods(List *mods())
  Declare getModByFoldername(foldername$)
  Declare isInstalled(foldername$)
  
  ; mod methods
  ; get
  Declare.s modGetID(*mod)
  Declare.s modGetFoldername(*mod)
  Declare.s modGetName(*mod)
  Declare.s modGetVersion(*mod)
  Declare.s modGetDescription(*mod)
  Declare.s modGetAuthorsString(*mod)
  Declare.s modGetTags(*mod)
  Declare.s modGetDownloadLink(*mod)
  Declare modGetRepoMod(*mod)
  Declare modGetSize(*mod, refresh=#False)
  Declare.s modGetWebsite(*mod)
  Declare modGetTfnetID(*mod)
  Declare.q modGetWorkshopID(*mod)
  Declare modGetSettings(*mod, List settings.modLuaSetting())
  Declare modGetInstallDate(*mod)
  Declare modGetPreviewImage(*mod)
  
  ; set
  Declare modSetName(*mod, name$)
  Declare modSetDescription(*mod, description$)
  Declare modSetMinorVersion(*mod, version)
  Declare modSetHidden(*mod, hidden)
  Declare modSetTFNET(*mod, id)
  Declare modSetWorkshop(*mod, id.q)
  Declare modSetLuaDate(*mod, date)
  Declare modSetLuaLanguage(*mod, language$)
  
  ; add to / clear / sort lists
  Declare modAddAuthor(*mod)
  Declare modClearAuthors(*mod)
  Declare modAddTag(*mod, tag$)
  Declare modClearTags(*mod)
  Declare modAddDependency(*mod, dependency$)
  Declare modClearDependencies(*mod)
  Declare modAddSetting(*mod)
  Declare modClearSettings(*mod)
  Declare modSortSettings(*mod)
  
  ; check
  Declare modIsVanilla(*mod)
  Declare modIsWorkshop(*mod)
  Declare modIsStagingArea(*mod)
  Declare modIsHidden(*mod)
  Declare modIsUpdateAvailable(*mod)
  Declare modCanBackup(*mod)
  Declare modCanUninstall(*mod)
  Declare modHasSettings(*mod)
  
  ; other
  Declare modCountAuthors(*mod)
  Declare modGetAuthor(*mod, n.i)
  Declare modCountTags(*mod)
  Declare.s modGetTag(*mod, n.i)
  
  ; export
  Declare exportList(all=#False)
  
  ; Bind Callback Events
  Declare BindEventCallback(Event, *callback)
  Declare BindEventPost(ModEvent, WindowEvent, *callback)
  
  ;}
EndDeclareModule


