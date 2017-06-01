DeclareModule mods
  EnableExplicit
  
  #SCANNER_VERSION = #PB_Editor_CompileCount
  
  Structure backup  ;-- information about last backup if available
    time.i
    filename$
  EndStructure
  
  Structure aux     ;-- additional information about mod
    type$             ; "mod", "map", "dlc", ...
    isVanilla.b       ; pre-installed mods should not be uninstalled
    luaDate.i         ; date of info.lua (reload info when newer version available)
    luaLanguage$      ; language of currently loaded info from mod.lua -> reload mod.lua when language changes
    installDate.i     ; date of first encounter of this file (added to TPFMM)
    repoTimeChanged.i ; timechanged value from repository if installed from repo (if timechanged in repo > timechanged in mod: update available
    tfnetID.i         ; entry ID in transportfever.net download section
    workshopID.q      ; fileID in Steam Workshop
    installSource$    ; name of install source (workshop, tpfnet)
    *tfnetMod         ; (temp) link to mod in repository
    *workshopMod      ; (temp) link to mod in repository
    sv.i              ; scanner version, rescan if newer scanner version is used
    hidden.b          ; hidden from overview ("visible" in mod.lua)
    backup.backup     ; backup information (local)
  EndStructure
  
  ; as saved in settings.lua
  Structure modSetting
    value$            ; single value
    List values$()    ; table type value
  EndStructure
  
  ; a single value for table-type setting definition in mod.lua
  Structure tableValue
    text$
    value$
  EndStructure
  
  ; mod.lua custom mod setting definition
  Structure settings
    type$             ; boolean, number, string
    name$             ; name of given setting
    Default$          ; default value, type dependent, stored as string
    List tableDefaults$()  ; default values for table type
    description$      ; tooltip / description of setting
    image$            ; path (relative to mod.lua) to a preview image to show in the settings dialog
    min.d             ; only for number, minimum value, optional
    max.d             ; only for number, maximum value, optional
    List tableValues.tableValue()
;     Step.d            ; only for number, step for spin gagdet, optional
    im.i              ; image # 
  EndStructure
  
  
  Structure author  ;-- information about author
    name$             ; name of author
    role$             ; CREATOR, CO_CREATOR, TESTER, BASED_ON, OTHER
    text$             ; optional, additional text to display
    tfnetId.i         ; user ID on transportfever.net
    steamId.q         ; SteamID
    steamProfile$     ; Steam profile link
  EndStructure
  
  Structure dependency ;-- dependency information
    mod$            ; folder name
    version.i       ; minorVersion
    steamId.q       ; steam workshop ID
    tfnetId.i       ; transportfever.net ID
    exactMatch.b    ; is only exact version match allowed?
  EndStructure
  
  Structure mod           ;-- information about mod/dlc
    tpf_id$              ; folder name in game: author_name_version or steam workshop ID
    uuid$                   ; Universally unique identifier for a single mod (all versions of mod on all online sources)
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
    List dependencies.dependency()    ; list of required mods (folder name of required mod)
    url$                    ; website with further information
    
    Map settings.settings() ; mod settings (optional)
    aux.aux                 ; auxiliary information
  EndStructure
  
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
  
  
  Global isLoaded.b
  Global working.b
  
  
  ; mod functions:
  
  Declare modCountAuthors(*mod.mod)
  Declare modGetAuthor(*mod.mod, n.i, *author.author)
  Declare modCountTags(*mod.mod)
  Declare.s modGetTag(*mod.mod, n.i)
  Declare.s modGetTags(*mod.mod)
  
  ; mod-list functions:
  
  
  Declare register(window, gadgetModList, gadgetFilterString, gadgetFilterHidden, gadgetFilterVanilla, gadgetFilterFolder)
  
  Declare init()    ; allocate new mod structure, return *mod
  Declare freeAll() ; free all mods in map
  Declare saveList()
  
  Declare generateID(*mod.mod, id$ = "")
  
  Declare.s getModFolder(id$ = "", type$ = "mod")
  
  ; required interfaces:
  ; install(*data) - extract an archive to the game folder
  ; uninstall(*data) - remove a mod folder from the game
  ; 
  ; download(*data) - provided by repository module! -> dowloads file to temp dir and calls install procedure
  
  ; check mod functions:
  
  Declare canUninstall(*mod.mod)
  Declare canBackup(*mod.mod)
  Declare isInstalledByRemote(source$, id)
  Declare isInstalled(id$)
  
  Declare getBackupList(List backups.backupInfoLocal())
  Declare backupDelete(file$)
  
  ; actions
  Declare load()                ; load mods.json and find installed mods
  Declare install(file$)        ; check and extract archive to game folder
  Declare uninstall(folderID$)  ; remove mod folder from game, maybe create a security backup by zipping content
  Declare backup(folderID$)     ; backup installed mod
  Declare update(folderID$)
  
  ; export
  Declare exportList(all=#False)
  
  ; display callbacks
  Declare displayMods()
  
  Declare getPreviewImage(*mod.mod, original=#False)
EndDeclareModule
