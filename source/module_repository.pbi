
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
    repo$ = "http://update.alexandernaehring.eu/tfmm/mods.php"
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


repository::updateRepository()
repository::loadRepository()
; IDE Options = PureBasic 5.31 (Windows - x64)
; CursorPosition = 50
; Folding = -
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser