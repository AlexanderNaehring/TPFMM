
DeclareModule pack
  EnableExplicit
  
  #EXTENSION = "tpfp"
  
  Structure packItem
    name$
    folder$ ; = mod_ID (must be unique)
    download$
    required.i
  EndStructure
  
  ; functions
  Declare create(name$="", author$="")
  Declare free(*pack)
  Declare open(file$)
  Declare save(*pack, file$)
  
  Declare setName(*pack, name$)
  Declare.s getName(*pack)
  Declare setAuthor(*pack, author$)
  Declare.s getAuthor(*pack)
  Declare addItem(*pack, *item.packItem)
  Declare getItems(*pack, List items())
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"

Module pack
  
  Structure packFile
    name$
    author$
    List items.packItem()
  EndStructure
  
  Structure pack
    packFile.packFile ; content actually be written to the pack file
    mutex.i           ; for operations on this pack
  EndStructure
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(name$ = "", author$ = "")
    Protected *pack.pack
    
    *pack = AllocateStructure(pack)
    *pack\packFile\name$   = name$
    *pack\packFile\author$ = author$
    *pack\mutex   = CreateMutex()
    
    ProcedureReturn *pack
  EndProcedure
  
  Procedure free(*pack.pack)
    FreeMutex(*pack\mutex)
    FreeStructure(*pack)
  EndProcedure
  
  Procedure open(file$)
    Protected json
    Protected *pack.pack
    debugger::add("pack::open() "+file$)
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      debugger::add("pack::open() - could not open json file")
      ProcedureReturn #False
    EndIf
    
    *pack = create()
    ExtractJSONStructure(JSONValue(json), *pack\packFile, packFile)
    FreeJSON(json)
    
    ProcedureReturn *pack
  EndProcedure
  
  Procedure save(*pack.pack, file$)
    If LCase(GetExtensionPart(file$)) <> #EXTENSION
      file$ + "." + #EXTENSION
    EndIf
    
    Protected json = CreateJSON(#PB_Any)
    InsertJSONStructure(JSONValue(json), *pack\packFile, packFile)
    If Not SaveJSON(json, file$, #PB_JSON_PrettyPrint)
      debugger::add("pack::save() - error writing json file {"+file$+"}")
    EndIf
    FreeJSON(json)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure setName(*pack.pack, name$)
    *pack\packFile\name$ = name$
  EndProcedure
  
  Procedure.s getName(*pack.pack)
    ProcedureReturn *pack\packFile\name$
  EndProcedure
  
  Procedure setAuthor(*pack.pack, author$)
    *pack\packFile\author$ = author$
  EndProcedure
  
  Procedure.s getAuthor(*pack.pack)
    ProcedureReturn *pack\packFile\author$
  EndProcedure
  
  Procedure getItems(*pack.pack, List *items.packItem())
    ClearList(*items())
    LockMutex(*pack\mutex)
    CopyList(*pack\packFile\items(), *items())
    LockMutex(*pack\mutex)
    ProcedureReturn ListSize(*items())
  EndProcedure
  
  Procedure addItem(*pack.pack, *item.packItem)
    LockMutex(*pack\mutex)
    AddElement(*pack\packFile\items())
    CopyStructure(*item, *pack\packFile\items(), packItem)
    UnlockMutex(*pack\mutex)
    ProcedureReturn #True
  EndProcedure
  
  
EndModule
