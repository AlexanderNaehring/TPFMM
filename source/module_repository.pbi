﻿XIncludeFile "module_debugger.pbi"
XIncludeFile "module_aes.pbi"
XIncludeFile "module_locale.pbi"

DeclareModule repository
  EnableExplicit
  
  Macro StopWindowUpdate(_winID_)
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        ;SendMessage_(_winID_,#WM_SETREDRAW,0,0)
      CompilerCase #PB_OS_Linux
        
      CompilerCase #PB_OS_MacOS
        CocoaMessage(0,_winID_,"disableFlushWindow")
    CompilerEndSelect
  EndMacro
  Macro ContinueWindowUpdate(_winID_, _redrawBackground_ = 0)
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        ;SendMessage_(_winID_,#WM_SETREDRAW,1,0)
        InvalidateRect_(_winID_,0,_redrawBackground_)
        UpdateWindow_(_winID_)
      CompilerCase #PB_OS_Linux
        
      CompilerCase #PB_OS_MacOS
        CocoaMessage(0,_winID_,"enableFlushWindow")
    CompilerEndSelect
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
    enc$
  EndStructure
  
  ; main (root level) repository
  Structure repo_main
    repository.repo_info
    mods.repo_link
  EndStructure
  
  Structure files
    file_id.i
    filename$
    downloads.i
    url$
  EndStructure
  
  Structure mod
    id.i
    source$
    remote_id.i
    name$
    author$
    authorid.i
    version$
    type$
    url$
    thumbnail$
    views.i
    timecreated.i
    timechanged.i
    lastscan.i
    List files.files()
    List tags$()
    List tagsLocalized$()
  EndStructure
  
  ; repository for mods
  Structure repo_mods
    repo_info.repo_info
    mod_base_url$
    file_base_url$
    thumbnail_base_url$
    List mods.mod()
  EndStructure
  
  ; public column identifier
  Structure column
    name$
    width.i
  EndStructure
  
  Declare loadRepository(url$)
  Declare loadRepositoryList()
  
  Declare registerWindow(windowID)
  Declare registerListGadget(gadgetID, Array columns.column(1))
  Declare registerThumbGadget(gadgetID)
  Declare registerTypeGadget(gadgetID)
  Declare registerFilterGadget(gadgetID)
  Declare filterMods(type$, search$)
  Declare displayThumbnail(url$)
  
  Global NewMap repo_mods.repo_mods()
EndDeclareModule

Module repository
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
  
  Global NewList repositories$()
  Global _windowID, _listGadgetID, _thumbGadgetID, _filterGadgetID, _typeGadgetID
  Global Dim _columns.column_info(0)
  Global currentImageURL$
  Global NewList stackDisplayThumbnail$(), mutexStackDisplayThumb = CreateMutex()
  Global Dim type.type(0) ; type information (for filtering)
  
  #DIRECTORY = "repositories"
  CreateDirectory(#DIRECTORY) ; subdirectory used for all repository related files
  CreateDirectory(#DIRECTORY + "/thumbnails")
  
  
  ; Create repository list file if not existing and add basic repository
  If FileSize(#DIRECTORY+"/repositories.list") <= 0
    debugger::add("repository::init() - create repositories.list")
    Define file
    file = CreateFile(#PB_Any, #DIRECTORY+"/repositories.list")
    If file
      WriteStringN(file, "http://www.transportfevermods.com/repository/repository.json")
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
      ProcedureReturn #DIRECTORY + "/thumbnails/" + Left(name$, 2) + "/" + name$ + "." + ext$
    Else
      ProcedureReturn ""
    EndIf
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
  
  Procedure loadRepositoryMods(url$, enc$ = "")
    Protected file$ ; parameter: URL -> calculate local filename from url
    file$ = getRepoFileName(url$)
    debugger::add("repository::loadRepositoryMods("+url$+", "+enc$+") - filename: {"+file$+"}")
    
    Protected json, value, mods
    
    If FileSize(file$) < 0
      debugger::add("repository::loadRepositoryMods() - repository file not present, load from server")
      updateRepository(url$)
    EndIf
    
    Select enc$
      Case "aes"
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
        If repo_mods(url$)\mod_base_url$
          \url$ = repo_mods(url$)\mod_base_url$ + \url$
        EndIf
        ; add base url to mod thumbnail
        If repo_mods(url$)\thumbnail_base_url$
          \thumbnail$ = repo_mods(url$)\thumbnail_base_url$ + \thumbnail$
        EndIf
        ; add base url to all files
        If repo_mods(url$)\file_base_url$
          ForEach \files()
            \files()\url$ = repo_mods(url$)\file_base_url$ + \files()\url$
          Next
        EndIf
        ; tags are stored without localization here (english)
        ; only display translated strings but store original strings
        ClearList(\tagsLocalized$())
        ForEach \tags$()
          AddElement(\tagsLocalized$())
          \tagsLocalized$() = locale::l("tags", \tags$())
        Next
      Next
    EndWith
    
    debugger::add("repository::loadRepositoryMods() - " + Str(ListSize(repo_mods(url$)\mods())) + " mods in repository")
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure thumbnailThread(*dummy)
    ; waits for new entries in queue and displays them to the registered image gadget
    debugger::add("repository::thumbnailThread()")
    
    Protected url$, file$
    Protected image
    Protected scale.d
    Static NewMap images()
    
    LockMutex(mutexStackDisplayThumb)
    If ListSize(stackDisplayThumbnail$()) <= 0
      ; no element waiting in stack
      UnlockMutex(mutexStackDisplayThumb)
      debugger::add("repository::thumbnailThread() - No element in stack")
      ProcedureReturn #False
    EndIf
    
    ; display (and if needed download) image from top of the stack (LiFo)
    LastElement(stackDisplayThumbnail$())
    url$ = stackDisplayThumbnail$()
    DeleteElement(stackDisplayThumbnail$())
    UnlockMutex(mutexStackDisplayThumb)
    
    file$ = getThumbFileName(url$)
    debugger::add("repository::thumbnailThread() - display image url={"+url$+"}, file={"+file$+"}")
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
      image = LoadImage(#PB_Any, file$)
      If image And IsImage(image)
        images(file$) = image
      Else ; could not load from disk
        image = #Null
        ; download image
        ;-TODO keep track of downloads!
        ; TODO it is possible, that two threads download the same image simultaneously -> maybe keep track of urls$ that are being downloaded at the moment
        CreateDirectory(GetPathPart(file$))
        ReceiveHTTPFile(url$, file$)
        If FileSize(file$) > 0
          image = LoadImage(#PB_Any, file$)
          If image And IsImage(image)
            images(file$) = image
          Else
            debugger::add("repository::thumbnailThread() - ERROR: could not load image {"+file$+"}")
          EndIf
        Else
          debugger::add("repository::thumbnailThread() - ERROR: download failed: {"+url$+"} -> {"+file$+"}")
        EndIf
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
  
  Procedure handleEventList()
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
          misc::openLink(*mod\url$)
        Case #PB_EventType_Change
          displayThumbnail(*mod\thumbnail$)
      EndSelect
    EndIf
  EndProcedure
  
  Procedure handleEventFilter()
    Protected n, type$, filter$
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
      filterMods(type$, filter$)
    EndIf
  EndProcedure
  
  
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
    
    ; TODO check when to load new file from server!
    ; currently: reload from server every time
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
      loadRepositoryMods(repo_main\mods\url$, repo_main\mods\enc$)
    EndIf
    
    
  EndProcedure
  
  Procedure loadRepositoryList()
    debugger::add("repository::loadRepositoryList()")
    Protected file, time
    
    time = ElapsedMilliseconds()
    
    ClearList(repositories$())
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
  
  Procedure registerWindow(window)
    _windowID = window
    If Not IsWindow(_windowID)
      _windowID = #False
    EndIf
    ProcedureReturn _windowID
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
          Case "views"
            \offset = OffsetOf(mod\views)
            \name$ = "Views"
            \type = #COL_INT
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
        debugger::add("repository::registerListGadget() - new column: {" + \name$ + "} of width {" + \width + "}")
      EndWith
    Next
    
    ; initialize new columns to gadget
    For col = 0 To ArraySize(_columns())
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
    type(0)\localized$ = locale::l("tags", "all")
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
  
  Procedure registerFilterGadget(gadget)
    debugger::add("repository::registerFilterGadget(" + gadget + ")")
    
    _filterGadgetID = gadget
    If Not IsGadget(_filterGadgetID)
      _filterGadgetID = #False
    EndIf
    
    BindGadgetEvent(_filterGadgetID, @handleEventFilter())
    
    ProcedureReturn _filterGadgetID
  EndProcedure
  
  Procedure filterMods(type$, search$)
    ; debugger::add("repository::filterMods("+search$+")")
    Protected text$, mod_ok, tmp_ok, count, item, k, col, str$, *base_address, *address
    
    If Not IsWindow(_windowID) Or Not IsGadget(_listGadgetID)
      debugger::add("repository::filterMods() - ERROR: window or gadget not valid")
      ProcedureReturn #False
    EndIf
    
    StopWindowUpdate(WindowID(_windowID))
    HideGadget(_listGadgetID, 0)
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
          
          
          If search$ = ""
            mod_ok = 1
            count = 1
          Else
            For k = 1 To count
              tmp_ok = 0
              str$ = Trim(StringField(search$, k, " "))
              If str$
                ; search in author, name, tags
                If FindString(\author$, str$, 1, #PB_String_NoCase)
                  tmp_ok = 1
                ElseIf FindString(\name$, str$, 1, #PB_String_NoCase)
                  tmp_ok = 1
                Else
                  ForEach \tags$()
                    If FindString(\tags$(), str$, 1, #PB_String_NoCase)
                      tmp_ok = 1
                    EndIf
                  Next
                  If Not tmp_ok ; only check further if not already found a hit
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
            text$ = ""
            ; generate text based on specified columns
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
            
            AddGadgetItem(_listGadgetID, item, text$)
            SetGadgetItemData(_listGadgetID, item, repo_mods()\mods())
            item + 1
          EndIf
        EndWith
      Next
    Next
    
    HideGadget(_listGadgetID, 0)
    ContinueWindowUpdate(WindowID(_windowID))
    
  EndProcedure
  
  Procedure displayThumbnail(url$)
    debugger::add("repository::displayThumbnail("+url$+")")
    
    LockMutex(mutexStackDisplayThumb)
    LastElement(stackDisplayThumbnail$())
    AddElement(stackDisplayThumbnail$())
    stackDisplayThumbnail$() = url$
    currentImageURL$ = url$
    UnlockMutex(mutexStackDisplayThumb)
    
    CreateThread(@thumbnailThread(), 0)
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
