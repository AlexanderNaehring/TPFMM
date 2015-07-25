
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
    age.i
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
    List mods.mods()
  EndStructure
  
  Declare loadRepository(url$)
  Declare loadRepositoryList()
  
EndDeclareModule

Module repository
  Global NewList repositories$()
  Global NewMap repo_mods.repo_mods()
  
  CreateDirectory("repositories") ; subdirectory used for all repositoyry related files
  
  If Not InitNetwork()
    debugger::add("repository::init() - ERROR initializing network")
    End
  EndIf
  
  ; Private
  
  Procedure.s getRepoFileName(url$)
    ProcedureReturn "repositories/" + MD5Fingerprint(@url$, StringByteLength(url$)) + ".json"
  EndProcedure
  
  
  Procedure updateRepository(url$)
    debugger::add("repository::updateRepository("+url$+")")
    Protected file$, time
    
    file$ = getRepoFileName(url$)
    
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
    file$ = getRepoFileName(url$)
    debugger::add("repository::loadRepositoryMods("+file$+")")
    
    Protected json, value, mods
    
    If FileSize(file$) < 0
      debugger::add("repository::loadRepositoryMods() - repository file not present, load from server")
      updateRepository(url$)
    EndIf
    
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      debugger::add("repository::loadRepositoryMods() - ERROR: Could not load JSON")
      ProcedureReturn #False
    EndIf
    
    value = JSONValue(json)
    If JSONType(value) <> #PB_JSON_Object 
      debugger::add("repository::loadRepositoryMods() - ERROR: Mods Repository should be of type JSON Object")
      ProcedureReturn #False
    EndIf
    
    ExtractJSONStructure(value, repo_mods(url$), repo_mods)
    
;     mods = GetJSONMember(value, "mods")
;     
;     If JSONType(mods) <> #PB_JSON_Array
;       debugger::add("repository::loadRepositoryMods() - ERROR: Mods should be of type JSON Array")
;       ProcedureReturn #False
;     EndIf
;     ExtractJSONList(mods, mods())
    
    debugger::add("repository::loadRepositoryMods() - " + Str(ListSize(repo_mods(url$)\mods())) + " mods in repository")
    
  EndProcedure
  
  Procedure loadRepositoryLocale(url$)
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = getRepoFileName(url$)
    debugger::add("repository::loadRepositoryLocale("+file$+")")
    
    Protected json, value
    
    If FileSize(file$) < 0
      debugger::add("repository::loadRepositoryLocale() - repository file not present, load from server")
      updateRepository(url$)
    EndIf
    
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      debugger::add("repository::loadRepositoryLocale() - ERROR: Could not load JSON")
      ProcedureReturn #False
    EndIf
    
    value = JSONValue(json)
    ; value is an object
    If JSONType(value) <> #PB_JSON_Object 
      debugger::add("repository::loadRepositoryLocale() - ERROR: Locale Repository should be of type JSON Object")
      ProcedureReturn #False
    EndIf
    
  EndProcedure
  
  
  ; Public
  
  Procedure loadRepository(url$)
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = getRepoFileName(url$)
    debugger::add("repository::loadRepository("+url$+")")
    debugger::add("repository::loadRepository() - filename: {"+file$+"}")
    
    Protected repo_main.repo_main
    Protected json, value
    Protected age
    
    ; TODO check when to load new file from server!
    ; currently: relead from server every time
    updateRepository(url$)
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      debugger::add("repository::loadRepository() - ERROR opening main repository: "+JSONErrorMessage())
      ProcedureReturn #False
    EndIf
    
    value = JSONValue(json)
    If JSONType(value) <> #PB_JSON_Object
      debugger::add("repository::loadRepository() - Main Repository should be of type JSON Object")
      ProcedureReturn #False
    EndIf
    
    ExtractJSONStructure(value, repo_main, repo_main) ; no return value
    
    If repo_main\repository\name$ = ""
      debugger::add("repository::loadRepository() - Basic information missing (name) -> Skip repository")
      ProcedureReturn #False
    EndIf
    
    debugger::add("repository::loadRepository() |---- Main Repository Info:")
    debugger::add("repository::loadRepository() | Name: "+repo_main\repository\name$)
    debugger::add("repository::loadRepository() | Description: "+repo_main\repository\description$)
    debugger::add("repository::loadRepository() | Maintainer: "+repo_main\repository\maintainer$)
    debugger::add("repository::loadRepository() | URL: "+repo_main\repository\url$)
    debugger::add("repository::loadRepository() |----")
    debugger::add("repository::loadRepository() | Mods Repository URL: "+repo_main\mods\url$)
    debugger::add("repository::loadRepository() | Locale Repository URL: "+repo_main\locale\url$)
    debugger::add("repository::loadRepository() |---- ")
    
    If repo_main\mods\url$
      debugger::add("repository::loadRepository() - load mods repository...")
      age = Date() - GetFileDate(getRepoFileName(repo_main\mods\url$), #PB_Date_Modified)
      debugger::add("repository::loadRepository() - local mods repo age: "+Str(age)+", remote mods repo age: "+Str(repo_main\mods\age)+"")
      If age > repo_main\mods\age
        debugger::add("repository::loadRepository() - download new version")
        updateRepository(repo_main\mods\url$)
      EndIf
      ; Load mods from repository file
      loadRepositoryMods(repo_main\mods\url$)
    EndIf
    
    If repo_main\locale\url$
      debugger::add("repository::loadRepository() - load locale repository...")
      age = Date() - GetFileDate(getRepoFileName(repo_main\locale\url$), #PB_Date_Modified)
      debugger::add("repository::loadRepository() - local locale repo age: "+Str(age)+", remote locale repo age: "+Str(repo_main\locale\age)+"")
      If age > repo_main\locale\age
        debugger::add("repository::loadRepository() - download new version")
        updateRepository(repo_main\locale\url$)
      EndIf
      ; Load locale files from repository file
      loadRepositoryLocale(repo_main\locale\url$)
    EndIf
    
  EndProcedure
  
  Procedure loadRepositoryList()
    debugger::add("repository::loadRepositoryList()")
    Protected file, time
    
    time = ElapsedMilliseconds()
    
    ClearList(repositories$())
    file = ReadFile(#PB_Any, "repositories/repositories.list", #PB_File_SharedRead)
    If file
      While Not Eof(file)
        AddElement(repositories$())
        repositories$() = ReadString(file)
      Wend
      CloseFile(file)
    EndIf
    
    If ListSize(repositories$())
      ForEach repositories$()
        repository::loadRepository(repositories$())
      Next
      
      debugger::add("repository::loadRepositoryList() - finished loading repositories in "+Str(ElapsedMilliseconds()-time)+" ms")
      ProcedureReturn #True
    EndIf
    
    ProcedureReturn #False
  EndProcedure
  
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  
  repository::loadRepositoryList()
  
CompilerEndIf

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 77
; FirstLine = 50
; Folding = H9
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser