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
  Global NewList repositories.repository()
  Global mutexRepoMods = CreateMutex() ; coordinate access to "repo_mods()" map
  
  Global _windowMain, _listGadgetID, _thumbGadgetID, _filterGadgetID, _typeGadgetID, _sourceGadgetID, _installedGadgetID
  Global Dim _columns.column_info(0)
  Global currentImageURL$
  Global NewList stackDisplayThumbnail$(), mutexStackDisplayThumb = CreateMutex()
  Global Dim type.type(0) ; type information (for filtering)
  Global _DISABLED = #False
  Global _UPDATE_URL$ = ""
  
  Global NewMap settingsGadget()
  
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
    LockMutex(mutexRepoMods)
    ForEach repo_mods()
      AddGadgetItem(_sourceGadgetID, item, repo_mods()\repo_info\name$)
      SetGadgetItemData(_sourceGadgetID, item, repo_mods()\repo_info)
      item + 1
    Next
    UnlockMutex(mutexRepoMods)
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
    debugger::add("repository::loadRepositoryMods() "+url$)
    
    Protected json, value, mods
    
    If FileSize(file$) < 0
      debugger::add("repository::loadRepositoryMods() - download: "+url$)
      If Not downloadRepository(url$)
        ; download failed
        ProcedureReturn #False 
      EndIf
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
    LockMutex(mutexRepoMods)
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
    
    UnlockMutex(mutexRepoMods)
    
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
    
    
    If FindMapElement(images(), file$) And images(file$) And IsImage(images(file$))
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
  
  Procedure downloadModThread(*download.download)
    If Not *download Or *download\source$ = "" Or Not *download\id
      ProcedureReturn #False
    EndIf
    
    Protected source$, id.q, fileID.q
    source$ = *download\source$
    id      = *download\id
    fileID  = *download\fileID
    FreeStructure(*download)
    
    ;TODO: allow direct download of HTTP(S) link
    ; if source == a loaded source
    ; if source = http(s)://...... -> direct download
    ;
    ; e.g. getRepoBySource(source$)...
    ; if no repo found -> try direct download...
    
    Protected *mod.mod, *file.file
    *mod = getModByID(source$, id)
    *file = getFileByID(*mod, fileID) ; returns vaid pointer even if fileID = 0 when only one file in mod
    
    If Not *mod
      debugger::add("repository::downloadModThread() - Error: could not find modID /"+source$+"/"+id)
      ProcedureReturn #False
    EndIf
    If Not canDownloadMod(*mod)
      debugger::add("repository::downloadModThread() - Error: cannot download mod")
      ProcedureReturn #False
    EndIf
    If Not *file
      debugger::add("repository::downloadModThread() - Error: could not find fileID /"+source$+"/"+id+"/"+fileID)
      ProcedureReturn #False
    EndIf
    If Not canDownloadFile(*file)
      debugger::add("repository::downloadModThread() - Error: cannot download file")
      ProcedureReturn #False
    EndIf
    
    
    
    ; wait for other threads to finish download...
    Static running
    While running
      Delay(100)
    Wend
    running = #True
    windowMain::progressDownload(0, *mod\name$)
    
    ; start process...
    Protected connection, size, downloaded, progress, finish
    Protected target$, file$, header$
    Protected json
    Protected HTTPstatus
    Static regExpContentLength, regExpHTTPstatus
    If Not regExpContentLength
      regExpContentLength = CreateRegularExpression(#PB_Any, "Content-Length: ([0-9]+)")
    EndIf
    If Not regExpHTTPstatus
      regExpHTTPstatus = CreateRegularExpression(#PB_Any, "HTTP/1.\d (\d\d\d)")
    EndIf
    
    
    If *file\filename$ = ""
      *file\filename$ = *mod\source$+"-"+*mod\id+".zip"
    EndIf
    
    target$ = misc::Path(main::gameDirectory$ + "/TPFMM/download/")
    misc::CreateDirectoryAll(target$)
;     RunProgram(target$)
    file$   = target$ + *file\filename$
    
    debugger::add("repository::downloadModThread() - {"+*file\url$+"}")
    header$ = GetHTTPHeader(*file\url$)
    If header$
      
      ExamineRegularExpression(regExpHTTPstatus, header$)
      If NextRegularExpressionMatch(regExpHTTPstatus)
        HTTPstatus = Val(RegularExpressionGroup(regExpHTTPstatus, 1))
        If HTTPstatus = 404
          debugger::add("repository::downloadModThread() - server response: 404 File Not Found")
          windowMain::progressDownload(-2, *mod\name$)
          running = #False
          ProcedureReturn #False
        EndIf
      EndIf
      
      ExamineRegularExpression(regExpContentLength, header$)
      If NextRegularExpressionMatch(regExpContentLength)
        size = Val(RegularExpressionGroup(regExpContentLength, 1))
      EndIf
      If size
        
      Else
        ; no progress known...
      EndIf
    EndIf
      
    connection = ReceiveHTTPFile(*file\url$, file$, #PB_HTTP_Asynchronous)
    Repeat
      progress = HTTPProgress(connection)
      Select progress
        Case #PB_Http_Success
          downloaded = FinishHTTP(connection)
          finish = #True
        Case #PB_Http_Failed
          debugger::add("repository::downloadModThread() - Error: download failed {"+*file\url$+"}")
          finish = #True
        Case #PB_Http_Aborted
          debugger::add("repository::downloadModThread() - Error: download aborted {"+*file\url$+"}")
          finish = #True
        Default 
          ; progess = bytes receiuved
          If size
            windowMain::progressDownload(progress / size, *mod\name$)
          EndIf
      EndSelect
      Delay(50)
    Until finish
    
    If size
      windowMain::progressDownload(1, *mod\name$)
      ; TODO display progress somewhere
    Else
      ; stop update
    EndIf
    
    If Not downloaded
      ; cleanup downlaod folder
      debugger::add("repository::downloadModThread() - download failed")
      windowMain::progressDownload(-2, *mod\name$)
      DeleteDirectory(target$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)
      running = #False
      ProcedureReturn #False
    EndIf
    
    debugger::add("repository::downloadModThread() - download complete")
    
    ; add some meta data...
    json = CreateJSON(#PB_Any)
    If json
      InsertJSONStructure(JSONValue(json), *mod, mod)
      SaveJSON(json, file$+".meta", #PB_JSON_PrettyPrint)
      FreeJSON(json)
    EndIf
    
    mods::install(file$)
    running = #False
  EndProcedure
  
  Procedure checkInstalled()
    Protected source$, id.i
    
    LockMutex(mutexRepoMods)
    ForEach repo_mods()
      ForEach repo_mods()\mods()
        source$ = repo_mods()\mods()\source$
        id      = repo_mods()\mods()\id
        
        repo_mods()\mods()\installed = mods::isInstalled(source$, id)
      Next
    Next
    UnlockMutex(mutexRepoMods)
    
  EndProcedure
  
  Procedure showUpdate()
    If MessageRequester(locale::l("repository","update"), locale::l("repository","update_text"), #PB_MessageRequester_Info|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
      If _UPDATE_URL$
        misc::openLink(_UPDATE_URL$)
      Else
        misc::openLink(main::WEBSITE$)
      EndIf
      main::exit()
    EndIf
  EndProcedure
  
  Procedure loadRepository(*repository.repository)
    Protected file$ ; parameter: URL -> calculate local filename from url
    
    file$ = getRepoFileName(*repository\url$)
    debugger::add("repository::loadRepository() "+*repository\url$)
    
    Protected json, value
    Protected age
    
    If _DISABLED
      ProcedureReturn #False 
    EndIf
    
    ; main repository: always request new version from server!
    If Not downloadRepository(*repository\url$)
      ProcedureReturn #False
    EndIf
    
    
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
    
    InitializeStructure(*repository\main_json, main_json)
    ExtractJSONStructure(value, *repository\main_json, main_json) ; no return value
    
    If *repository\main_json\repository\name$ = ""
      debugger::add("repository::loadRepository() - Basic information missing (name) -> Skip repository")
      ProcedureReturn #False
    EndIf
    
    debugger::add("repository::loadRepository() |---- Main Repository Info:")
    debugger::add("repository::loadRepository() | Name: "+*repository\main_json\repository\name$)
    debugger::add("repository::loadRepository() | Description: "+*repository\main_json\repository\description$)
    debugger::add("repository::loadRepository() | Maintainer: "+*repository\main_json\repository\maintainer$)
    debugger::add("repository::loadRepository() | URL: "+*repository\main_json\repository\url$)
    debugger::add("repository::loadRepository() |----")
    debugger::add("repository::loadRepository() | Mods Repositories: "+ListSize(*repository\main_json\mods()))
    debugger::add("repository::loadRepository() |----")
    
    If *repository\url$ = #OFFICIAL_REPOSITORY$
      ; in main repository, check for update of TPFMM
      If *repository\main_json\TPFMM\build And 
         *repository\main_json\TPFMM\build > #PB_Editor_CompileCount
        debugger::add("repository::loadRepository() - TPFMM update available: "+*repository\main_json\TPFMM\version$)
        
        CopyStructure(*repository\main_json\TPFMM, TPFMM_UPDATE, tpfmm)
        _UPDATE_URL$ = *repository\main_json\TPFMM\url$
        BindEvent(#EventShowUpdate, @showUpdate(), _windowMain)
        PostEvent(#EventShowUpdate, _windowMain, 0)
        
        ; disable repository features for outdated versions?
        _DISABLED = #True
        LockMutex(mutexRepoMods)
        ClearMap(repo_mods())
        UnlockMutex(mutexRepoMods)
        ProcedureReturn #False
      Else
        debugger::add("repository::loadRepository() - TPFMM is up to date")
      EndIf
    EndIf
    
    
    If ListSize(*repository\main_json\mods()) > 0
      ForEach *repository\main_json\mods()
        debugger::add("repository::loadRepository() - load mods repository {"+*repository\main_json\mods()\url$+"}...")
        age = Date() - GetFileDate(getRepoFileName(*repository\main_json\mods()\url$), #PB_Date_Modified)
        debugger::add("repository::loadRepository() - local age: "+Str(age)+", remote age: "+Str(*repository\main_json\mods()\age)+"")
        If age > *repository\main_json\mods()\age
          debugger::add("repository::loadRepository() - local repository not up to date")
          DeleteFile(getRepoFileName(*repository\main_json\mods()\url$))
        EndIf
        ; Load mods from repository file
        loadRepositoryMods(*repository\main_json\mods()\url$, *repository\main_json\mods()\enc$)
      Next
    EndIf
    
    
  EndProcedure
  
  Procedure loadRepositoryList()
    debugger::add("repository::loadRepositoryList()")
    Protected file, time
    
    time = ElapsedMilliseconds()
    
    
    ; clean all lists
    ClearList(repositories())
    LockMutex(mutexRepoMods)
    ClearMap(repo_mods())
    UnlockMutex(mutexRepoMods)
    displayMods() ; show clean gadget list
    
    ; always use official repository
    AddElement(repositories())
    repositories()\url$ = #OFFICIAL_REPOSITORY$
    
    ; add user defined repositories from file
    file = ReadFile(#PB_Any, #DIRECTORY+"/repositories.list", #PB_File_SharedRead)
    If file
      While Not Eof(file)
        AddElement(repositories())
        repositories()\url$ = ReadString(file)
      Wend
      CloseFile(file)
    Else
      debugger::add("repository::loadRepositoryList() - cannot read repositories.list")
    EndIf
    ;-TODO: save repos as json as well?
    
    If ListSize(repositories())
      ForEach repositories()
        loadRepository(repositories())
      Next
      
      debugger::add("repository::loadRepositoryList() - finished loading repositories in "+Str(ElapsedMilliseconds()-time)+" ms")
      ProcedureReturn #True
    Else
      debugger::add("repository::loadRepositoryList() - no repositories in list")
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure initThread(*dummy)
    While Not mods::isLoaded
      ; do not start repository update while mods are loading
      Delay(100)
    Wend
    loadRepositoryList()
    displayMods() ; initially fill list
    mods::displayMods()       ; update mod list to show remote links
  EndProcedure
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  ; load repositories...
  
  Procedure init()
    debugger::add("repository::init()")
    
    Static thread 
    
    If thread And IsThread(thread)
      KillThread(thread)
    EndIf
    
    thread = CreateThread(@initThread(), 0)
    
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
          Case "version"
            \offset = OffsetOf(mod\version$)
            \name$ = "Version"
            \type = #COL_STR
          Case "url"
            \offset = OffsetOf(mod\url$)
            \name$ = "URL"
            \type = #COL_STR
          Case "installed"
            \offset = OffsetOf(mod\installed)
            \name$ = "Status"
            \type = #COL_INT
            
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
  
  Procedure registerFilterGadgets(gadgetString, gadgetType, gadgetSource, gadgetInstalled)
    Protected i.i
    
    ; string gadget
    
    _filterGadgetID = gadgetString
    If Not IsGadget(_filterGadgetID)
      _filterGadgetID = #False
    EndIf
    BindGadgetEvent(_filterGadgetID, @displayMods())
    
    
    ; combobox: type
    
    _typeGadgetID = gadgetType
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
    
    BindGadgetEvent(_typeGadgetID, @displayMods())
    
    
    ; combobox: source
    
    _sourceGadgetID = gadgetSource
    If _sourceGadgetID And IsGadget(_sourceGadgetID)
      updateSourceGadget()
      BindGadgetEvent(_sourceGadgetID, @displayMods())
    Else
      _sourceGadgetID = #False
    EndIf
    
    
    ; combobox: installed
    
    _installedGadgetID = gadgetInstalled
    If Not IsGadget(_installedGadgetID)
      _installedGadgetID = #False
    EndIf
    
    ClearGadgetItems(_installedGadgetID)
    AddGadgetItem(_installedGadgetID, 0, locale::l("repository", "installed_all"))
    AddGadgetItem(_installedGadgetID, 1, locale::l("repository", "installed_yes"))
    AddGadgetItem(_installedGadgetID, 2, locale::l("repository", "installed_no"))
    SetGadgetState(_installedGadgetID, 0)
    
    BindGadgetEvent(_installedGadgetID, @displayMods())
    
    
    ProcedureReturn #True
  EndProcedure
  
  
  ; display functions
  
  Procedure displayMods()
    ; debugger::add("repository::displayMods("+search$+")")
    Protected search$, type$, source$, installed.i
    Protected *repo_info.repo_info, n.i
    Protected text$, mod_ok, tmp_ok, count, item, k, col, str$, *base_address.mod, *address
    Protected *selectedMod.mod
    Protected NewList *mods_to_display() ; pointer to "mod" structured data
    
    If Not IsWindow(_windowMain) Or Not IsGadget(_listGadgetID)
      debugger::add("repository::displayMods() - ERROR: window or gadget not valid")
      ProcedureReturn #False
    EndIf
    
    If _DISABLED
      AddGadgetItem(_listGadgetID, 0, locale::l("repository","disabled_update"))
      SetGadgetItemColor(_listGadgetID, 0, #PB_Gadget_FrontColor, RGB($A0, $00, $00))
      ProcedureReturn #False
    EndIf
    
    
    ; get filter parameters
    If _filterGadgetID And IsGadget(_filterGadgetID)
      search$ = GetGadgetText(_filterGadgetID)
    EndIf
    If _typeGadgetID And IsGadget(_typeGadgetID)
      n = GetGadgetState(_typeGadgetID)
      If n >= 0 And n <= ArraySize(type())
        type$ = type(n)\key$
      EndIf
    EndIf
    If _sourceGadgetID And IsGadget(_sourceGadgetID)
      *repo_info = GetGadgetItemData(_sourceGadgetID, GetGadgetState(_sourceGadgetID))
      If *repo_info
        source$ = *repo_info\source$
      EndIf
    EndIf
    If _installedGadgetID And IsGadget(_installedGadgetID)
      installed = GetGadgetState(_installedGadgetID)
      ; 0 = all, 1 = installed, 2 = not installed
    EndIf
    
    
    
    
    
    HideGadget(_listGadgetID, 1)
    
    If GetGadgetState(_listGadgetID) <> -1
      *selectedMod = GetGadgetItemData(_listGadgetID, GetGadgetState(_listGadgetID))
    EndIf
    
    ClearGadgetItems(_listGadgetID)
    
    checkInstalled()
    
    count = CountString(search$, " ") + 1
    
    LockMutex(mutexRepoMods)
    
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
          
          If installed ; 1 = only show installed, 2 = only show not installed
            If installed = 1 And \installed = 0
              Continue
            ElseIf installed = 2 And \installed = 1
              Continue
            EndIf
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
    
    UnlockMutex(mutexRepoMods)
    
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
      If *base_address\installed
        SetGadgetItemColor(_listGadgetID, item, #PB_Gadget_FrontColor, RGB($00, $66, $00))
;         SetGadgetItemColor(_listGadgetID, item, #PB_Gadget_BackColor, RGB($F0, $F0, $F0))
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
  
  Procedure selectModInList(*mod.mod)
    ; remove all filters
    Protected item, *mod_in_list.mod
    If _listGadgetID And IsGadget(_listGadgetID)
      If _filterGadgetID And IsGadget(_filterGadgetID)
        SetGadgetText(_filterGadgetID, "")
      EndIf
      If _typeGadgetID And IsGadget(_typeGadgetID)
        SetGadgetState(_typeGadgetID, 0)
      EndIf
      If _sourceGadgetID And IsGadget(_sourceGadgetID)
        SetGadgetState(_sourceGadgetID, 0)
      EndIf
      If _installedGadgetID And IsGadget(_installedGadgetID)
        SetGadgetState(_installedGadgetID, 0)
      EndIf
      displayMods()
      ; trigger "change" event on list for thumbnail preview, button update, etc...
      PostEvent(#PB_Event_Gadget, _windowMain, _listGadgetID, #PB_EventType_Change)
      
      For item = 0 To CountGadgetItems(_listGadgetID) -1
        *mod_in_list = GetGadgetItemData(_listGadgetID, item)
        If *mod_in_list = *mod
          SetGadgetState(_listGadgetID, item)
          ProcedureReturn #True
        EndIf
      Next
    EndIf
    
    ProcedureReturn #False
  EndProcedure
  
  Procedure searchMod(name$, author$="")
    ; set filters to search for mod
    If author$
      name$ + " " + author$
    EndIf
    
    If _listGadgetID And IsGadget(_listGadgetID)
      If _filterGadgetID And IsGadget(_filterGadgetID)
        SetGadgetText(_filterGadgetID, name$)
        displayMods()
        ; trigger "change" event on list for thumbnail preview, button update, etc...
        PostEvent(#PB_Event_Gadget, _windowMain, _listGadgetID, #PB_EventType_Change)
        ProcedureReturn #True
      EndIf
    EndIf
    
    ProcedureReturn #False
  EndProcedure
  
  
  ; check functions
  Procedure canDownloadFile(*file.file)
    If *file And *file\url$
      ProcedureReturn #True
    EndIf
  EndProcedure
  
  Procedure canDownloadMod(*repoMod.mod)
    Protected nFiles
    
    ; currently, only mods with single file can be downloaded automatically
    If *repoMod\type$ = "mod"
      ForEach *repoMod\files()
        If canDownloadFile(*repoMod\files())
          nFiles + 1
        EndIf
      Next
    EndIf
    
    If nFiles > 0
      ; start download of file and install automatically
      ProcedureReturn nFiles
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure getModByID(source$, id.q)
    Protected *repoMod.mod
    Protected *file.file
    
    LockMutex(mutexRepoMods)
    ForEach repo_mods()
      If repo_mods()\repo_info\source$ = source$
        ForEach repo_mods()\mods()
          If repo_mods()\mods()\id = id
            *repoMod = repo_mods()\mods()
            Break 2
          EndIf
        Next
      EndIf
    Next
    UnlockMutex(mutexRepoMods)
    
    ProcedureReturn *repoMod
  EndProcedure
  
  Procedure getFileByID(*repoMod.mod, fileID.q)
    Protected *file.file
    
    If *repoMod
      LockMutex(mutexRepoMods)
      If fileID 
        ; fileID given - search for this fileID
        ForEach *repoMod\files()
          If *repoMod\files()\fileID = fileID
            *file = *repoMod\files()
            Break
          EndIf
        Next
      Else 
        ; no fileID given
        If ListSize(*repoMod\files()) = 1
          ; if only one file in mod - return this file
          FirstElement(*repoMod\files())
          *file = *repoMod\files()
        EndIf
        ; if more files in mod, return false / null
      EndIf
      UnlockMutex(mutexRepoMods)
    EndIf
    
    ProcedureReturn *file
  EndProcedure
  
  Procedure canDownloadModByID(source$, id.q, fileID.q = 0)
    Protected *repoMod.mod
    Protected *file.file
    
    *repoMod = getModByID(source$, id)
    
    If Not *repoMod
      debugger::add("repository::canDownloadModByID() - Could not find mod "+source$+"-"+id)
      ProcedureReturn #False
    EndIf
    
    If fileID
      *file = getFileByID(*repoMod, fileID)
    EndIf
    
    If fileID
      ProcedureReturn Bool(canDownloadMod(*repoMod) And canDownloadFile(*file))
    Else
      ProcedureReturn canDownloadMod(*repoMod)
    EndIf
  EndProcedure
  
  Procedure downloadMod(source$, id.q, fileID.q = #Null)
    debugger::add("repository::downloadMod() download/"+source$+"/"+id+"/"+fileID+"")
    Protected *buffer.download
    
    ; copy structure so that data stays available in thread
    *buffer = AllocateStructure(download) ; memory is freed in thread function!
    *buffer\source$ = source$
    *buffer\id      = id
    *buffer\fileID  = fileID
    
    ; call thread
    CreateThread(@downloadModThread(), *buffer)
  EndProcedure
  
  Procedure findModOnline(*mod.mods::mod)  ; search for mod in repository, return pointer ro repository::mod
    Protected *find = #Null
    LockMutex(mutexRepoMods)
    
    If *mod\aux\tfnetID
      ForEach repo_mods()
        If repo_mods()\repo_info\source$ <> "tpfnet"
          Continue
        EndIf
        ForEach repo_mods()\mods()
          If repo_mods()\mods()\id = *mod\aux\tfnetID
            *find = repo_mods()\mods()
            Break 2
          EndIf
        Next
      Next
      
    ElseIf *mod\aux\workshopID
      ForEach repo_mods()
        If repo_mods()\repo_info\source$ <> "workshop"
          Continue
        EndIf
        ForEach repo_mods()\mods()
          If repo_mods()\mods()\id = *mod\aux\workshopID
            *find = repo_mods()\mods()
            Break 2
          EndIf
        Next
      Next
    EndIf
    
    UnlockMutex(mutexRepoMods)
    
    ProcedureReturn *find
  EndProcedure
  
  Procedure findModByID(source$, id.q)
    debugger::add("repository::findModByID("+source$+","+id+")")
    Protected *find.mod
    LockMutex(mutexRepoMods)
    
    ForEach repo_mods()
      If repo_mods()\repo_info\source$ = source$
        ForEach repo_mods()\mods()
          If repo_mods()\mods()\source$ = source$ And 
             repo_mods()\mods()\id      = id
            *find = repo_mods()\mods()
            debugger::add("repository::findModByID("+source$+","+id+") - found mod '"+*find\name$+"'")
            Break 2
          EndIf
        Next
      EndIf
    Next
    
    UnlockMutex(mutexRepoMods)
    ProcedureReturn *find
  EndProcedure
  
  ; list all available repos in settings gadget
  
  Procedure infoCallback()
    Protected item, *repository.repository
    
    SetGadgetText(settingsGadget("repositoryName"), "")
    SetGadgetText(settingsGadget("repositoryCurator"), "")
    SetGadgetText(settingsGadget("repositoryDescription"), "")
    DisableGadget(settingsGadget("repositoryRemove"), #True)
        
    item = GetGadgetState(settingsGadget("repositoryList"))
    If item <> -1
      *repository = GetGadgetItemData(settingsGadget("repositoryList"), item)
      If *repository
        SetGadgetText(settingsGadget("repositoryName"), *repository\main_json\repository\name$)
        SetGadgetText(settingsGadget("repositoryCurator"), *repository\main_json\repository\maintainer$)
        SetGadgetText(settingsGadget("repositoryDescription"), *repository\main_json\repository\description$)
        If *repository\url$ <> #OFFICIAL_REPOSITORY$
          DisableGadget(settingsGadget("repositoryRemove"), #False)
        EndIf
      EndIf
    EndIf
    
  EndProcedure
  
  Procedure listRepositories(Map gadgets())
    Protected item
    
    If settingsGadget("repositoryList") And IsGadget(settingsGadget("repositoryList"))
      UnbindGadgetEvent(settingsGadget("repositoryList"), @infoCallback())
    EndIf
    
    CopyMap(gadgets(), settingsGadget())
    
    
    BindGadgetEvent(settingsGadget("repositoryList"), @infoCallback())
    
    ClearGadgetItems(settingsGadget("repositoryList"))
    
    ForEach repositories()
      AddGadgetItem(settingsGadget("repositoryList"), item, repositories()\url$)
      SetGadgetItemData(settingsGadget("repositoryList"), item, repositories())
      item + 1
    Next
    
  EndProcedure
  
  Procedure refresh()
    Protected dir$, entry$, dir
    
    dir$ = #DIRECTORY + "/"
    Debug dir$
    dir = ExamineDirectory(#PB_Any, dir$, "*.json")
    If dir
      While NextDirectoryEntry(dir)
        entry$ = DirectoryEntryName(dir)
        Debug entry$
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          DeleteFile(dir$ + entry$)
        EndIf
      Wend
      FinishDirectory(dir)
    EndIf
    
    init()
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure clearCache()
    Protected dir$
    
    dir$ = #DIRECTORY + "/thumbnails/"
    DeleteDirectory(dir$, "", #PB_FileSystem_Recursive)
    CreateDirectory(dir$)
    
    ProcedureReturn #True
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
