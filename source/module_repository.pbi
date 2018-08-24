XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"

XIncludeFile "module_repository.h.pbi"

Module repository
  UseModule debugger
  
  ;{ VT
  
  DataSection
    vtMod:
    Data.i @modGetName()
    Data.i @modGetVersion()
    Data.i @modGetAuthor()
    Data.i @modGetFiles()
    Data.i @modIsInstalled()
    Data.i @modGetSource()
    Data.i @modCanDownload()
    Data.i @modDownload()
    Data.i @modGetLink()
    Data.i @modGetThumbnailUrl()
    Data.i @modGetThumbnailFile()
    Data.i @modGetThumbnailAsync()
    Data.i @modGetTimeChanged()
    Data.i @modGetWebsite()
    Data.i @modSetThumbnailImage()
    
    vtFile:
    Data.i @fileGetMod()
    Data.i @fileisInstalled()
    Data.i @fileCanDownload()
    Data.i @fileDownload()
    Data.i @fileGetLink()
    Data.i @fileGetFolderName()
  EndDataSection
  
  ;}
  
  ;{ Structures
  
  Structure file
    *vt.RepositoryFile
    *mod  ; link to "parent" mod
    
    fileid.q
    filename$         ; 
    url$              ; url to download this file
    timechanged.i     ; last time this file was changed
    foldername$       ; the name of the modfolder (after install)
  EndStructure
  
  Structure mod ; each mod in the list has these information
    *vt.RepositoryMod ; OOP interface table
    
    source$
    id.q
    name$
    author$
    authorid.i
    version$
    type$
    url$
    thumbnail$
    timecreated.i
    timechanged.i
    List files.file()
    List tags$()
    List tagsLocalized$()
    
    ; local stuff
    installSource$ ; used when installing after download
    thumbnailImage.i
  EndStructure
  
  Structure repo_info ; information about the mod repository
    name$
    source$
    description$
    maintainer$
    info_url$
    terms$
    changed.i
  EndStructure
  
  Structure modRepository ; the repository.json file
    repo_info.repo_info
    mod_base_url$
    file_base_url$
    thumbnail_base_url$
    List mods.mod()
  EndStructure
  
  
  Structure thumbnailAsync
    *mod.mod
    callback.CallbackThumbnail
    *userdata
  EndStructure
  
  Prototype callbackQueue(*userdata)
  Structure queue
    callback.callbackQueue
    *userdata
  EndStructure
  ;}
  
  ;{ Globals
  
  Global NewMap ModRepositories.modRepository() ; allow multiple repositories -> use map, with repository URL as key
  Global NewMap *filesByFoldername.mod()        ; pointer to original mods in ModRepositories\mods() with foldername as key
  Global mutexMods = CreateMutex(),
         mutexFilesMap = CreateMutex()
         
  Global CallbackAddMods.CallbackAddMods
  Global CallbackClearList.CallbackClearList
  Global CallbackRefreshFinished.CallbackRefreshFinished
  
  Global CallbackEventClearList
  
  Global *queueThread, queueStop.b,
         mutexQueue = CreateMutex()
  Global NewList queue.queue()
  
  ;}
  
  ;{ init
  #RepoDirectory$ = "repositories"
  #RepoCache$     = #RepoDirectory$ + "/cache"
  #RepoListFile$  = #RepoDirectory$ + "/repositories.txt"
  #RepoDownloadTimeout = 1000 ; timeout for downloads in milliseconds
    
  Procedure init()
    CreateDirectory(#RepoDirectory$)
    CreateDirectory(#RepoCache$)
    
    If FileSize(#RepoListFile$) <= 0
      Define file
      file = CreateFile(#PB_Any, #RepoListFile$)
      If file
        CloseFile(file)
      EndIf
    EndIf
    
    InitNetwork()
    UseMD5Fingerprint()
    UsePNGImageDecoder()
    UseJPEGImageDecoder()
    UseJPEGImageEncoder()
  EndProcedure
  
  init()
  ;}
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------- PRIVATE FUNCTIONS -----------------------------
  ;----------------------------------------------------------------------------
  
  Procedure WriteSourcesFile(List sources$())
    Protected file
    file = CreateFile(#PB_Any, #RepoListFile$)
    If file
      ForEach sources$()
        WriteStringN(file, sources$(), #PB_UTF8)
      Next
      CloseFile(file)
    Else
      deb("repository:: could not access file "+#RepoListFile$)
    EndIf
    ProcedureReturn Bool(file)
  EndProcedure
  
  Procedure.s getRepoFileName(url$)
    ProcedureReturn #RepoDirectory$ + "/" + Fingerprint(@url$, StringByteLength(url$), #PB_Cipher_MD5) + ".json"
  EndProcedure
  
  Procedure.s getThumbFileName(url$)
    Protected name$
    If url$
      name$ = Fingerprint(@url$, StringByteLength(url$), #PB_Cipher_MD5)
      ProcedureReturn #RepoCache$ + "/" + Left(name$, 2) + "/" + name$ + ".jpg"
    Else
      ProcedureReturn ""
    EndIf
  EndProcedure
  
  Procedure downloadToMemory(url$, timeout=#RepoDownloadTimeout)
    ; TODO timeout custom function with timeout causes IMA on Win7...
    ; workaround use default download function
    ProcedureReturn ReceiveHTTPMemory(url$, 0, main::VERSION_FULL$)
    
    Protected con, progress,
              lastBytes, time,
              *buffer
    
    con = ReceiveHTTPMemory(url$, #PB_HTTP_Asynchronous, main::VERSION_FULL$)
    If con
      time = ElapsedMilliseconds()
      Repeat
        progress = HTTPProgress(con)
        If progress < 0 ; #PB_Http_Success Or #PB_Http_Failed Or #PB_Http_Aborted
          *buffer = FinishHTTP(con)
          Break
        EndIf
        
        If progress = lastBytes
          If ElapsedMilliseconds() - time > #RepoDownloadTimeout
            deb("repository:: timeout "+url$)
            AbortHTTP(con)
          EndIf
        Else
          lastBytes = progress
          time = ElapsedMilliseconds()
        EndIf
        
        Delay(50)
      ForEver
    Else
      deb("repository:: error "+url$)
    EndIf
    
    If progress = #PB_Http_Success
      ProcedureReturn *buffer
    Else
      ProcedureReturn #Null
    EndIf
  EndProcedure
  
  Procedure saveMemoryToFile(*buffer, file$)
    Protected file
    file = CreateFile(#PB_Any, file$)
    If file
      WriteData(file, *buffer, MemorySize(*buffer))
      CloseFile(file)
      ProcedureReturn MemorySize(*buffer)
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure openRepositoryFile(url$)
    Protected file$, *buffer,
              json, *value,
              *modRepository.modRepository,
              NewList *mods.RepositoryMod()
    
    file$ = getRepoFileName(url$)
    
    ; download
    *buffer = downloadToMemory(url$)
    If *buffer
      saveMemoryToFile(*buffer, file$)
      FreeMemory(*buffer)
    Else
      deb("repository:: download failed: "+url$)
    EndIf
    
    ; check file
    If FileSize(file$) <= 0
      deb("repository:: "+file$+" for url "+url$+" does not exist or is empty")
      ProcedureReturn #False
    EndIf
    
    ; read JSON
    json = LoadJSON(#PB_Any, file$)
    If Not json
      deb("repository:: could not parse JSON from "+url$)
      DeleteFile(file$)
      ProcedureReturn #False
    EndIf
    
    ; check JSON
    *value = JSONValue(json)
    If JSONType(*value) <> #PB_JSON_Object 
      deb("repository:: invalid JSON type in "+url$)
      FreeJSON(json)
      ProcedureReturn #False
    EndIf
    
    LockMutex(mutexMods)
    
    ; check if repo already loaded
    *modRepository = FindMapElement(ModRepositories(), url$)
    If *modRepository
      deb("repository:: "+url$+" already loaded")
      FreeJSON(json)
      UnlockMutex(mutexMods)
      ProcedureReturn #False
    EndIf
    
    ; load repository
    *modRepository = AddMapElement(ModRepositories(), url$)
    ExtractJSONStructure(*value, *modRepository, ModRepository)
    
    
    ; process
    If *modRepository\repo_info\source$
      ; TODO check if source name is already used, cannot have two sources with same name
    Else
      deb("repository:: "+url$+" has no source information")
    EndIf
    
    
    ForEach *modRepository\mods()
      With *modRepository\mods()
        ; mod vt
        \vt = ?vtMod
        ; source
        \source$ = *modRepository\repo_info\source$
        ; mod url
        If \url$ And *modRepository\mod_base_url$
          \url$ = *modRepository\mod_base_url$ + \url$
        EndIf
        ; thumbnail
        If \thumbnail$ And *modRepository\thumbnail_base_url$
          \thumbnail$ = *modRepository\thumbnail_base_url$ + \thumbnail$
        EndIf
        ; files
        ForEach \files()
          \files()\vt = ?vtFile
          \files()\mod = *modRepository\mods() ; store "parent" mod for file
          If \files()\url$ And *modRepository\file_base_url$
            \files()\url$ = *modRepository\file_base_url$ + \files()\url$
          EndIf
        Next
        ; tags
        ClearList(\tagsLocalized$())
        ForEach \tags$()
          AddElement(\tagsLocalized$())
          \tagsLocalized$() = locale::l("tags", \tags$())
        Next
      EndWith
    Next
   
    ; populate pointer map
    LockMutex(mutexFilesMap)
    ForEach *modRepository\mods()
      ForEach *modRepository\mods()\files()
        If Not FindMapElement(*filesByFoldername(), *modRepository\mods()\files()\foldername$)
          *filesByFoldername(*modRepository\mods()\files()\foldername$) = *modRepository\mods()\files()
        EndIf
      Next
    Next
    UnlockMutex(mutexFilesMap)
    
    Debug "#GUI UPDATE"
    ; GUI update
    If ListSize(*modRepository\mods()) > 0 And CallbackAddMods
;       ReDim *mods(ListSize(*modRepository\mods()) - 1)
      ClearList(*mods())
      ForEach *modRepository\mods()
        AddElement(*mods())
        *mods() = *modRepository\mods()
      Next
      CallbackAddMods(*mods())
      ClearList(*mods())
    EndIf
    
    UnlockMutex(mutexMods)
    
    ; finished
    ProcedureReturn #True
  EndProcedure
  
  ; QUEUE
  
  Procedure queueRefreshRepositories(*dummy)
    ; download repositories
    
    Protected NewList repositories$()
    GetRepositories(repositories$())
    
    ForEach repositories$()
      openRepositoryFile(repositories$())
    Next
    
    If CallbackRefreshFinished
      CallbackRefreshFinished()
    EndIf
  EndProcedure
  
  Procedure queueThumbnail(*thumbnailData.thumbnailAsync)
    Protected url$, file$
    Protected image, *buffer
    ; TODO this function can be optimized!
    
    ; download for same image may be triggered multiple times!
    ; make sure, same image is not downloaded in parallel
    
    If *thumbnailData\mod\thumbnailImage
      *thumbnailData\callback(*thumbnailData\mod\thumbnailImage, *thumbnailData\userdata)
    Else
      url$ = *thumbnailData\mod\thumbnail$
      
      ; check if image on disk
      file$ = getThumbFileName(url$)
      
      If FileSize(file$) <= 0
        ; download image
        deb("Download Thumbnail "+*thumbnailData\mod\thumbnail$)
        CreateDirectory(GetPathPart(file$))
        *buffer = downloadToMemory(url$)
        If *buffer
          If MemorySize(*buffer) > 1024 ; often rx 92 bytes when proxy error occurs
            image = CatchImage(#PB_Any, *buffer, MemorySize(*buffer))
            If image
              image = misc::ResizeCenterImage(image, 160, 90)
              SaveImage(image, file$, #PB_ImagePlugin_JPEG, 7, 24)
              FreeImage(image)
            EndIf
          EndIf
          FreeMemory(*buffer)
        EndIf
      EndIf
        
      If FileSize(file$) > 0
        ; file exists, load image
        image = LoadImage(#PB_Any, file$)
        If image And IsImage(image)
          ; cache image
          *thumbnailData\mod\thumbnailImage = image
        Else
          ; local file could not be loaded?
          DeleteFile(file$)
          deb("repository:: could not open local thumbnail from "+url$)
        EndIf
      EndIf
      
      If image
        *thumbnailData\callback(image, *thumbnailData\userdata)
      EndIf
    EndIf
    
    FreeStructure(*thumbnailData)
  EndProcedure
  
  Procedure QueueThread(*dummy)
    Protected callback.callbackQueue
    Protected *userdata
    Repeat
      
      LockMutex(mutexQueue)
      If ListSize(queue()) = 0
        UnlockMutex(mutexQueue)
        Delay(100)
        Continue
      EndIf
      
      ; get top item from queue
      FirstElement(queue())
      callback = queue()\callback
      *userdata = queue()\userdata
      DeleteElement(queue(), 1)
      UnlockMutex(mutexQueue)
      
      ; execute the task
      Debug "repo queue: start next task"
      callback(*userdata)
      
      ; not hog CPU
      Delay(10)
      
    Until queueStop
  EndProcedure
  
  Procedure addToQueue(callback.callbackQueue, *userdata)
    LockMutex(mutexQueue)
    LastElement(queue())
    AddElement(queue())
    queue()\callback = callback
    queue()\userdata = *userdata
    UnlockMutex(mutexQueue)
    
    If Not *queueThread Or Not IsThread(*queueThread)
      *queueThread = CreateThread(@QueueThread(), 0)
    EndIf
  EndProcedure
  
  Procedure stopQueue(timeout = 500)
    Protected time
    If *queueThread And IsThread(*queueThread)
      queueStop = #True
      time = ElapsedMilliseconds()
      While IsThread(*queueThread)
        If ElapsedMilliseconds() - time > timeout
          KillThread(*queueThread)
          Break
        EndIf
      Wend
      queueStop = #False
    EndIf
    *queueThread = #Null
  EndProcedure
  
  
  
  ;----------------------------------------------------------------------------
  ;----------------------------- PUBLIC FUNCTION ------------------------------
  ;----------------------------------------------------------------------------
  
  
  Procedure refreshRepositories(async=#True)
    freeAll()
    
    ; always add official repositories to sources
    AddRepository("https://www.transportfevermods.com/repository/mods/tpfnet.json")
    AddRepository("https://www.transportfevermods.com/repository/mods/workshop.json")
    
    If async
      addToQueue(@queueRefreshRepositories(), #Null)
    Else
      queueRefreshRepositories(0)
    EndIf
  EndProcedure
  
  Procedure freeAll()
    deb("repository:: free all")
    
    Debug "stop queue"
    stopQueue()
    
    Debug "lock mutex"
    LockMutex(mutexMods)
    LockMutex(mutexFilesMap)
    
    Debug "call callback"
    If CallbackClearList
      CallbackClearList()
    EndIf
    If CallbackEventClearList
      PostEvent(CallbackEventClearList)
    EndIf
    
    Debug "clear map"
    ClearMap(ModRepositories())
    ClearMap(*filesByFoldername())
    
    Debug "unlock"
    UnlockMutex(mutexFilesMap)
    UnlockMutex(mutexMods)
    
    Debug "fin"
  EndProcedure
  
  Procedure clearCache()
    Protected dir$
    
    DeleteDirectory(#RepoCache$, "", #PB_FileSystem_Recursive)
    CreateDirectory(#RepoCache$)
    
    ProcedureReturn #True
  EndProcedure
  
  ; source handling
  
  Procedure AddRepository(url$)
    Protected inlist.b
    Protected NewList sources$()
    Debug "add repository "+url$
    
    url$ = Trim(url$)
    GetRepositories(sources$())
    
    ForEach sources$()
      If url$ = sources$()
        ; source already in list
        inList = #True
        Break
      EndIf
    Next
    
    If inlist
      Debug "repo already in list"
    Else
      LastElement(sources$())
      AddElement(sources$())
      sources$() = url$
      WriteSourcesFile(sources$())
    EndIf
  EndProcedure
  
  Procedure CanRemoveRepository(url$)
    url$ = Trim(url$)
    
    If url$ = "https://www.transportfevermods.com/repository/mods/tpfnet.json" Or 
       url$ = "https://www.transportfevermods.com/repository/mods/workshop.json"
      ProcedureReturn #False
    Else
      ProcedureReturn #True
    EndIf
  EndProcedure
  
  Procedure RemoveRepository(url$)
    Protected deleted.b
    Protected NewList sources$()
    
    GetRepositories(sources$())
    
    ForEach sources$()
      If url$ = sources$()
        If CanRemoveRepository(url$)
          DeleteElement(sources$())
          deleted = #True
          Break
        EndIf
      EndIf
    Next
    
    If deleted
      WriteSourcesFile(sources$())
    EndIf
  EndProcedure
  
  Procedure GetRepositories(List sources$())
    Protected file, url$
    ClearList(sources$())
    file = OpenFile(#PB_Any, #RepoListFile$)
    If file
      While Not Eof(file)
        url$ = Trim(ReadString(file, #PB_UTF8))
        If url$
          AddElement(sources$())
          sources$() = url$
        EndIf
      Wend
      CloseFile(file)
    Else
      deb("repository:: could not read repository file "+#RepoListFile$)
    EndIf
    
    If ListSize(sources$()) > 0
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure GetRepositoryModCount(url$)
    Protected count, *ModRepository.ModRepository
;     LockMutex(mutexMods)
    *ModRepository = FindMapElement(ModRepositories(), url$)
    If *ModRepository
      count = ListSize(*ModRepository\mods())
    Else
      count = -1 ; not loaded
    EndIf
;     UnlockMutex(mutexMods)
    ProcedureReturn count
  EndProcedure
  
  ; get mod object
  
  Procedure getModByFoldername(foldername$)
    Protected *mod.mod, *file.file
    
    *file = getFileByFoldername(foldername$)
    *mod = fileGetMod(*file)
    
    ProcedureReturn *mod
  EndProcedure
  
  Procedure getModByLink(link$)
    ; TODO getModByLink()
    ProcedureReturn 0
  EndProcedure
  
  Procedure getFileByFoldername(foldername$)
    Protected *file, regExpFolder, version
    Static regexp
    If Not regexp
      regexp = CreateRegularExpression(#PB_Any, "_[0-9]+$")
    EndIf
    
    LockMutex(mutexFilesMap)
    ; check if "foldername" is version independend, e.g. "urbangames_vehicles_no_end_year" (no _1 at the end)
    If Not MatchRegularExpression(regexp, foldername$)
      Debug "search version for foldername "+#DQUOTE$+foldername$+#DQUOTE$+" version independend"
      ; try to find a file matching the foldername without the version
      regExpFolder = CreateRegularExpression(#PB_Any, "^"+foldername$+"_([0-9]+)$")
      If regExpFolder
        version = -1
        ForEach *filesByFoldername()
          If MatchRegularExpression(regExpFolder, MapKey(*filesByFoldername()))
            ; found a match, keep on searching for a higher version number (e.g.: if version _1 and _2 are found, use _2)
            ; try to extract version number
            If ExamineRegularExpression(regExpFolder, MapKey(*filesByFoldername()))
              If NextRegularExpressionMatch(regExpFolder)
                If Val(RegularExpressionGroup(regExpFolder, 1)) > version
                  ; if version is higher, save version and file link
                  version = Val(RegularExpressionGroup(regExpFolder, 1))
                  *file = *filesByFoldername()
                EndIf
              EndIf
            EndIf
          EndIf
        Next
        FreeRegularExpression(regExpFolder)
      Else
        deb("repository:: could not create regexp "+#DQUOTE$+"^"+foldername$+"_([0-9]+)$"+#DQUOTE$)
        Debug RegularExpressionError()
      EndIf
    Else
      ;notice attention: folderByFoldername only has "last" source, if multiple sources have mod with same foldername
      If FindMapElement(*filesByFoldername(), foldername$)
        *file = *filesByFoldername()
      EndIf
    EndIf
    UnlockMutex(mutexFilesMap)
    
    ProcedureReturn *file
  EndProcedure
  
  Procedure getFileByLink(link$)
    ; TODO getFileByLink()
  EndProcedure
  
  ; work on mod object
  
  Procedure.s modGetName(*mod.mod)
    If *mod
      ProcedureReturn *mod\name$
    EndIf
  EndProcedure
  
  Procedure.s modGetVersion(*mod.mod)
    If *mod
      ProcedureReturn *mod\version$
    EndIf
  EndProcedure
  
  Procedure.s modGetAuthor(*mod.mod)
    If *mod
      ProcedureReturn *mod\author$
    EndIf
  EndProcedure
  
  Procedure modGetFiles(*mod.mod, List *files.RepositoryFile())
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    If ListSize(*mod\files()) > 0
;       ReDim *files(ListSize(*mod\files()) -1)
;       ForEach *mod\files()
;         *files(ListIndex(*mod\files())) = *mod\files()
;       Next
      ClearList(*files())
      ForEach *mod\files()
        AddElement(*files())
        *files() = *mod\files()
      Next
    EndIf
    
    ProcedureReturn ListSize(*mod\files())
  EndProcedure
  
  Procedure modIsInstalled(*mod.mod)
    ; TODO modIsInstalled()
    ; idea: for all files in mod, check if installed -> c.f. fileIsInstalled
  EndProcedure
  
  Procedure.s modGetSource(*mod.mod)
    ProcedureReturn *mod\source$
  EndProcedure
  
  Procedure modCanDownload(*mod.mod)
    Protected nFiles
    ForEach *mod\files()
      If fileCanDownload(*mod\files())
        nFiles + 1
      EndIf
    Next
    ProcedureReturn nFiles
  EndProcedure
  
  Procedure modDownload(*mod)
    ; TODO modDownload()
  EndProcedure
  
  Procedure.s modGetLink(*mod)
    ; TODO modGetLink()
  EndProcedure
  
  Procedure.s modGetThumbnailUrl(*mod.mod)
    If *mod
      ProcedureReturn *mod\thumbnail$
    EndIf
  EndProcedure
  
  Procedure.s modGetThumbnailFile(*mod.mod)
    Protected url$
    url$ = modGetThumbnailUrl(*mod)
    If url$
      ProcedureReturn getThumbFileName(url$)
    EndIf
  EndProcedure
  
  Procedure modGetThumbnailAsync(*mod.mod, callback.CallbackThumbnail, *userdata=#Null)
    Protected *thumbnailData.thumbnailAsync
    Protected url$, file$, image
    
    If *mod
      ; image not yet available -> send to queue for image download
      *thumbnailData = AllocateStructure(thumbnailAsync)
      *thumbnailData\mod = *mod
      *thumbnailData\callback = callback
      *thumbnailData\userdata = *userdata
      
      addToQueue(@queueThumbnail(), *thumbnailData)
    EndIf
    ProcedureReturn #True
  EndProcedure
  
  Procedure modGetTimeChanged(*mod.mod)
    If *mod
      ProcedureReturn *mod\timechanged
    EndIf
  EndProcedure
  
  Procedure.s modGetWebsite(*mod.mod)
    If *mod
      ProcedureReturn *mod\url$
    EndIf
  EndProcedure
  
  Procedure modSetThumbnailImage(*mod.mod, image)
    If *mod
      *mod\thumbnailImage = image
    EndIf
  EndProcedure
  
  ; work on file object
  
  Procedure fileGetMod(*file.file)
    If *file
      ProcedureReturn *file\mod
    EndIf
  EndProcedure
  
  Procedure fileCanDownload(*file.file)
    If *file And *file\url$
      ProcedureReturn #True
    EndIf
  EndProcedure
  
  Procedure fileDownload(*file.file)
    ; TODO fileDownload()
  EndProcedure
  
  Procedure.s fileGetLink(*file.file)
    ; TODO fileGetLink()
  EndProcedure
  
  Procedure.s fileGetFolderName(*file.file)
    ProcedureReturn *file\foldername$
  EndProcedure
  
  Procedure fileIsInstalled(*file.file)
    ; TODO fileIsInstalled()
    ; idea: use mods module to check for foldername
    ; if file has not foldername, check for ID? (optional)
  EndProcedure
  
  ; Callbacks to GUI
  
  Procedure BindEventCallback(Event, *callback)
    ; function callbacks - will be called in sync as function
    Select event
      Case #CallbackAddMods
        CallbackAddMods = *callback
      Case #CallbackClearList
        CallbackClearList = *callback
      Case #CallbackRefreshFinished
        CallbackRefreshFinished = *callback
    EndSelect
  EndProcedure
  
  Procedure BindEventPost(Event, Post)
    ; event based callbacks, will trigger an event that must be handled by the event loop
    Select event
      Case #CallbackClearList
        CallbackEventClearList = Post
    EndSelect
    
  EndProcedure
  
EndModule
