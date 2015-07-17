
DeclareModule repository
  EnableExplicit
  
  Structure files
    file_id.i
    file_name$
  EndStructure
  
  Structure mods
    mod_id.i
    mod_name$
    mod_version$
    author_id.i
    author_name$
    List files.files()
  EndStructure
  
  Declare updateRepository()
  Declare loadRepository()
  
EndDeclareModule

Module repository
  
  Global NewMap mods.mods()
  InitNetwork()
  
  Procedure updateRepository()
    Protected repo$
    repo$ = "http://update.tfmm.xanos.eu/repository.php"
    If ReceiveHTTPFile(repo$, "repository.json")
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure loadRepository()
    Protected json, value
    
    json = LoadJSON(#PB_Any, "repository.json")
    If Not json
      ProcedureReturn #False
    EndIf
    
    value = JSONValue(json)
    ExtractJSONMap(value, mods())
    
    ForEach mods()
      mods()\mod_id = Val(MapKey(mods()))
    Next
    
  EndProcedure
EndModule

CompilerIf #PB_Compiler_IsMainFile

  repository::updateRepository()
  repository::loadRepository()
  
  
  
CompilerEndIf

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 60
; FirstLine = 7
; Folding = -
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser