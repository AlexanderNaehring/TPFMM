
DeclareModule repository
  EnableExplicit
  
  Structure repo_info
    name$
    description$
    maintainer$
    url$
    info_url$
    changed.i
  EndStructure
  
  Structure repo_link
    url$
    changed.i
  EndStructure
  
  ; main (root level) repository
  Structure repo_main
    repository.repo_info
    locale.repo_link
    mods.repo_link
  EndStructure
  
  Structure files
    file_id.i
    filename$
    downloads.i
    link$
  EndStructure
  
  Structure mods
    mod_id.i
    name$
    author_id.i
    author_name$
    thumbnail$
    views.i
    downloads.i
    likes.i
    created.i
    changed.i
    category.i
    version$
    state$
    link$
    List files.files()
  EndStructure
  
  ; repository for mods
  Structure repo_mods
    repo_info.repo_info
    mod_base_url$
    Map mods.mods()
  EndStructure
  
  
  Declare updateRepository()
  Declare loadRepository()
  
EndDeclareModule

Module repository
  InitNetwork()
  
  Global NewList mods.mods()
  Global repo_mods.repo_mods
  
  
  Procedure updateRepository()
    Protected repo$
    repo$ = "http://repo.tfmm.xanos.eu/mods/"
    If ReceiveHTTPFile(repo$, "repository.json")
      Debug "ok"
      ProcedureReturn #True
    EndIf
    Debug "error"
    ProcedureReturn #False
  EndProcedure
  
  Procedure loadRepository()
    Protected json, value, mods
    
    json = LoadJSON(#PB_Any, "repository.json")
    If Not json
      Debug "Could not load JSON"
      ProcedureReturn #False
    EndIf
    
    value = JSONValue(json)
    ; value is an object
    If JSONType(value) <> #PB_JSON_Object 
      Debug "Mod Repository should be of type JSON Object"
      ProcedureReturn #False
    EndIf
    
    mods = GetJSONMember(value, "mods")
    
    If JSONType(mods) <> #PB_JSON_Array
      Debug "Error Mods should be of type JSON Array"
      ProcedureReturn #False
    EndIf
    ExtractJSONList(mods, mods())
    
    Debug Str(ListSize(mods())) + " Mods"
    
    ForEach mods()
      Debug mods()\name$
    Next
    
    
    
  EndProcedure
EndModule

CompilerIf #PB_Compiler_IsMainFile
  Debug "start"
  
  Debug "update Repo"
  repository::updateRepository()
  
  Debug "load Repo"
  repository::loadRepository()
  
  
  
CompilerEndIf

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 98
; FirstLine = 73
; Folding = -
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser