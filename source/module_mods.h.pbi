DeclareModule mods
  EnableExplicit
  
  Structure aux
    version$          ; version as string
    authors$          ; authors as string
    tfnet_author_id$  ; author ids on tf|net as string
    tags$             ; tags as string
    
    archive$    ; filename of mod archive (zip/rar/...)
    archiveMD5$ ; md5 of mod archive
    active.i    ; true, if mod installed (new or old system)
    inLibrary.i ; true, if mod is in TFMM library
    luaDate.i   ; md5 of info.lua (check if it was changed -> relead info)
  EndStructure
  
  Structure author
    name$
    role$
    text$
    steamProfile$
    tfnetId.i
  EndStructure
  
  Structure mod
    tf_id$
    minorVersion.i
    majorVersion.i
    severityAdd$
    severityRemove$
    name$
    description$
    List authors.author()
    List tags$()
    tfnetId.i
    minGameVersion.i
    List dependencies$()
    url$
    
    aux.aux ; auxiliary information
  EndStructure
  
  Declare changed_() ; report changed to mod map (new mods, changed status, etc)
  Declare registerLibraryGadget(library)
  
  Declare init() ; allocate structure, return *mod
  Declare free(id$) ; free *mod structure
  Declare freeAll()
  Declare loadList(*dummy)
  Declare saveList()
  Declare convert(*data)
  
  Declare generateID(*mod.mod, id$ = "")
  Declare.s getLUA(*mod.mod)
  
  Declare new(file$)      ; read mod pack from any location, extract info
  Declare delete(*data)   ; delete mod from library
  
  Declare install(*data)  ; add mod to TF
  Declare remove(*data)   ; remove mod from TF
  
  Declare exportList(all=#False)
EndDeclareModule
