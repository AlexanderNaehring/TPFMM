XIncludeFile "module_debugger.pbi"

DeclareModule repository
  EnableExplicit
  
  Macro StopWindowUpdate(_winID_)
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      SendMessage_(_winID_,#WM_SETREDRAW,0,0)
    CompilerEndIf
  EndMacro
  Macro ContinueWindowUpdate(_winID_, _redrawBackground_ = 0)
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      SendMessage_(_winID_,#WM_SETREDRAW,1,0)
      InvalidateRect_(_winID_,0,_redrawBackground_)
      UpdateWindow_(_winID_)
    CompilerEndIf
  EndMacro
  
  Structure repo_info
    name$
    guid$
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
    List tags$()
    version$
    state$
    link$
    List files.files()
  EndStructure
  
  ; repository for mods
  Structure repo_mods
    repo_info.repo_info
    mod_base_url$
    file_base_url$
    thumbnail_base_url$
    List mods.mods()
  EndStructure
  
  Declare loadRepository(url$)
  Declare loadRepositoryList()
  Declare filterMods(search$, window = -1, gadget = -1)
  
  Global NewMap repo_mods.repo_mods()
EndDeclareModule

Module repository
  Global NewList repositories$()
  #DIRECTORY = "repositories"
  CreateDirectory(#DIRECTORY) ; subdirectory used for all repository related files
  
  ; Create repository list file if not existing and add basic repository
  If FileSize(#DIRECTORY+"/repositories.List") <= 0
    Define file
    file = CreateFile(#PB_Any, #DIRECTORY+"/repositories.list")
    If file
      WriteStringN(file, "http://repo.tfmm.xanos.eu/")
      CloseFile(file)
    EndIf
  EndIf
  
  If Not InitNetwork()
    debugger::add("repository::init() - ERROR initializing network")
    End
  EndIf
  
  ; Private
  
  Procedure.s getRepoFileName(url$)
    ProcedureReturn #DIRECTORY + "/" + MD5Fingerprint(@url$, StringByteLength(url$)) + ".json"
  EndProcedure
  
  Procedure updateRepository(url$)
    debugger::add("repository::updateRepository("+url$+")")
    Protected file$, time
    
    file$ = getRepoFileName(url$)
    
    time = ElapsedMilliseconds()
    If ReceiveHTTPFile(url$, file$)
      debugger::add("repository::updateRepository() - download successfull ("+Str(ElapsedMilliseconds()-time)+" ms)")
      ProcedureReturn #True
    EndIf
    debugger::add("repository::updateRepository() - ERROR: failed to download repository")
    ProcedureReturn #False
    
  EndProcedure
  
  Procedure loadRepositoryMods(url$)
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = getRepoFileName(url$)
    debugger::add("repository::loadRepositoryMods("+url$+")")
    debugger::add("repository::loadRepositoryMods() - filename: {"+file$+"}")
    
    Protected json, value, mods
    
    If FileSize(file$) < 0
      debugger::add("repository::loadRepositoryMods() - repository file not present, load from server")
      updateRepository(url$)
    EndIf
    
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      debugger::add("repository::loadRepositoryMods() - ERROR: could not parse JSON")
      ProcedureReturn #False
    EndIf
    
    value = JSONValue(json)
    If JSONType(value) <> #PB_JSON_Object 
      debugger::add("repository::loadRepositoryMods() - ERROR: mods repository should be of type JSON object")
      ProcedureReturn #False
    EndIf
    
    ; load JSON into memory:
    ; repository information and complete list of mods
    ExtractJSONStructure(value, repo_mods(url$), repo_mods)
    
    ; Sort list for last modification time
    If ListSize(repo_mods(url$)\mods())
      SortStructuredList(repo_mods(url$)\mods(), #PB_Sort_Descending, OffsetOf(mods\changed), TypeOf(mods\changed))
    EndIf
    
    ; postprocess some structure fields
    With repo_mods(url$)\mods()
      ForEach repo_mods(url$)\mods()
        If repo_mods(url$)\mod_base_url$
          \link$ = repo_mods(url$)\mod_base_url$ + \link$
        EndIf
        If repo_mods(url$)\thumbnail_base_url$
          \thumbnail$ = repo_mods(url$)\thumbnail_base_url$ + \thumbnail$
        EndIf
        If repo_mods(url$)\file_base_url$
          ForEach \files()
            \files()\link$ = repo_mods(url$)\file_base_url$ + \files()\link$
          Next
        EndIf
      Next
    EndWith
    
    debugger::add("repository::loadRepositoryMods() - " + Str(ListSize(repo_mods(url$)\mods())) + " mods in repository")
    
  EndProcedure
  
  Procedure loadRepositoryLocale(url$)
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = getRepoFileName(url$)
    debugger::add("repository::loadRepositoryLocale("+url$+")")
    debugger::add("repository::loadRepositoryLocale() - filename: {"+file$+"}")
    
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
    debugger::add("repository::loadRepository() |----")
    
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
  
  Procedure filterMods(search$, window = -1, gadget = -1)
    ; debugger::add("repository::filterMods("+search$+")")
    Protected text$, mod_ok, tmp_ok, count, i, k, str$, tags$
    
    StopWindowUpdate(WindowID(0))
    HideGadget(gadget, 0)
    ClearGadgetItems(gadget)
    
    count = CountString(search$, " ") + 1
    
    ForEach repo_mods()
      ForEach repo_mods()\mods()
        With repo_mods()\mods()
          mod_ok = 0 ; reset ok for every mod entry
          If search$ = ""
            mod_ok = 1
            count = 1
          Else
            For k = 1 To count
              tmp_ok = 0
              str$ = Trim(StringField(search$, k, " "))
              If str$
                If FindString(\author_name$, str$, 1, #PB_String_NoCase)
                  tmp_ok = 1
                ElseIf FindString(\name$, str$, 1, #PB_String_NoCase)
                  tmp_ok = 1
                Else
                  ForEach \tags$()
                    If FindString(\tags$(), str$, 1, #PB_String_NoCase)
                      tmp_ok = 1
                    EndIf
                  Next
                EndIf
              Else
                tmp_ok = 1 ; empty search string is just ignored (ok)
              EndIf
              
              If tmp_ok
                mod_ok + 1 ; increase "ok-counter"
              EndIf
            Next
          EndIf
          If mod_ok And mod_ok = count ; all substrings have to be found (ok-counter == count of substrings)
            tags$ = ""
            ForEach \tags$()
              tags$ + \tags$() + ", "
            Next
            If Len(tags$) > 2
              tags$ = Left(tags$, Len(tags$) - 2)
            EndIf
            text$ = \name$ + #LF$ +
                    \version$ + #LF$ +
                    \author_name$ + #LF$ +
                    \state$ + #LF$ +
                    tags$ + #LF$ +
                    Str(\downloads) + #LF$ +
                    Str(\likes)
            AddGadgetItem(0, i, text$)
            SetGadgetItemData(gadget, i, repo_mods()\mods())
            i + 1
          EndIf
        EndWith
      Next
    Next
    
    HideGadget(gadget, 0)
    ContinueWindowUpdate(WindowID(0))
    
  EndProcedure
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  Define text$, event
  
  debugger::setlogfile("output.log")
  
  repository::loadRepositoryList()
  
  If OpenWindow(0, 0, 0, 800, 600, "Repository Test", #PB_Window_SystemMenu|#PB_Window_MinimizeGadget|#PB_Window_ScreenCentered)
    ListIconGadget(0, 0, 30, 800, 570, "Mod Name", 240, #PB_ListIcon_FullRowSelect)
    AddGadgetColumn(0, 1, "Version", 60)
    AddGadgetColumn(0, 2, "Author", 100)
    AddGadgetColumn(0, 3, "State", 60)
    AddGadgetColumn(0, 4, "Tags", 200)
    AddGadgetColumn(0, 5, "Downloads", 60)
    AddGadgetColumn(0, 6, "Likes", 40)
    
    TextGadget(3, 515, 7, 50, 18, "Search:", #PB_Text_Right)
    StringGadget(1, 570, 5, 200, 20, "")
    ButtonGadget(2, 775, 5, 20, 20, "X")
    
    repository::filterMods("", 0 ,0) ; initially fill list
    
    Repeat
      event = WaitWindowEvent()
      Select event
        Case #PB_Event_CloseWindow
          Break
        Case #PB_Event_Gadget
          Select EventGadget()
            Case 2 ; push "x" button
              SetGadgetText(1, "")
          EndSelect
      EndSelect
      If GetGadgetText(1) <> text$
        text$ = GetGadgetText(1)
        repository::filterMods(text$, 0, 0)
      EndIf
    ForEver 
  EndIf
  
CompilerEndIf

; IDE Options = PureBasic 5.31 (Windows - x64)
; CursorPosition = 90
; FirstLine = 43
; Folding = Jh-
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser
; Executable = repository_test.exe
; Compiler = PureBasic 5.31 (Windows - x86)