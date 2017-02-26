XIncludeFile "module_debugger.pbi"
XIncludeFile "module_aes.pbi"
XIncludeFile "module_locale.pbi"

XIncludeFile "module_repository.h.pbi"

Module repository
  ;TODO: event number has to be unique in windowMain... 
  #EventShowUpdate = #PB_Event_FirstCustomValue+10
  
  Enumeration ; column data type
    #COL_INT
    #COL_STR
  EndEnumeration
  Structure column_info Extends column
    offset.i
    type.i
  EndStructure
  Structure type ; type information (for filtering)
    key$
    localized$
  EndStructure
  
  Global NewMap repo_mods.repo_mods()
  Global NewList repositories$()
  Global _windowMain, _listGadgetID, _thumbGadgetID, _filterGadgetID, _typeGadgetID, _sourceGadgetID
  Global Dim _columns.column_info(0)
  Global currentImageURL$
  Global NewList stackDisplayThumbnail$(), mutexStackDisplayThumb = CreateMutex()
  Global Dim type.type(0) ; type information (for filtering)
  Global _DISABLED = #False
  
  Global _windowUpdate
  
  #DIRECTORY = "repositories"
  CreateDirectory(#DIRECTORY) ; subdirectory used for all repository related files
  CreateDirectory(#DIRECTORY + "/thumbnails")
  
  
  ; Create repository list file if not existing and add basic repository
  If FileSize(#DIRECTORY+"/repositories.list") <= 0
    debugger::add("repository::init() - create repositories.list")
    Define file
    file = CreateFile(#PB_Any, #DIRECTORY+"/repositories.list")
    If file
      CloseFile(file)
    EndIf
  EndIf
  
  If Not InitNetwork()
    debugger::add("repository::init() - ERROR initializing network")
    End
  EndIf
  UseMD5Fingerprint()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure.s getRepoFileName(url$)
    ProcedureReturn #DIRECTORY + "/" + Fingerprint(@url$, StringByteLength(url$), #PB_Cipher_MD5) + ".json"
  EndProcedure
  
  Procedure.s getThumbFileName(url$)
    Protected name$, ext$
    
    If url$
      name$ = Fingerprint(@url$, StringByteLength(url$), #PB_Cipher_MD5)
      ext$ = GetExtensionPart(url$)
      If ext$
        ext$ = "." + ext$
      EndIf
      ProcedureReturn #DIRECTORY + "/thumbnails/" + Left(name$, 2) + "/" + name$ + ext$
    Else
      ProcedureReturn ""
    EndIf
  EndProcedure
  
  Procedure updateSourceGadget() ; add currently known sources to the gadget dropdown
    Protected item
    If Not _sourceGadgetID Or Not IsGadget(_sourceGadgetID)
      ProcedureReturn #False
    EndIf
    
    ClearGadgetItems(_sourceGadgetID)
    AddGadgetItem(_sourceGadgetID, 0, locale::l("repository", "all_sources"))
    item = 1
    ForEach repo_mods()
      AddGadgetItem(_sourceGadgetID, item, repo_mods()\repo_info\name$)
      SetGadgetItemData(_sourceGadgetID, item, repo_mods()\repo_info)
      item + 1
    Next
    
    SetGadgetState(_sourceGadgetID, 0)
    
  EndProcedure
  
  Procedure downloadRepository(url$)
    debugger::add("repository::downloadRepository("+url$+")")
    Protected file$, time
    
    file$ = getRepoFileName(url$)
    
    time = ElapsedMilliseconds()
    If ReceiveHTTPFile(url$, file$+".tmp")
      If FileSize(file$)
        DeleteFile(file$)
      EndIf
      RenameFile(file$+".tmp", file$)
      debugger::add("repository::downloadRepository() - download successfull ("+Str(ElapsedMilliseconds()-time)+" ms)")
      ProcedureReturn #True
    EndIf
    If FileSize(file$+".tmp")
      DeleteFile(file$+".tmp")
    EndIf
    debugger::add("repository::downloadRepository() - ERROR: failed to download repository")
    ProcedureReturn #False
    
  EndProcedure
  
  Procedure loadRepositoryMods(url$, enc$ = "")
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = getRepoFileName(url$)
    debugger::add("repository::loadRepositoryMods("+url$+", "+enc$+") - filename: {"+file$+"}")
    
    Protected json, value, mods
    
    If FileSize(file$) < 0
      debugger::add("repository::loadRepositoryMods() - repository file not present, load from server")
      downloadRepository(url$)
    EndIf
    
    Select enc$
      Case "aes_1"
        debugger::add("repository::loadRepositoryMods() - using AES decryption")
        Protected size, file, *buffer
        size = FileSize(file$)
        file = ReadFile(#PB_Any, file$)
        If Not file
          debugger::add("repository::loadRepositoryMods() - ERROR: cannot read file")
          ProcedureReturn #False
        EndIf
        
        *buffer = AllocateMemory(size)
        ReadData(file, *buffer, size)
        CloseFile(file)
        aes::decrypt(*buffer, size)
        json = CatchJSON(#PB_Any, *buffer, size)
        FreeMemory(*buffer)
        
      Default
        json = LoadJSON(#PB_Any, file$)
    EndSelect
    
    If Not json
      debugger::add("repository::loadRepositoryMods() - ERROR: could not parse JSON")
      DeleteFile(file$)
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
      SortStructuredList(repo_mods(url$)\mods(), #PB_Sort_Descending, OffsetOf(mod\timechanged), TypeOf(mod\timechanged))
    EndIf
    
    ; postprocess some structure fields
    With repo_mods(url$)\mods()
      ForEach repo_mods(url$)\mods()
        ; add base url to mod url
        If \url$
          If repo_mods(url$)\mod_base_url$
            \url$ = repo_mods(url$)\mod_base_url$ + \url$
          EndIf
        Else
          If \url$ = ""
            If \source$ = "workshop"
              \url$ = "http://steamcommunity.com/sharedfiles/filedetails/?id="+\id
            ElseIf \source$ = "tpfnet"
              \url$ = "https://www.transportfever.net/filebase/index.php/Entry/"+\id
            EndIf
          EndIf
        EndIf
        ; add base url to mod thumbnail
        If \thumbnail$
          If repo_mods(url$)\thumbnail_base_url$
            \thumbnail$ = repo_mods(url$)\thumbnail_base_url$ + \thumbnail$
          EndIf
        EndIf
        ; add base url to all files
        If repo_mods(url$)\file_base_url$
          ForEach \files()
            If \files()\url$
              \files()\url$ = repo_mods(url$)\file_base_url$ + \files()\url$
            EndIf
          Next
        EndIf
        ClearList(\tagsLocalized$())
        ForEach \tags$()
          AddElement(\tagsLocalized$())
          \tagsLocalized$() = locale::l("tags", \tags$())
        Next
      Next
    EndWith
    
    debugger::add("repository::loadRepositoryMods() - " + Str(ListSize(repo_mods(url$)\mods())) + " mods in repository")
    
    updateSourceGadget(); add this repository as new source
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure thumbnailThread(*dummy)
    ; waits for new entries in queue and displays them to the registered image gadget
    ; debugger::add("repository::thumbnailThread()")
    
    Protected url$, file$
    Protected image
    Protected scale.d
    Static NewMap images()
    Static NewMap downloading()
    
    LockMutex(mutexStackDisplayThumb)
    If ListSize(stackDisplayThumbnail$()) <= 0
      ; no element waiting in stack
      UnlockMutex(mutexStackDisplayThumb)
      ProcedureReturn #False
    EndIf
    
    ; display (and if needed download) image from top of the stack (LiFo)
    LastElement(stackDisplayThumbnail$())
    url$ = stackDisplayThumbnail$()
    DeleteElement(stackDisplayThumbnail$())
    UnlockMutex(mutexStackDisplayThumb)
    
    If FindMapElement(downloading(), url$)
      ; already downloading, skip here!
      ProcedureReturn #False
    EndIf
    
    file$ = getThumbFileName(url$)
    ; debugger::add("repository::thumbnailThread() - display image url={"+url$+"}, file={"+file$+"}")
    If file$ = ""
      debugger::add("repository::thumbnailThread() - ERROR: thumbnail filename not defined")
      ProcedureReturn #False
    EndIf
    
    ; map access is threadsafe - no need for mutex here
    If images(file$) And IsImage(images(file$))
      ; image already loaded in memory
      image = images(file$)
    Else
      ; try to load file from disk if available
      If FileSize(file$) > 0
        image = LoadImage(#PB_Any, file$)
      Else
        image = #Null
      EndIf
      If image And IsImage(image)
        images(file$) = image
      Else ; could not load from disk
        image = #Null
        ; download image
        downloading(url$) = #True
        CreateDirectory(GetPathPart(file$))
        ReceiveHTTPFile(url$, file$)
        If FileSize(file$) > 0
          image = LoadImage(#PB_Any, file$)
          If image And IsImage(image)
            images(file$) = image
          Else
            DeleteFile(file$)
            debugger::add("repository::thumbnailThread() - ERROR: could not load image {"+file$+"}")
          EndIf
        Else
          debugger::add("repository::thumbnailThread() - ERROR: download failed: {"+url$+"} -> {"+file$+"}")
        EndIf
        DeleteMapElement(downloading(), url$)
      EndIf
    EndIf
    
    If Not image Or Not _thumbGadgetID Or Not IsGadget(_thumbGadgetID)
      ProcedureReturn #False
    EndIf
    
    If ImageWidth(image) <> GadgetWidth(_thumbGadgetID)
      ; TODO also check height
      scale = GadgetWidth(_thumbGadgetID)/ImageWidth(image)
      ResizeImage(image, ImageWidth(image) * scale, ImageHeight(image) * scale)
    EndIf
    
    ; check if image that is being handled in this thread is still the current image
    ; user may have selected a different mod while this thread was downloading an image
    If currentImageURL$ = url$
      SetGadgetState(_thumbGadgetID, ImageID(image))
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure handleEventList() ; click on list gadget
    Protected *mod.mod
    Protected selected
    selected = GetGadgetState(EventGadget())
    *mod = #Null
    If selected <> -1
      *mod = GetGadgetItemData(EventGadget(), selected)
    EndIf
    If *mod
      Select EventType() 
        Case #PB_EventType_LeftDoubleClick
          If *mod\url$
            misc::openLink(*mod\url$)
          EndIf
        Case #PB_EventType_Change
          displayThumbnail(*mod\thumbnail$)
      EndSelect
    EndIf
  EndProcedure
  
  Procedure handleEventFilter() ; click on any filter gadget
    Protected n, type$, filter$, source$
    Protected *repo_info.repo_info
    If EventType() = #PB_EventType_Change Or 
       EventType() = #PB_EventType_Focus
      If IsGadget(_typeGadgetID)
        n = GetGadgetState(_typeGadgetID)
        If n >= 0 And n <= ArraySize(type())
          type$ = type(n)\key$
        EndIf
      EndIf
      If IsGadget(_filterGadgetID)
        filter$ = GetGadgetText(_filterGadgetID)
      EndIf
      If IsGadget(_sourceGadgetID)
        *repo_info = GetGadgetItemData(_sourceGadgetID, GetGadgetState(_sourceGadgetID))
        If *repo_info
          source$ = *repo_info\source$
        EndIf
      EndIf
      
      displayMods(filter$, source$, type$)
    EndIf
  EndProcedure
  
  Procedure downloadModThread(*download.download)
    If Not *download Or Not *download\mod Or Not *download\file
      ProcedureReturn #False
    EndIf
    
    If canDownload(*download\mod) <> *download\file
      ProcedureReturn #False
    EndIf
    
    ; wait for other instances to finish download...
    Static running
    While running
      Delay(100)
    Wend
    running = #True
    windowMain::progressDownload(0)
    
    Protected connection, size, downloaded, progress, finish
    Protected target$, file$, header$
    Protected json
    Static regExp
    If Not regExp
      regExp = CreateRegularExpression(#PB_Any, "Content-Length: ([0-9]+)")
    EndIf
    
    If *download\file\filename$ = ""
      *download\file\filename$ = *download\mod\source$+"-"+*download\mod\id+".zip"
    EndIf
    target$ = misc::Path(main::gameDirectory$ + "/TPFMM/download/")
    misc::CreateDirectoryAll(target$)
;     RunProgram(target$)
    file$   = target$ + *download\file\filename$
    
    debugger::add("repository::downloadModThread() - {"+*download\file\url$+"}")
    header$ = GetHTTPHeader(*download\file\url$)
    If header$
      ExamineRegularExpression(regExp, header$)
      If NextRegularExpressionMatch(regExp)
        size = Val(RegularExpressionGroup(regExp, 1))
      EndIf
      If size
        
      Else
        ; no progress known...
      EndIf
    EndIf
      
    connection = ReceiveHTTPFile(*download\file\url$, file$, #PB_HTTP_Asynchronous)
    Repeat
      progress = HTTPProgress(connection)
      Select progress
        Case #PB_Http_Success
          downloaded = FinishHTTP(connection)
          finish = #True
        Case #PB_Http_Failed
          debugger::add("repository::downloadModThread() - Error: download failed {"+*download\file\url$+"}")
          finish = #True
        Case #PB_Http_Aborted
          debugger::add("repository::downloadModThread() - Error: download aborted {"+*download\file\url$+"}")
          finish = #True
        Default 
          ; progess = bytes receiuved
          If size
            windowMain::progressDownload(progress / size)
          EndIf
      EndSelect
      Delay(50)
    Until finish
    
    If size
      windowMain::progressDownload(1)
      ; TODO display progress somewhere
    Else
      ; stop update
    EndIf
    
    If Not downloaded
      ; cleanup downlaod folder
      debugger::add("repository::downloadModThread() - download failed")
      DeleteDirectory(target$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
      FreeStructure(*download)
      running = #False
      ProcedureReturn #False
    EndIf
    
    debugger::add("repository::downloadModThread() - download complete")
    
    ; add some meta data...
    json = CreateJSON(#PB_Any)
    If json
      InsertJSONStructure(JSONValue(json), *download\mod, mod)
      SaveJSON(json, file$+".meta", #PB_JSON_PrettyPrint)
      FreeJSON(json)
    EndIf
    
    ; free download structure
    FreeStructure(*download)
    
    queue::add(queue::#QueueActionInstall, file$)
    running = #False
  EndProcedure
  
  
  ; update window functions
;   
;   Procedure updateOpenWebsite()
;     
;   EndProcedure
;   
;   Procedure updateWindowClose()
;     DisableWindow(_windowMain, #False)
;     If _windowUpdate And IsWindow(_windowUpdate)
;       HideWindow(_windowUpdate, #True)
;     EndIf
;     SetActiveWindow(_windowMain)
;   EndProcedure
;   
;   Procedure updateWindowShow()
;     
;     debugger::add("repository::updateWindowShow()")
;     If _windowUpdate And IsWindow(_windowUpdate)
;       HideWindow(_windowUpdate, #False, #PB_Window_WindowCentered)
;       DisableWindow(_windowMain, #True)
;     EndIf
;   EndProcedure
;   
;   Procedure updateWindowCreate(parentWindow)
;     DataSection
;       dataDialogXML:
;       IncludeBinary "dialogs/update.xml"
;       dataDialogXMLend:
;     EndDataSection
;     
;     ; open dialog
;     Protected xml, dialog
;     
;     xml = CatchXML(#PB_Any, ?dataDialogXML, ?dataDialogXMLend - ?dataDialogXML)
;     If Not xml Or XMLStatus(xml) <> #PB_XML_Success
;       debugger::add("repository::showUpdateWindow() - Error: could not read xml")
;     EndIf
;     
;     dialog = CreateDialog(#PB_Any)
;      
;     If Not OpenXMLDialog(dialog, xml, "update", #PB_Any, #PB_Any, #PB_Any, #PB_Any, WindowID(parentWindow))
;       debugger::add("repository::showUpdateWindow() - Error: could not open update window")
;     EndIf
;     
;     _windowUpdate = DialogWindow(dialog)
;     
;     
;     ; problem: Linux cannot unhide window from thread -> send event to main window which then will show the update window.
;     ; bind event to main window: user event is send when update window should be shown. main window received and is passed to bound function
;     ; BindEvent(#EventShowUpdate, @updateWindowShow(), parentWindow)
;     
;     BindEvent(#PB_Event_CloseWindow, @updateWindowClose(), _windowUpdate)
; ;     BindGadgetEvent(DialogGadget(dialog, "updateWebsite"), @updateOpenWebsite())
;     
;     ; has to be created by main thread?
;     
;   EndProcedure
;   
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure loadRepository(url$)
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = getRepoFileName(url$)
    debugger::add("repository::loadRepository("+url$+")")
    debugger::add("repository::loadRepository() - filename: {"+file$+"}")
    
    Protected repo_main.repo_main
    Protected json, value
    Protected age
    
    If _DISABLED
      ProcedureReturn #False 
    EndIf
    
    
    downloadRepository(url$)
    
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
    debugger::add("repository::loadRepository() | Mods Repositories: "+ListSize(repo_main\mods()))
    debugger::add("repository::loadRepository() |----")
    
    If url$ = #OFFICIAL_REPOSITORY$
      ; in main repository, check for update of TPFMM
      If repo_main\TPFMM\build And 
         repo_main\TPFMM\build > #PB_Editor_BuildCount
        debugger::add("repository::loadRepository() - TPFMM update available: "+repo_main\TPFMM\version$)
        
        ; debugger::add("repository::loadRepository() - post event to main window!")
        ; PostEvent(#EventShowUpdate, _windowMain, 0)
        ; updateWindowShow()
        
        
        ; disable repository features for outdated versions?
;         _DISABLED = #True
;         ClearMap(repo_mods())
;         ProcedureReturn #False
      EndIf
    EndIf
    
    
    If ListSize(repo_main\mods()) > 0
      ForEach repo_main\mods()
        debugger::add("repository::loadRepository() - load mods repository {"+repo_main\mods()\url$+"}...")
        age = Date() - GetFileDate(getRepoFileName(repo_main\mods()\url$), #PB_Date_Modified)
        debugger::add("repository::loadRepository() - local age: "+Str(age)+", remote age: "+Str(repo_main\mods()\age)+"")
        If age > repo_main\mods()\age
          debugger::add("repository::loadRepository() - download new version")
          downloadRepository(repo_main\mods()\url$)
        Else
          debugger::add("repository::loadRepository() - no download required")
        EndIf
        ; Load mods from repository file
        loadRepositoryMods(repo_main\mods()\url$, repo_main\mods()\enc$)
      Next
    EndIf
    
    
  EndProcedure
  
  Procedure loadRepositoryList()
    debugger::add("repository::loadRepositoryList()")
    Protected file, time
    
    time = ElapsedMilliseconds()
    
    ClearList(repositories$())
    ; always use official repository
    AddElement(repositories$())
    repositories$() = #OFFICIAL_REPOSITORY$
    ; add user defined repositories from file
    file = ReadFile(#PB_Any, #DIRECTORY+"/repositories.list", #PB_File_SharedRead)
    If file
      While Not Eof(file)
        AddElement(repositories$())
        repositories$() = ReadString(file)
      Wend
      CloseFile(file)
    Else
      debugger::add("repository::loadRepositoryList() - cannot read repositories.list")
    EndIf
    
    If ListSize(repositories$())
      ForEach repositories$()
        repository::loadRepository(repositories$())
      Next
      
      debugger::add("repository::loadRepositoryList() - finished loading repositories in "+Str(ElapsedMilliseconds()-time)+" ms")
      ProcedureReturn #True
    Else
      debugger::add("repository::loadRepositoryList() - no repositories in list")
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  ; register functions
  
  Procedure registerWindow(window)
    _windowMain = window
    If IsWindow(_windowMain)
      ; updateWindowCreate(_windowMain)
    Else
      _windowMain = #False
    EndIf
    ProcedureReturn _windowMain
  EndProcedure
  
  Procedure registerListGadget(gadget, Array columns.column(1))
    debugger::add("repository::registerListGadget(" + gadget + ")")
    Protected col
    
    ; set new gadget ID
    _listGadgetID = gadget
    If Not IsGadget(_listGadgetID)
      ; if new id is not valid, return false
      _listGadgetID = #False
      ProcedureReturn #False
    EndIf
    
    ; clear gadget item list
    ClearGadgetItems(_listGadgetID)
    
    ; clear columns
    For col = 0 To 100 ; no native way to get column count
      RemoveGadgetColumn(_listGadgetID, col)
    Next
    
    ; create _columns array
    debugger::add("repository::registerListGadget() - generate _columns")
    FreeArray(_columns())
    Dim _columns(ArraySize(columns()))
    ; in PureBasic, Dim Array(10) created array with 11 elements (0 to 10)
    ; ArraySize() returns the same size that is used with Dim
    ; therefore, real size of array is one more than returned by ArraySize()
    For col = 0 To ArraySize(columns())
      ; user can specify which columns to display
      ; internal array will save offset for reading value from memory
      ; and type of value to read (int, string, ...)
      ; TODO use locale to get translation of column header
      With _columns(col)
        ; save name and type depending on offset
        Select columns(col)\name$ ;{
          Case "name"
            \offset = OffsetOf(mod\name$)
            \name$ = "Mod Name"
            \type = #COL_STR
          Case "author"
            \offset = OffsetOf(mod\authorid)
            \name$ = "Author ID"
            \type = #COL_INT
          Case "author_name"
            \offset = OffsetOf(mod\author$)
            \name$ = "Author"
            \type = #COL_STR
          Case "thumbnail"
            Continue
            \offset = OffsetOf(mod\thumbnail$)
            \name$ = "Thumbnail"
            \type = #COL_STR
;           Case "downloads"
;             \offset = OffsetOf(mod\downloads)
;             \name$ = "Downloads"
;             \type = #COL_INT
;           Case "likes"
;             \offset = OffsetOf(mod\likes)
;             \name$ = "Likes"
;             \type = #COL_INT
          Case "timecreated"
            Continue
            \offset = OffsetOf(mod\timecreated)
            \name$ = "Created"
            \type = #COL_INT
          Case "timechanged"
            Continue
            \offset = OffsetOf(mod\timechanged)
            \name$ = "Last Modified"
            \type = #COL_INT
          Case "tags" ; list
            Continue
          Case "version"
            \offset = OffsetOf(mod\version$)
            \name$ = "Version"
            \type = #COL_STR
          Case "url"
            \offset = OffsetOf(mod\url$)
            \name$ = "URL"
            \type = #COL_STR
          Case "files" ; list
            Continue
          Default
            Continue
        EndSelect ;}
        \width = columns(col)\width
        ;debugger::add("repository::registerListGadget() - new column: {" + \name$ + "} of width {" + \width + "}")
      EndWith
    Next
    
    ; initialize new columns to gadget
    For col = 0 To ArraySize(_columns())
      Debug "column: "+_columns(col)\name$+", width = "+ _columns(col)\width
      AddGadgetColumn(_listGadgetID, col, _columns(col)\name$, _columns(col)\width)
    Next
    
    ; Bind events for gadget (left click shows image, double click opens webseite, ...)
    BindGadgetEvent(_listGadgetID, @handleEventList())
    
    ; return
    ProcedureReturn _listGadgetID
  EndProcedure
  
  Procedure registerThumbGadget(gadget)
    debugger::add("repository::registerThumbGadget(" + gadget + ")")
    
    _thumbGadgetID = gadget
    If Not IsGadget(_thumbGadgetID)
      _thumbGadgetID = #False
    EndIf
    
    ProcedureReturn _thumbGadgetID
  EndProcedure
  
  Procedure registerTypeGadget(gadget)
    Protected i.i
    debugger::add("repository::registerTypeGadget(" + gadget + ")")
    
    _typeGadgetID = gadget
    If Not IsGadget(_typeGadgetID)
      _typeGadgetID = #False
    EndIf
    
    ReDim type.type(3)
    type(0)\key$ = ""
    type(0)\localized$ = locale::l("repository", "all_types")
    type(1)\key$ = "mod"
    type(1)\localized$ = locale::l("tags", "mod")
    type(2)\key$ = "map"
    type(2)\localized$ = locale::l("tags", "map")
    type(3)\key$ = "dlc"
    type(3)\localized$ = locale::l("tags", "dlc")
    
    
    ClearGadgetItems(_typeGadgetID)
    For i = 0 To ArraySize(type())
      AddGadgetItem(_typeGadgetID, i, type(i)\localized$)
    Next
    SetGadgetState(_typeGadgetID, 0)
    
    BindGadgetEvent(_typeGadgetID, @handleEventFilter())
    
    ProcedureReturn _typeGadgetID
  EndProcedure
  
  Procedure registerSourceGadget(gadget)
    Protected i.i
    debugger::add("repository::registerSourceGadget(" + gadget + ")")
    
    _sourceGadgetID = gadget
    If _sourceGadgetID And IsGadget(_sourceGadgetID)
      updateSourceGadget()
      BindGadgetEvent(_sourceGadgetID, @handleEventFilter())
    Else
      _sourceGadgetID = #False
    EndIf
    
    ProcedureReturn _sourceGadgetID
  EndProcedure
  
  Procedure registerFilterGadget(gadget)
    debugger::add("repository::registerFilterGadget(" + gadget + ")")
    
    _filterGadgetID = gadget
    If Not IsGadget(_filterGadgetID)
      _filterGadgetID = #False
    EndIf
    
    BindGadgetEvent(_filterGadgetID, @handleEventFilter())
    
    ProcedureReturn _filterGadgetID
  EndProcedure
  
  ; display functions
  
  Procedure displayMods(search$, source$ = "", type$="")
    ; debugger::add("repository::displayMods("+search$+")")
    Protected text$, mod_ok, tmp_ok, count, item, k, col, str$, *base_address.mod, *address
    Protected *selectedMod.mod
    Protected NewList *mods_to_display() ; pointer to "mod" structured data
    
    If Not IsWindow(_windowMain) Or Not IsGadget(_listGadgetID)
      debugger::add("repository::displayMods() - ERROR: window or gadget not valid")
      ProcedureReturn #False
    EndIf
    
    HideGadget(_listGadgetID, 1)
    
    If GetGadgetState(_listGadgetID) <> -1
      *selectedMod = GetGadgetItemData(_listGadgetID, GetGadgetState(_listGadgetID))
    EndIf
    
    ClearGadgetItems(_listGadgetID)
    
    count = CountString(search$, " ") + 1
    
    ForEach repo_mods()
      ForEach repo_mods()\mods()
        With repo_mods()\mods()
          *base_address = repo_mods()\mods()
          mod_ok = 0 ; reset ok for every mod entry
          
          If type$ And \type$ <> type$
            ;TODO better way of cheking for localized version of type?
            Continue
          EndIf
          
          If source$ And \source$ <> source$
            Continue
          EndIf
          
          If search$ = ""
            mod_ok = 1
            count = 1
          Else
            For k = 1 To count
              tmp_ok = 0
              str$ = Trim(StringField(search$, k, " "))
              If str$
                ; search in author, name, tags
                ; author
                If FindString(\author$, str$, 1, #PB_String_NoCase)
                  tmp_ok = 1
                ; name
                ElseIf FindString(\name$, str$, 1, #PB_String_NoCase)
                  tmp_ok = 1
                Else
                  ; tags
                  ForEach \tags$()
                    If FindString(\tags$(), str$, 1, #PB_String_NoCase)
                      tmp_ok = 1
                    EndIf
                  Next
                  If Not tmp_ok
                    ; localized tags
                    ForEach \tagsLocalized$()
                      If FindString(\tagsLocalized$(), str$, 1, #PB_String_NoCase)
                        tmp_ok = 1
                      EndIf
                    Next
                  EndIf
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
            ; mod will be shown in list
            ; add to tmp list:
            AddElement(*mods_to_display())
            *mods_to_display() = *base_address
            
          EndIf
        EndWith
      Next
    Next
    
    ; sort list of mods-to-be-displayed
    misc::SortStructuredPointerList(*mods_to_display(), #PB_Sort_Descending, OffsetOf(mod\timechanged), #PB_Integer)
    
    ; display filtered mods:
    item = 0
    ForEach *mods_to_display()
      *base_address = *mods_to_display() ; current mod
      
      ; generate text based on specified columns
      text$ = ""
      For col = 0 To ArraySize(_columns())
        *address = *base_address + _columns(col)\offset
        Select _columns(col)\type
          Case #COL_INT
            text$ + Str(PeekI(*address))
          Case #COL_STR
            *address = PeekI(*address)
            If *address
              text$ + PeekS(*address)
            EndIf
        EndSelect
        If col < ArraySize(_columns())
          text$ + #LF$
        EndIf
      Next
      
      ; display
      AddGadgetItem(_listGadgetID, item, text$)
      SetGadgetItemData(_listGadgetID, item, *base_address)
      If *base_address\source$ = "workshop"
        SetGadgetItemImage(_listGadgetID, item, ImageID(images::Images("icon_workshop")))
      ElseIf *base_address\source$ = "tpfnet"
        SetGadgetItemImage(_listGadgetID, item, ImageID(images::Images("icon_tpfnet")))
      EndIf
      If *selectedMod And *selectedMod = *base_address
        SetGadgetState(_listGadgetID, item)
      EndIf
      
      item + 1
    Next
    
          
    HideGadget(_listGadgetID, 0)
    
  EndProcedure
  
  Procedure displayThumbnail(url$)
;     debugger::add("repository::displayThumbnail("+url$+")")
    
    LockMutex(mutexStackDisplayThumb)
    LastElement(stackDisplayThumbnail$())
    AddElement(stackDisplayThumbnail$())
    stackDisplayThumbnail$() = url$
    currentImageURL$ = url$
    UnlockMutex(mutexStackDisplayThumb)
    
    CreateThread(@thumbnailThread(), 0)
    ProcedureReturn #True
  EndProcedure
  
  ; check functions
  
  Procedure canDownload(*repoMod.mod)
    Protected nFiles
    Protected *file.file
    
    ; currently, only mods with single file can be downloaded automatically
    ForEach *repoMod\files()
      If *repoMod\files()\url$
        If *repoMod\type$ = "mod"
          nFiles + 1
          *file = *repoMod\files()
        EndIf
      EndIf
    Next
    
    If nFiles = 1
      ; start download of file and install automatically
      ProcedureReturn *file
    EndIf
    ProcedureReturn #Null
  EndProcedure
  
  Procedure downloadMod(*download.download)
    debugger::add("repository::downloadMod()")
    
    CreateThread(@downloadModThread(), *download)
  EndProcedure
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  Define text$, event
  
  UsePNGImageDecoder()
  UseJPEGImageDecoder()
  debugger::setlogfile("output.log")
  
  repository::loadRepositoryList()
  
  If OpenWindow(0, 0, 0, 800, 600, "Repository Test", #PB_Window_SystemMenu|#PB_Window_MinimizeGadget|#PB_Window_ScreenCentered)
    ListIconGadget(0, 0, 30, 600, 570, "", 0, #PB_ListIcon_FullRowSelect)
    
    Define Dim columns.repository::column(0)
    
    ; load column definition
    Define *json, *value, json$
    ; load old column settings
    *json = LoadJSON(#PB_Any, "columns.json")
    If Not *json
      ; if no column settings found, initialize with base columns
      json$ = ReplaceString("[{'width':240,'name':'name'},"+
                            "{'width':60,'name':'version'},"+
                            "{'width':100,'name':'author_name'},"+
                            "{'width':60,'name':'state'},"+
                            "{'width':200,'name':'tags_string'},"+
                            "{'width':60,'name':'downloads'},"+
                            "{'width':40,'name':'likes'}]", "'", #DQUOTE$)
      *json = ParseJSON(#PB_Any, json$)
      If Not *json
        Debug "Error loading json"
        End
      EndIf
    EndIf
    ExtractJSONArray(JSONValue(*json), columns())
    FreeJSON(*json)
    
    repository::registerWindow(0)
    repository::registerListGadget(0, columns())
    
    ; save current configuration to json file
    *json = CreateJSON(#PB_Any)
    InsertJSONArray(JSONValue(*json), columns())
    SaveJSON(*json, "columns.json", #PB_JSON_PrettyPrint)
    FreeJSON(*json)
    
    TextGadget(3, 515, 7, 50, 18, "Search:", #PB_Text_Right)
    StringGadget(1, 570, 5, 200, 20, "")
    ButtonGadget(2, 775, 5, 20, 20, "X")
    ImageGadget(3, 610, 30, 180, 500, 0)
    repository::registerThumbGadget(3)
    
    repository::filterMods("") ; initially fill list
    
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
        repository::filterMods(text$)
      EndIf
    ForEver 
  EndIf
  
CompilerEndIf
