
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
  Declare isPack(*pack)
  
  Declare setName(*pack, name$)
  Declare.s getName(*pack)
  Declare setAuthor(*pack, author$)
  Declare.s getAuthor(*pack)
  Declare addItem(*pack, *item.packItem)
  Declare getItems(*pack, List items())
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"

Module pack
  
  Global NewMap packs()
  Global mutex = CreateMutex()
  
  Structure pack
    name$
    author$
    List items.packItem()
    mutex.i           ; for operations on this pack
  EndStructure
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(name$ = "", author$ = "")
    Protected *pack.pack
    
    *pack = AllocateStructure(pack)
    *pack\name$   = name$
    *pack\author$ = author$
    *pack\mutex   = CreateMutex()
    
    LockMutex(mutex)
    AddMapElement(packs(), Str(*pack), #PB_Map_NoElementCheck)
    UnlockMutex(mutex)
    
    ProcedureReturn *pack
  EndProcedure
  
  Procedure isPack(*pack)
    Protected valid.i
    LockMutex(mutex)
    valid = FindMapElement(packs(), Str(*pack))
    UnlockMutex(mutex)
    ProcedureReturn valid
  EndProcedure
  
  Procedure free(*pack.pack)
    If Not isPack(*pack)
      debugger::add("pack::free() - WARNING: try to free invalid pack")
      ProcedureReturn #False
    EndIf
    
    LockMutex(mutex)
    DeleteMapElement(packs(), Str(*pack))
    UnlockMutex(mutex)
    FreeMutex(*pack\mutex)
    FreeStructure(*pack)
  EndProcedure
  
  Procedure open(file$)
    Protected json
    Protected *pack.pack, packMutex
    debugger::add("pack::open() "+file$)
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      debugger::add("pack::open() - could not open json file")
      ProcedureReturn #False
    EndIf
    
    *pack = create()
    packMutex = *pack\mutex
    ExtractJSONStructure(JSONValue(json), *pack, pack)
    *pack\mutex = packMutex
    FreeJSON(json)
    
    ProcedureReturn *pack
  EndProcedure
  
  Procedure save(*pack.pack, file$)
    If LCase(GetExtensionPart(file$)) <> #EXTENSION
      file$ + "." + #EXTENSION
    EndIf
    
    Protected json = CreateJSON(#PB_Any)
    InsertJSONStructure(JSONValue(json), *pack, pack)
    If Not SaveJSON(json, file$, #PB_JSON_PrettyPrint)
      debugger::add("pack::save() - error writing json file {"+file$+"}")
    EndIf
    FreeJSON(json)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure setName(*pack.pack, name$)
    *pack\name$ = name$
  EndProcedure
  
  Procedure.s getName(*pack.pack)
    ProcedureReturn *pack\name$
  EndProcedure
  
  Procedure setAuthor(*pack.pack, author$)
    *pack\author$ = author$
  EndProcedure
  
  Procedure.s getAuthor(*pack.pack)
    ProcedureReturn *pack\author$
  EndProcedure
  
  Procedure getItems(*pack.pack, List items.packItem())
    ClearList(items())
    LockMutex(*pack\mutex)
    CopyList(*pack\items(), items())
    LockMutex(*pack\mutex)
    ProcedureReturn ListSize(items())
  EndProcedure
  
  Procedure addItem(*pack.pack, *item.packItem)
    Protected add = #True
    LockMutex(*pack\mutex)
    ForEach *pack\items()
      If LCase(*pack\items()\folder$) = LCase(*item\folder$)
        add = #False
        Break
      EndIf
    Next
    If add
      AddElement(*pack\items())
      CopyStructure(*item, *pack\items(), packItem)
    EndIf
    UnlockMutex(*pack\mutex)
    ProcedureReturn add
  EndProcedure
  
  
EndModule
