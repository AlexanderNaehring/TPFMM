
XIncludeFile "module_debugger.pbi"

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
  
  
  Declare loadRepository(url$)
  
EndDeclareModule

Module repository
  Global NewList mods.mods()
  Global repo_mods.repo_mods
  
  CreateDirectory("repositories")
  
  If Not InitNetwork()
    debugger::add("repository::init() - ERROR initializing network")
    End
  EndIf
  
  ; Private
  
  Procedure updateRepository(url$)
    debugger::add("repository::updateRepository("+url$+")")
    
    Protected file$
    Protected time
    
    file$ = "repositories/" + MD5Fingerprint(@url$, StringByteLength(url$)) + ".json"
    
    time = ElapsedMilliseconds()
    If ReceiveHTTPFile(url$, file$)
      debugger::add("repository::updateRepository() - Download successfull ("+Str(ElapsedMilliseconds()-time)+" ms)")
      ProcedureReturn #True
    EndIf
    debugger::add("repository::updateRepository() - ERROR downloading repository")
    ProcedureReturn #False
    
  EndProcedure
  
  Procedure loadRepositoryMods(url$)
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = "repositories/" + MD5Fingerprint(@url$, StringByteLength(url$)) + ".json"
    
    Protected json, value, mods
    
    If FileSize(file$) < 0
      debugger::add("repository::loadRepositoryMods() - repository file not present, load from server...")
      updateRepository(url$)
    EndIf
    
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      debugger::add("repository::loadRepositoryMods() - ERROR: Could not load JSON")
      ProcedureReturn #False
    EndIf
    
    value = JSONValue(json)
    ; value is an object
    If JSONType(value) <> #PB_JSON_Object 
      debugger::add("repository::loadRepositoryMods() - ERROR: Mod Repository should be of type JSON Object")
      ProcedureReturn #False
    EndIf
    
    mods = GetJSONMember(value, "mods")
    
    If JSONType(mods) <> #PB_JSON_Array
      debugger::add("repository::loadModRepositoryMods() - ERROR: Mods should be of type JSON Array")
      ProcedureReturn #False
    EndIf
    ExtractJSONList(mods, mods())
    
    debugger::add("repository::loadModRepositoryMods() - Found " + Str(ListSize(mods())) + " Mods")
    
    ForEach mods()
;       Debug mods()\name$
      
    Next
    
  EndProcedure
  
  
  ; Public
  
  Procedure loadRepository(url$)
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = "repositories/" + MD5Fingerprint(@url$, StringByteLength(url$)) + ".json"
    debugger::add("repository::loadMainRepository("+url$+") -> {"+file$+"}")
    
    Protected repo_main.repo_main
    Protected json, value
    
    ; TODO check when to load new file from server!
    ; currently: relead from server every time
    updateRepository(url$)
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      debugger::add("ERROR opening main repository: "+JSONErrorMessage())
      ProcedureReturn #False
    EndIf
    
    value = JSONValue(json)
    If JSONType(value) <> #PB_JSON_Object
      debugger::add("Main Repository should be of type JSON Object")
      ProcedureReturn #False
    EndIf
    
    ExtractJSONStructure(value, repo_main, repo_main) ; no return value
    
    If repo_main\repository\name$ = ""
      debugger::add("Basic information missing (name) -> Skip repository")
      ProcedureReturn #False
    EndIf
    
    debugger::add("repository::loadMainRepository() |---- Main Repository Info:")
    debugger::add("repository::loadMainRepository() | Name: "+repo_main\repository\name$)
    debugger::add("repository::loadMainRepository() | Description: "+repo_main\repository\description$)
    debugger::add("repository::loadMainRepository() | Maintainer: "+repo_main\repository\maintainer$)
    debugger::add("repository::loadMainRepository() | URL: "+repo_main\repository\url$)
    debugger::add("repository::loadMainRepository() |----")
    debugger::add("repository::loadMainRepository() | Mods Repository URL: "+repo_main\mods\url$)
    debugger::add("repository::loadMainRepository() | Locale Repository URL: "+repo_main\locale\url$)
    debugger::add("repository::loadMainRepository() |---- ")
    
    If repo_main\mods\url$
      debugger::add("repository::loadMainRepository() - Found Mods Repository :-)")
      
      ; check last changed time 
      ; TODO: how to update last changed time on server? time only changes when document is retrieved...
      
      loadRepositoryMods(repo_main\mods\url$)
    EndIf
    
    If repo_main\locale\url$
      debugger::add("repository::loadMainRepository() - Found Locale Repository :-)")
      
      
    EndIf
    
  EndProcedure
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  repository::loadRepository("http://repo.tfmm.xanos.eu/")
CompilerEndIf

; IDE Options = PureBasic 5.31 (Windows - x64)
; CursorPosition = 185
; FirstLine = 127
; Folding = 8-
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser