DeclareModule mods
  EnableExplicit
  
  Structure aux
    version$ ; version as string
    authors$ ; authors as string
    tfnet_author_id$ ; author id's on tf|net as string
    tags$ ; tags as string
    
    file$ ; filename
    md5$ ; md5 of file
    installed.i ; true, if mod is currently installed
    TFonly.i ; if only in tf mods directory, but not in TFMM library
    lua$
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
  
  Declare changed() ; report changed to mod map (new mods, changed status, etc)
  Declare registerLibraryGadget(library)
  
  Declare init() ; allocate structure, return *mod
  Declare free(id$) ; free *mod structure
  Declare freeAll()
  Declare load(*data)
  Declare convert(*data)
  
  Declare generateID(*mod.mod, id$ = "")
  Declare generateLUA(*mod.mod)
  
  Declare new(file$, TF$) ; read mod pack from any location, extract info
  Declare delete(*data)   ; delete mod from library
  
  Declare install(*data)  ; add mod to TF
  Declare remove(*data)   ; remove mod from TF
  
EndDeclareModule

; IDE Options = PureBasic 5.31 (Windows - x64)
; CursorPosition = 12
; FirstLine = 3
; Folding = -
; EnableUnicode
; EnableXP