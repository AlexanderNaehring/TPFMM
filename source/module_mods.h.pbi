DeclareModule mods
  EnableExplicit
  
  Enumeration
    #TYPE_ZIP
    #TYPE_RAR
  EndEnumeration
  
  Structure archive ;-- information about the archive
    name$             ; filename of archive
    md5$              ; md5 file fingerprint of archive file
;     type.i            ; #TYPE_ZIP or #TYPE_RAR
    password$         ; password used for decrypting the archive
  EndStructure
  
  Structure aux     ;-- additional information about mod
    version$          ; version as string: major.minor
    authors$          ; authors as string: author1, author2, author3, ...
    tfnet_author_id$  ; author ids on tf|net as string: id1, id2, id3, ...
    tags$             ; tags as string: tag1, tag2, tag3, ...
    
    active.i          ; true, if mod installed (new or old system)
    inLibrary.i       ; true, if mod is in TFMM library
    luaDate.i         ; date of info.lua (reload info when newer version available)
    installDate.i     ; date of first encounter of this file (added to TFMM)
  EndStructure
  
  Structure author  ;-- information about author
    name$             ; name of author
    role$             ; CREATOR, CO_CREATOR, TESTER, BASED_ON, OTHER
    text$             ; optional, additional text to display
    steamProfile$     ; Stream profile link
    tfnetId.i         ; user ID (number) on train-fever.net
  EndStructure
  
  Structure mod           ;-- information about mod/dlc
    tf_id$                  ; unique id for Train Fever: author_name_version
    name$                   ; name of mod
    minorVersion.i          ; latter part of version number
    majorVersion.i          ; first part of version number, identical to version in ID string
    severityAdd$            ; potential impact to game when adding mod
    severityRemove$         ; potential impact to game when removeing mod
    description$            ; optional description
    List authors.author()   ; information about author(s)
    List tags$()            ; list of tags
    tfnetId.i               ; ID (number) on train-fever.net
    minGameVersion.i        ; minimum required build number of Train Fever
    List dependencies$()    ; list of required mods (tf_id)
    url$                    ; online information about mod
    
    isDLC.b                 ; true (1) if mod is a DLC and has to be installed to "dlc" directory
    aux.aux                 ; additional information
    archive.archive         ; archive file, type and handle
  EndStructure
  
  Declare registerMainWindow(window)
  Declare registerModGadget(gadget)
  Declare registerDLCGadget(gadget)
  
  Declare init()    ; allocate new mod structure, return *mod
  Declare free(id$) ; free *mod structure
  Declare freeAll() ; free all mods in map
  Declare loadList(*dummy)
  Declare saveList()
  Declare convert(*data)
  
  Declare generateID(*mod.mod, id$ = "")
  Declare.s getLUA(*mod.mod)
  
  Declare new(*data)      ; read mod pack from any location, extract info
  Declare delete(*data)   ; delete mod from library
  
  Declare install(*data)  ; add mod to TF
  Declare remove(*data)   ; remove mod from TF
  
  Declare exportList(all=#False)
  
  Declare displayMods(filter$="")
  Declare displayDLCs()
  
  Declare getPreviewImage(*mod.mod, original=#False)
EndDeclareModule
