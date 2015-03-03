DeclareModule mods
  EnableExplicit
  
  Structure aux
    version$
    authors$
    tfnet_author_id$
    tags$
    
    file$
    md5$
    installed.i
    TFonly.i
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
    id$
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
    
    aux.aux
  EndStructure
  
  Declare changed() ; report changed to mod map (new mods, changed status, etc)
  Declare registerLibraryGadget(library)
  
  Declare init() ; allocate structure, return *mod
  Declare free(id$) ; free *mod structure
  Declare load(*data)
  Declare convert(*data)
  
  Declare generateID(*mod.mod, id$ = "")
  Declare generateLUA(*mod.mod)
  
  Declare new(file$, TF$) ; read mod pack from any location, extract info
  Declare delete(*data)   ; delete mod from library
  
  Declare install(*data)  ; add mod to TF
  Declare remove(*data)   ; remove mod from TF
  
  
  
EndDeclareModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 12
; Folding = -
; EnableUnicode
; EnableXP