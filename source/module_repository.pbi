XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_settings.pbi"
XIncludeFile "wget.pb"

XIncludeFile "module_repository.h.pbi"


;TODO use winapi for downloads? https://msdn.microsoft.com/en-us/ie/ms775123(v=vs.94)

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
    Data.i @fileGetFilename()
  EndDataSection
  
  ;}
  
  ;{ Structures
  
  Structure download ; download information
    *file.file
    *mod.mod
    url$
    file$
    size.i
    con.i
    timeout.l
  EndStructure
  
  ; file and mod structures
  
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
  
  ; repository structures
  
  Structure repo_info ; information about the mod repository
    name$
    source$
    icon$
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
         mutexFilesMap = CreateMutex(),
         _mutexDownload = CreateMutex()
         
  Global CallbackAddMods.CallbackAddMods
  Global CallbackClearList.CallbackClearList
  Global CallbackRefreshFinished.CallbackRefreshFinished
  
  Global Dim events(EventArraySize)
  
  Global *queueThread, queueStop.b,
         mutexQueue = CreateMutex()
  Global NewList queue.queue()
  
  Global _loaded.b
  Global _activeRepoDownloads.i
  ;}
  
  ;{ init
  #RepoDirectory$ = "repositories"
  #RepoCache$     = #RepoDirectory$ + "/cache"
  #RepoListFile$  = #RepoDirectory$ + "/repositories.txt"
  #RepoDownloadTimeout = 2000 ; timeout for downloads in milliseconds
    
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
  
  Procedure postProgressEvent(percent, text$=Chr(1))
    Protected *buffer
    If events(#EventProgress)
      If text$ = Chr(1)
        *buffer = #Null
      Else
        *buffer = AllocateMemory(StringByteLength(text$+" "))
;         Debug "########## poke "+text$+" @ "+*buffer
        PokeS(*buffer, text$)
      EndIf
      PostEvent(events(#EventProgress), 0, 0, percent, *buffer)
    EndIf
  EndProcedure
  
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
  
  Procedure downloadToMemory_deprecated(url$, timeout=#RepoDownloadTimeout)
    ; some bug in HTTP_Async causes IMA... do not use async (no timeout available...)
    ProcedureReturn ReceiveHTTPMemory(url$, 0, main::VERSION_FULL$)
    
    Protected con, time, lastBytes, progress, *buffer
    con = ReceiveHTTPMemory(url$, #PB_HTTP_Asynchronous, main::VERSION_FULL$)
    
    If con
      time = ElapsedMilliseconds()
      Repeat
        progress = HTTPProgress(con)
        
        If progress = lastBytes
          If ElapsedMilliseconds() - time > timeout
            Debug "download timed out"
            AbortHTTP(con)
          EndIf
        Else
          lastBytes = progress
          time = ElapsedMilliseconds()
        EndIf
        
        If progress < 0
          *buffer = FinishHTTP(con)
          Break
        EndIf
        
      Until progress < 0
    EndIf
    
    If progress = #PB_Http_Success
      ProcedureReturn *buffer
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
  
  Procedure updateRepositoryFileSuccess(*wget.wget::wget)
    Protected file$
    file$ = *wget\getFilename() ; should end with .download
    file$ = Left(file$, Len(file$)-9)
    DeleteFile(file$, #PB_FileSystem_Force)
    RenameFile(file$+".download", file$)
    deb("repository:: repository update successful: "+*wget\getRemote())
    *wget\free()
    _activeRepoDownloads - 1
  EndProcedure
  
  Procedure updateRepositoryFileError(*wget.wget::wget)
    Protected file$
    file$ = *wget\getFilename() ; should end with .download
    file$ = Left(file$, Len(file$)-9)
    
    DeleteFile(file$+".download", #PB_FileSystem_Force)
    deb("repository:: repository update failed: "+*wget\getRemote())
    *wget\free()
    _activeRepoDownloads - 1
  EndProcedure
  
  Procedure updateRepositoryFile(url$)
    Protected file$, ret,
              *wget.wget::wget
    
    file$ = getRepoFileName(url$)
    
    If Not settings::getInteger("repository", "use_cache")
      DeleteFile(file$, #PB_FileSystem_Force)
    EndIf
    
    ; start download
    _activeRepoDownloads + 1
    *wget = wget::NewDownload(url$, file$+".download", #RepoDownloadTimeout/1000, #True)
    *wget\setUserAgent(main::VERSION_FULL$)
    *wget\CallbackOnError(@updateRepositoryFileError())
    *wget\CallbackOnSuccess(@updateRepositoryFileSuccess())
    *wget\download()
  EndProcedure
  
  Procedure openRepositoryFile(url$)
    Protected file$,
              json, *value,
              *modRepository.modRepository,
              NewList *mods.RepositoryMod()
    
    file$ = getRepoFileName(url$)
    
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
    If *modRepository\repo_info\icon$
      ; use a custom icon for mods from this repo
      ; TODO download and store repo icon
    EndIf
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
  
  ; QUEUE (worker)
  
  Procedure queueRefreshRepositories(*dummy)
    ; download repositories
    Protected N, i, loaded
    Protected percent.b
    Protected NewList repositories$()
    _loaded = 0
    
    N = GetRepositories(repositories$())
    
    postProgressEvent(0, locale::l("repository", "load"))
    
    ; download all repositories
    _activeRepoDownloads = 0
    loaded = 0
    ForEach repositories$()
      updateRepositoryFile(repositories$())
    Next
    While _activeRepoDownloads > 0
      ; keep track of how many downloads are already finished
      If N - _activeRepoDownloads <> loaded
        loaded = N - _activeRepoDownloads
        percent = 100*loaded/N
        postProgressEvent(percent / 2)
      EndIf
      Delay(100)
    Wend
    
    ; open local repository files
    loaded = 0
    ForEach repositories$()
      loaded + openRepositoryFile(repositories$())
      i + 1
      percent = 100*i/N
      postProgressEvent(50 + percent/2)
    Next
    
    If loaded > 0
      postProgressEvent(-1, locale::l("repository", "loaded"))
    Else
      postProgressEvent(-1, locale::l("repository", "load_failed"))
    EndIf
    If CallbackRefreshFinished
      CallbackRefreshFinished()
    EndIf
    If events(#EventRefreshFinished)
      PostEvent(events(#EventRefreshFinished))
    EndIf
    
    _loaded = #True
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
        *buffer = downloadToMemory_deprecated(url$)
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
      
      ; there is something to do
      If events(#EventWorkerStarts)
        PostEvent(events(#EventWorkerStarts))
      EndIf
      
      ; get top item from queue
      FirstElement(queue())
      callback = queue()\callback
      *userdata = queue()\userdata
      DeleteElement(queue(), 1)
      UnlockMutex(mutexQueue)
      
      ; execute the task
      callback(*userdata)
      
      ; finished
      If events(#EventWorkerStops)
        PostEvent(events(#EventWorkerStops))
      EndIf
      
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
  
  Procedure stopQueue(timeout = 5000)
    Protected time
    If *queueThread And IsThread(*queueThread)
      queueStop = #True
      time = ElapsedMilliseconds()
      
      WaitThread(*queueThread, timeout)
      
      If IsThread(*queueThread)
        deb("repository:: kill worker")
        KillThread(*queueThread)
        ; WARNING: killing will potentially leave mutexes and other resources locked/allocated
      EndIf
        
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
    
    ;TODO if download is still active, and program is closed, download thread might try to access ressources that have been freed by END of program
    ; must also stop all download threads.
    ; idea: use wget:: static method to keep track of all running downloads centrally in the wget module directly
    
    stopQueue()
    
    LockMutex(mutexMods)
    LockMutex(mutexFilesMap)
    
    If CallbackClearList
      CallbackClearList()
    EndIf
    If events(#EventClearMods)
      PostEvent(events(#EventClearMods))
    EndIf
    
    ClearMap(ModRepositories())
    ClearMap(*filesByFoldername())
    
    UnlockMutex(mutexFilesMap)
    UnlockMutex(mutexMods)
  EndProcedure
  
  Procedure clearCache()
    Protected dir$
    
    DeleteDirectory(#RepoCache$, "", #PB_FileSystem_Recursive)
    CreateDirectory(#RepoCache$)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure.b isLoaded()
    ProcedureReturn _loaded
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
    
    ProcedureReturn ListSize(sources$())
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
  
  Procedure CheckRepository(url$)
    Protected file$
    Protected *wget.wget::wget
    Protected json, *value, *modRepository.modRepository
    Protected ret
    deb("repository:: CheckRepository("+url$+")")
    
    ; try to download repository
    file$ = GetTemporaryDirectory()+"tpfmm-repository.tmp"
    DeleteFile(file$, #PB_FileSystem_Force)
    *wget = wget::NewDownload(url$, file$, #RepoDownloadTimeout/1000, #False)
    *wget\setUserAgent(main::VERSION_FULL$)
    If *wget\download() = 0 ; exit code 0
      ; download okay
      json = LoadJSON(#PB_Any, file$)
      If json
        ; check JSON
        *value = JSONValue(json)
        If JSONType(*value) = #PB_JSON_Object 
          ; check if repo already loaded
          LockMutex(mutexMods)
          *modRepository = FindMapElement(ModRepositories(), url$)
          UnlockMutex(mutexMods)
          If Not *modRepository
            *modRepository = AllocateStructure(modRepository)
            ExtractJSONStructure(*value, *modRepository, modRepository)
            ; TODO check if duplicate "source" id
            deb("repository:: "+*modRepository\repo_info\name$+" by "+*modRepository\repo_info\maintainer$)
            ret = #True
          Else
            deb("repository:: "+url$+" already loaded")
            FreeJSON(json)
            ret = #False
          EndIf
        Else
          deb("repository:: invalid JSON type in "+url$)
          ret = #False
        EndIf
        FreeJSON(json)
      Else
        deb("repository:: could not parse JSON from "+url$)
        ret = #False
      EndIf
      DeleteFile(file$, #PB_FileSystem_Force)
    Else
      deb("repository:: download failed "+url$)
      ret = #False
    EndIf
    
    ProcedureReturn ret
  EndProcedure
  
  ; get mod object
  
  Procedure getModByFoldername(foldername$)
    Protected *mod.mod, *file.file
    
    *file = getFileByFoldername(foldername$)
    *mod = fileGetMod(*file)
    
    ProcedureReturn *mod
  EndProcedure
  
  Procedure getModByLink(link$)
    Protected source$, id.q
    Protected *mod
    
    source$ =     StringField(link$, 1, "/")
    id      = Val(StringField(link$, 2, "/"))
    
    ForEach ModRepositories()
      If ModRepositories()\repo_info\source$ = source$
        ForEach ModRepositories()\mods()
          If ModRepositories()\mods()\id = id
            *mod = ModRepositories()\mods()
            Break
          EndIf
        Next
        Break
      EndIf
    Next
    
    ProcedureReturn *mod
  EndProcedure
  
  Procedure getFileByFoldername(foldername$)
    Protected *file, regExpFolder, version
    Static regexp
    If Not regexp
      regexp = CreateRegularExpression(#PB_Any, "_[0-9]+$")
    EndIf
    
    If Left(foldername$, 1) = "?"
      deb("staging area mod")
      ShowCallstack()
      CallDebugger
    ElseIf Left(foldername$, 1) = "*"
      deb("workshop mod")
      ShowCallstack()
      CallDebugger
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
    Protected source$, id.q, fileID.q
    Protected *file
    
    source$ =     StringField(link$, 1, "/")
    id      = Val(StringField(link$, 2, "/"))
    fileID  = Val(StringField(link$, 3, "/"))
    
    ForEach ModRepositories()
      If ModRepositories()\repo_info\source$ = source$
        ForEach ModRepositories()\mods()
          If ModRepositories()\mods()\id = id
            ForEach ModRepositories()\mods()\files()
              If ModRepositories()\mods()\files()\fileid = fileID
                *file = ModRepositories()\mods()\files()
                Break
              EndIf
            Next
            Break
          EndIf
        Next
        Break
      EndIf
    Next
    
    ProcedureReturn *file
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
  
  Procedure modDownload(*mod.mod)
    Protected NewList *files.RepositoryFile()
    Protected nFiles
    
    nFiles = modGetFiles(*mod, *files())
    If nFiles = 1
      ; single file -> download
      FirstElement(*files())
      ProcedureReturn *files()\download()
    ElseIf nFiles > 1
      ; multiple files -> open file selection window
      If events(#EventShowModFileSelection)
        PostEvent(events(#EventShowModFileSelection), *mod, 0)
        ProcedureReturn #True
      Else
        ; no event callback defined...
        ProcedureReturn #False
      EndIf
    Else
      ; no files found
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure.s modGetLink(*mod.mod)
    ProcedureReturn *mod\source$+"/"+*mod\id
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
  
  Procedure fileDownloadMonitor(*download.download)
    ; monitor the download and send event on success/failure
    Protected progress, lastBytes, bytes, finish, time
    
    time = ElapsedMilliseconds()
    
    Repeat
      progress = HTTPProgress(*download\con)
      
      If lastBytes = progress
        ; download stuck? no new bytes received
        If ElapsedMilliseconds() - time > *download\timeout
          deb("repository:: download timeout after "+Str(*download\timeout/1000)+" s")
          AbortHTTP(*download\con)
        EndIf
      Else
        ; download is active, new bytes received
        lastBytes = progress
      EndIf
      
      If progress < 0
        bytes = FinishHTTP(*download\con)
        finish = #True
        Select progress
          Case #PB_Http_Success
            deb("repository:: download success "+*download\url$)
          Case #PB_Http_Failed
            deb("repository:: download failed "+*download\url$)
          Case #PB_Http_Aborted
            deb("repository:: download aborted "+*download\url$)
        EndSelect
      Else
        If *download\size
          postProgressEvent(100 * progress / *download\size)
        EndIf
      EndIf
      
      Delay(100)
    Until finish
    
    ProcedureReturn bytes
    
  EndProcedure
  
  Procedure fileDownloadProgress(*wget.wget::wget)
    postProgressEvent(*wget\getProgress())
  EndProcedure
  
  Procedure fileDownloadError(*wget.wget::wget)
    Protected *file.file, *mod.mod
    Protected url$
    Protected NewMap strings$()
    
    deb("repository:: fileDownloadError()")
    
    *file = *wget\getUserData()
    *mod = *file\mod
    url$ = *wget\getRemote()
    *wget\free()
    *wget = #Null
    
    strings$("modname") = *mod\name$
    
    deb("repository:: download error: "+url$)
    
    postProgressEvent(-1, locale::getEx("repository", "download_fail", strings$()))
    
    UnlockMutex(_mutexDownload)
    If events(#EventWorkerStops)
      PostEvent(events(#EventWorkerStops))
    EndIf
  EndProcedure
  
  Procedure fileDownloadSuccess(*wget.wget::wget)
    Protected *file.file, *mod.mod
    Protected filename$
    Protected NewMap strings$()
    
    deb("repository:: fileDownloadSuccess()")
    
    *file = *wget\getUserData()
    *mod = *file\mod
    filename$ = *wget\getFilename()
    *wget\free()
    *wget = #Null
    
    strings$("modname") = *mod\name$
    
    postProgressEvent(-1, locale::getEx("repository", "download_finish", strings$()))
    
    If events(#EventDownloadSuccess)
      PostEvent(events(#EventDownloadSuccess), *file, 0)
    EndIf
    
    mods::install(filename$)
    
    UnlockMutex(_mutexDownload)
    If events(#EventWorkerStops)
      PostEvent(events(#EventWorkerStops))
    EndIf
  EndProcedure
  
  Procedure fileDownload(*file.file)
    Protected *wget.wget::wget
    Protected *mod.mod = *file\mod
    Protected filename$, folder$
    Protected NewMap strings$()
    
    
    ; only one download at a time
    LockMutex(_mutexDownload)
    If events(#EventWorkerStarts)
      PostEvent(events(#EventWorkerStarts))
    EndIf
    
    ; start
    deb("repository:: download file "+*file\url$)
    strings$("modname") = *mod\name$
    postProgressEvent(0, locale::getEx("repository", "download_start", strings$()))
    
    ; pre-process
    filename$ = *file\filename$
    If filename$ = ""
      filename$ = Str(*mod\id)+".zip"
      deb("repository:: no filename specified for file #"+*file\fileid+" in mod "+*mod\name$+", use "+filename$)
    EndIf
    
    ; download location
    folder$ = misc::Path(settings::getString("", "path") + "/TPFMM/download/")
    misc::CreateDirectoryAll(folder$)
    filename$ = folder$ + filename$
    
    *wget = wget::NewDownload(*file\url$, filename$, #RepoDownloadTimeout/1000, #True)
    *wget\setUserAgent(main::VERSION_FULL$)
    *wget\setUserData(*file)
    *wget\CallbackOnProgress(@fileDownloadProgress())
    *wget\CallbackOnSuccess(@fileDownloadSuccess())
    *wget\CallbackOnError(@fileDownloadError())
    *wget\download()
  EndProcedure
  
  Procedure fileDownload_old(*file.file)
    Protected *download.download
    Protected folder$, header$, HTTPstatus, bytes, failure.b
    Protected NewMap strings$()
    
    ;{ regular expressions for HTTP header
    Static regExpContentLength, regExpHTTPstatus
    If Not regExpContentLength
      regExpContentLength = CreateRegularExpression(#PB_Any, "Content-Length: ([0-9]+)")
    EndIf
    If Not regExpHTTPstatus
      regExpHTTPstatus = CreateRegularExpression(#PB_Any, "HTTP/\d.\d (\d\d\d)")
    EndIf
    ;}
    
    If main::isMainThread()
      ; make sure this function is not in main thread
      deb("repository:: fileDownload() fork")
      CreateThread(@fileDownload(), *file)
      ProcedureReturn #True
    EndIf
    
    ; only one download at a time
    Static mutexDownload
    If Not mutexDownload
      mutexDownload = CreateMutex()
    EndIf
    LockMutex(mutexDownload)
    If events(#EventWorkerStarts)
      PostEvent(events(#EventWorkerStarts))
    EndIf
    
    
    *download = AllocateStructure(download)
    
    ; get information from file and mod
    *download\file  = *file
    *download\mod   = *file\mod
    *download\url$  = *file\url$
    *download\file$ = *file\filename$
    *download\size  = 0
    *download\con   = 0
    *download\timeout = #RepoDownloadTimeout
    
    strings$("modname") = *download\mod\name$
    
    ; start
    deb("repository:: download file "+*file\url$)
    postProgressEvent(0, locale::getEx("repository", "download_start", strings$()))
    
    ; pre-process
    If *download\file$ = ""
      *download\file$ = Str(*download\mod\id)+".zip"
      deb("repository:: no filename specified for file #"+*file\fileid+" in mod "+*download\mod\name$+", use "+*download\file$)
    EndIf
    
    ; download location
    folder$ = misc::Path(settings::getString("", "path") + "/TPFMM/download/")
    misc::CreateDirectoryAll(folder$)
    *download\file$ = folder$ + *download\file$
    
    
    ; get header information
    header$ = GetHTTPHeader(*download\url$, 0, main::VERSION_FULL$)
    failure = #False
    If header$
      ; get HTTP status
      ExamineRegularExpression(regExpHTTPstatus, header$)
      If NextRegularExpressionMatch(regExpHTTPstatus)
        HTTPstatus = Val(RegularExpressionGroup(regExpHTTPstatus, 1))
        If HTTPstatus = 404
          deb("repository:: 404 File Not Found")
          postProgressEvent(-1, locale::getEx("repository", "download_fail", strings$()))
          failure = #True
        ElseIf HTTPstatus = 429
          deb("repository:: 429 Too Many Requests")
          postProgressEvent(-1, locale::getEx("repository", "download_429", strings$()))
          failure = #True
        EndIf
      EndIf
      
      ; get content-length
      ExamineRegularExpression(regExpContentLength, header$)
      If NextRegularExpressionMatch(regExpContentLength)
        *download\size = Val(RegularExpressionGroup(regExpContentLength, 1))
      EndIf
    EndIf
    
    If Not failure
      ; download file
      *download\con = ReceiveHTTPFile(*download\url$, *download\file$, #PB_HTTP_Asynchronous, main::VERSION_FULL$)
      If *download\con
        ; download active...
        ; monitor download progress
        bytes = fileDownloadMonitor(*download)
        deb("repsitory:: download finished with "+bytes+" bytes")
        If bytes
          ; todo meta data file for install routine?
          
          If events(#EventDownloadSuccess)
            PostEvent(events(#EventDownloadSuccess), *download\file, 0)
          EndIf
          
          mods::install(*download\file$)
          
        Else
          DeleteFile(*download\file$)
        EndIf
      Else
        ; could not start download
      EndIf
    EndIf
    
    FreeStructure(*download)
    postProgressEvent(-1, locale::getEx("repository", "download_finish", strings$()))
    
    UnlockMutex(mutexDownload)
    If events(#EventWorkerStops)
      PostEvent(events(#EventWorkerStops))
    EndIf
  EndProcedure
  
  Procedure.s fileGetLink(*file.file)
    Protected *mod.mod = *file\mod
    ProcedureReturn *mod\source$+"/"+*mod\id+"/"+*file\fileid
  EndProcedure
  
  Procedure.s fileGetFolderName(*file.file)
    ProcedureReturn *file\foldername$
  EndProcedure
  
  Procedure.s fileGetFilename(*file.file)
    ProcedureReturn *file\filename$
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
      Case #EventAddMods
        CallbackAddMods = *callback
      Case #EventClearMods
        CallbackClearList = *callback
      Case #EventRefreshFinished
        CallbackRefreshFinished = *callback
    EndSelect
  EndProcedure
  
  Procedure BindEventPost(RepoEvent, WindowEvent, *callback)
    If RepoEvent >= 0 And RepoEvent <= ArraySize(events())
      events(RepoEvent) = WindowEvent
      If *callback
        BindEvent(WindowEvent, *callback)
      EndIf
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  
EndModule
