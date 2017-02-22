DeclareModule mods
  EnableExplicit
  
  Structure archive ;-- information about the archive
    name$             ; filename of archive
    md5$              ; md5 file fingerprint of archive file
;     type.i            ; #TYPE_ZIP or #TYPE_RAR
    password$         ; password used for decrypting the archive
  EndStructure
  
  Structure aux     ;-- additional information about mod
    type$             ; "mod", "map", "dlc", ...
    isVanilla.b       ; pre-installed mods should not be uninstalled
    luaDate.i         ; date of info.lua (reload info when newer version available)
    installDate.i     ; date of first encounter of this file (added to TPFMM)
    archive.archive   ; archive file, type and handle
    repoTimeChanged.i ; timechanged value from repository if installed from repo
    tpfnetID.i        ; entry ID in transportfever.net download section
    workshopID.i      ; fileID in Steam Workshop
;     isDLC.b            ; true (1) if mod is a DLC and has to be installed to "dlc" directory
  EndStructure
  
  Structure author  ;-- information about author
    name$             ; name of author
    role$             ; CREATOR, CO_CREATOR, TESTER, BASED_ON, OTHER
    text$             ; optional, additional text to display
    steamProfile$     ; Stream profile link
    tfnetId.i         ; user ID (number) on train-fever.net
  EndStructure
  
  Structure mod           ;-- information about mod/dlc
    tpf_id$                 ; folder name in game: author_name_version or steam workshop ID
    name$                   ; name of mod
    majorVersion.i          ; first part of version number, identical to version in ID string
    minorVersion.i          ; latter part of version number
    version$
    severityAdd$            ; potential impact to game when adding mod
    severityRemove$         ; potential impact to game when removeing mod
    description$            ; optional description
    List authors.author()   ; information about author(s)
    List tags$()            ; list of tags
    List tagsLocalized$()   ; translated tags
    minGameVersion.i        ; minimum required build number of game
    List dependencies$()    ; list of required mods (folder name of required mod)
    url$                    ; website with further information
    
    aux.aux                 ; auxiliary information
  EndStructure
  
  Declare registerMainWindow(window)
  Declare registerModGadget(gadget)
  
  Declare init()    ; allocate new mod structure, return *mod
  Declare free(*mod.mod) ; free *mod structure
  Declare freeAll() ; free all mods in map
  Declare loadList(*data) ; load up programm (read mods from different locations)
  Declare saveList()
  
  Declare generateID(*mod.mod, id$ = "")
  Declare.s getLUA(*mod.mod)
  
  ; required interfaces:
  ; install(*data) - extract an archive to the game folder
  ; uninstall(*data) - remove a mod folder from the game
  ; 
  ; download(*data) - provided by repository module! -> dowloads file to temp dir and calls install procedure
  
  Declare canUninstall(*mod.mod)
  Declare canBackup(*mod.mod)
  
  ; queue callbacks:
  Declare install(*data)    ; check and extract archive to game folder
  Declare uninstall(*data)  ; remove mod folder from game, maybe create a security backup by zipping content
  Declare backup(*data)     ; backup mod
  
  ; export
  Declare exportList(all=#False)
  
  ; display callbacks
  Declare displayMods(filter$="")
  Declare displayDLCs()
  
  Declare getPreviewImage(*mod.mod, original=#False)
EndDeclareModule
