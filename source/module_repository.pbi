XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_settings.pbi"
XIncludeFile "wget.pb"
XIncludeFile "threads.pb"

XIncludeFile "module_repository.h.pbi"

Module repository
  UseModule debugger
  UseModule locale
  
  ;{ VT
  DataSection
    vtMod:
    Data.i @modGetName()
    Data.i @modGetVersion()
    Data.i @modGetAuthor()
    Data.i @modGetFiles()
    Data.i @modIsInstalled()
    Data.i @modGetSource()
    Data.i @modGetRepositoryURL()
    Data.i @modCanDownload()
    Data.i @modDownload()
    Data.i @modGetLink()
    Data.i @modGetThumbnailUrl()
    Data.i @modGetThumbnailFile()
    Data.i @modGetThumbnailAsync()
    Data.i @modGetTimeChanged()
    Data.i @modGetWebsite()
    
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
    *modRepositoryPointer; point to parent mod repo
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
  EndStructure
  
  Structure modRepository ; the repository.json file
    repo_info.repo_info
    mod_base_url$
    file_base_url$
    thumbnail_base_url$
    List mods.mod()
    
    url$ ; map key
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
  Global NewMap *filesByFoldername.file()        ; pointer to original mods in ModRepositories\mods() with foldername as key
  Global mutexMods = CreateMutex(),
         mutexFilesMap = CreateMutex()
  Global _semaphoreDownload = CreateSemaphore(1); max number of parallel downloads
         
  Global CallbackAddMods.CallbackAddMods
  Global CallbackClearList.CallbackClearList
  Global CallbackRefreshFinished.CallbackRefreshFinished
  
  Global Dim events(EventArraySize)
  
  Global *queueThread,
         mutexQueue = CreateMutex()
  Global NewList queue.queue()
  
  Global _loaded.b
  Global _activeRepoDownloads.i
  ;}
  
  ;{ init
  #RepoDirectory$   = "repositories"
  #RepoThumbCache$  = #RepoDirectory$ + "/cache"
  #RepoListFile$    = #RepoDirectory$ + "/repositories.txt"
  #RepoDownloadTimeout = 2000 ; timeout for downloads in milliseconds
    
  Procedure init()
    CreateDirectory(#RepoDirectory$)
    CreateDirectory(#RepoThumbCache$)
    
    If FileSize(#RepoListFile$) <= 0
      Define file
      file = CreateFile(#PB_Any, #RepoListFile$)
      If file
        CloseFile(file)
      EndIf
    EndIf
    
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
  
  Procedure WriteSourcesToFile(List sources$())
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
  
  Procedure ReadSourcesFromFile(List sources$())
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
  
  Procedure.s getRepoFileName(url$)
    ProcedureReturn #RepoDirectory$ + "/" + Fingerprint(@url$, StringByteLength(url$), #PB_Cipher_MD5) + ".json"
  EndProcedure
  
  Procedure.s getThumbFileName(url$)
    Protected name$
    If url$
      name$ = Fingerprint(@url$, StringByteLength(url$), #PB_Cipher_MD5)
      ProcedureReturn #RepoThumbCache$ + "/" + Left(name$, 2) + "/" + name$ + ".jpg"
    Else
      ProcedureReturn ""
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
    *wget = wget::NewDownload(url$, file$+".download", #RepoDownloadTimeout/1000)
    *wget\setUserAgent(main::VERSION_FULL$)
    *wget\CallbackOnError(@updateRepositoryFileError())
    *wget\CallbackOnSuccess(@updateRepositoryFileSuccess())
    *wget\download()
  EndProcedure
  
  Procedure openRepositoryFile(url$)
    Protected file$,
              json,
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
    If JSONType(JSONValue(json)) <> #PB_JSON_Object 
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
    ExtractJSONStructure(JSONValue(json), *modRepository, ModRepository)
    FreeJSON(json)
    *modRepository\url$ = url$
    
    ; process
    If *modRepository\repo_info\icon$
      ; use a custom icon for mods from this repo
      ; TODO download and store repo icon
    EndIf
    If *modRepository\repo_info\source$
      LockMutex(mutexMods)
      ForEach ModRepositories()
        If ModRepositories() <> *modRepository
          If ModRepositories()\repo_info\source$ = *modRepository\repo_info\source$
            DebuggerWarning("repository:: duplicate repository source ID")
            deb("repository:: duplicate repository source ID encountered!")
            ;TODO do something about duplicate ID?
            Break
          EndIf
        EndIf
      Next
      UnlockMutex(mutexMods)
    Else
      deb("repository:: "+url$+" has no source information")
    EndIf
    
    ForEach *modRepository\mods()
      With *modRepository\mods()
        ; mod vt
        \vt = ?vtMod
        ; source
        \modRepositoryPointer = *modRepository
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
          \tagsLocalized$() = _("tags_"+\tags$())
        Next
      EndWith
    Next
   
    ; populate pointer map
    Protected foldername$
    Protected *mod.mod, *file.file
    LockMutex(mutexFilesMap)
    ForEach *modRepository\mods()
      ForEach *modRepository\mods()\files()
        foldername$ = *modRepository\mods()\files()\foldername$
        If foldername$ And foldername$ <> "<unknown>"
          If Not FindMapElement(*filesByFoldername(), foldername$)
            *filesByFoldername(foldername$) = *modRepository\mods()\files()
          Else
            *file = *filesByFoldername(foldername$)
            *mod = *file\mod
            deb("repository:: found duplicate foldername information for <"+*modRepository\mods()\files()\foldername$+">" + ~"\t" + 
                "linked mod: "+*mod\source$+"/"+*mod\id+"/"+*file\fileid+ ", " + ~"\t" + 
                "ignored mod: "+*modRepository\mods()\source$+"/"+*modRepository\mods()\id+"/"+*modRepository\mods()\files()\fileid)
          EndIf
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
    deb("repository:: refreshRepositories()")
    
    N = ReadSourcesFromFile(repositories$())
    
    postProgressEvent(0, _("repository_load"))
    
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
      postProgressEvent(-1, _("repository_loaded"))
    Else
      postProgressEvent(-1, _("repository_load_failed"))
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
    Protected tmp$, *wget.wget::wget
    ; TODO this function can be optimized!
    
    ; download for same image may be triggered multiple times!
    ; make sure, same image is not downloaded in parallel
    
      url$ = *thumbnailData\mod\thumbnail$
      
      ; check if image on disk
      file$ = getThumbFileName(url$)
      
      If FileSize(file$) <= 0
        ; download image
        Debug "Download Thumbnail '"+*thumbnailData\mod\thumbnail$+"'"
        tmp$ = GetTemporaryDirectory() + StringFingerprint(Str(Date()), #PB_Cipher_MD5)
        If FileSize(tmp$) > 0
          DeleteFile(tmp$, #PB_FileSystem_Force)
        EndIf
        *wget = wget::NewDownload(url$, tmp$, 2)
        *wget\download()
        While Not *wget\isFinished()
          If threads::IsStopRequested()
            *wget\abort()
            ProcedureReturn #False
          EndIf
          Delay(10)
        Wend
        If FileSize(tmp$) > 0
          image = LoadImage(#PB_Any, tmp$)
          DeleteFile(tmp$, #PB_FileSystem_Force)
          If image
            image = misc::ResizeCenterImage(image, 160, 90)
            CreateDirectory(GetPathPart(file$))
            SaveImage(image, file$, #PB_ImagePlugin_JPEG, 7, 24)
            FreeImage(image)
          Else
            Debug "cold not load image"
          EndIf
        Else
          Debug "download failed"
        EndIf
      EndIf
      
    If FileSize(file$) > 0
      *thumbnailData\callback(*thumbnailData\mod, file$, *thumbnailData\userdata)
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
      
    Until threads::IsStopRequested()
  EndProcedure
  
  Procedure addToQueue(callback.callbackQueue, *userdata, addInFront=#False)
    LockMutex(mutexQueue)
    If addInFront
      FirstElement(queue())
      InsertElement(queue())
    Else
      LastElement(queue())
      AddElement(queue())
    EndIf
    queue()\callback = callback
    queue()\userdata = *userdata
    UnlockMutex(mutexQueue)
    
    If Not *queueThread
      *queueThread = threads::NewThread(@QueueThread(), 0, "repository::queueThread")
    EndIf
  EndProcedure
  
  Procedure stopQueue(timeout = 5000)
    If *queueThread
      threads::WaitStop(*queueThread, timeout, #True)
      LockMutex(mutexQueue)
      ClearList(queue())
      ; might cause memory leak, as allocated memory is intended to be freed in queue function...
      UnlockMutex(mutexQueue)
      *queueThread = #Null
    EndIf
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;----------------------------- PUBLIC FUNCTION ------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure refreshRepositories(async=#True)
    stopQueue()
    freeAll()
    
    ; always add official repositories to sources
    AddRepository("https://www.transportfevermods.com/repository/mods/tpfnet.json")
    AddRepository("https://www.transportfevermods.com/repository/mods/workshop.json")
    
    If async
      addToQueue(@queueRefreshRepositories(), #Null, #True)
    Else
      queueRefreshRepositories(0)
    EndIf
  EndProcedure
  
  Procedure freeAll()
    deb("repository:: freeAll()")
    
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
    
    ; clear maps, should also clear mod list in the map
    ClearMap(ModRepositories())
    ClearMap(*filesByFoldername())
    
    UnlockMutex(mutexFilesMap)
    UnlockMutex(mutexMods)
  EndProcedure
  
  Procedure clearThumbCache()
    Protected dir$
    
    DeleteDirectory(#RepoThumbCache$, "", #PB_FileSystem_Recursive)
    CreateDirectory(#RepoThumbCache$)
    
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
    ReadSourcesFromFile(sources$())
    
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
      WriteSourcesToFile(sources$())
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
    deb("repository:: remove source "+url$)
    
    ReadSourcesFromFile(sources$())
    
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
      WriteSourcesToFile(sources$())
    EndIf
  EndProcedure
  
  Procedure GetRepositoryInformation(url$, *repoInfo.RepositoryInformation)
    Protected ret = #False
    LockMutex(mutexMods)
    If FindMapElement(ModRepositories(), url$)
      *repoInfo\error         = #ErrorNoError
      *repoInfo\url$          = MapKey(ModRepositories())
      *repoInfo\source$       = ModRepositories()\repo_info\source$
      *repoInfo\name$         = ModRepositories()\repo_info\name$
      *repoInfo\maintainer$   = ModRepositories()\repo_info\maintainer$
      *repoInfo\description$  = ModRepositories()\repo_info\description$
      *repoInfo\terms$        = ModRepositories()\repo_info\terms$
      *repoInfo\info_url$     = ModRepositories()\repo_info\info_url$
      *repoInfo\modCount      = ListSize(ModRepositories()\mods())
      ret = #True
    EndIf
    UnlockMutex(mutexMods)
    ProcedureReturn ret
  EndProcedure
  
  Procedure CheckRepository(url$, *RepoInfo.RepositoryInformation)
    Protected file$
    Protected *wget.wget::wget
    Protected json, *value, *modRepository.modRepository
    Protected duplicate
    Protected ret
    deb("repository:: CheckRepository("+url$+")")
    
    ; try to download repository
    file$ = GetTemporaryDirectory()+"tpfmm-repository.tmp"
    DeleteFile(file$, #PB_FileSystem_Force)
    *wget = wget::NewDownload(url$, file$, #RepoDownloadTimeout/1000)
    *wget\setUserAgent(main::VERSION_FULL$)
    *wget\download()
    *wget\waitFinished()
    If  FileSize(file$) > 0
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
            ; extract repository information
            *modRepository = AllocateStructure(modRepository)
            ExtractJSONStructure(*value, *modRepository, modRepository)
            deb("repository:: identified repo at "+url$+": "+*modRepository\repo_info\name$+" by "+*modRepository\repo_info\maintainer$)
            *RepoInfo\url$         = url$
            *RepoInfo\source$      = *modRepository\repo_info\source$
            *RepoInfo\name$        = *modRepository\repo_info\name$
            *RepoInfo\maintainer$  = *modRepository\repo_info\maintainer$
            *RepoInfo\description$ = *modRepository\repo_info\description$
            *RepoInfo\terms$       = *modRepository\repo_info\terms$
            *RepoInfo\info_url$    = *modRepository\repo_info\info_url$
            *RepoInfo\modCount     = ListSize(*modRepository\mods())
            ; check if source not empty
            If Trim(*RepoInfo\source$) <> ""
              ; check if source duplicate
              duplicate = #False
              LockMutex(mutexMods)
              ForEach ModRepositories()
                If LCase(ModRepositories()\repo_info\source$) = LCase(*RepoInfo\source$)
                  duplicate = #True
                  Break
                EndIf
              Next
              UnlockMutex(mutexMods)
              If Not duplicate
                ; check if mod count is zero
                If *RepoInfo\modCount > 0
                  ; everything looks good, return true (repo can be added!)
                  *RepoInfo\error = #ErrorNoError
                  ret = #True
                Else
                  deb("repository:: "+url$+" has no mods")
                  *RepoInfo\error = #ErrorNoMods
                  ret = #False
                EndIf
              Else
                deb("repository:: "+url$+" has same source as another loaded repository")
                *RepoInfo\error = #ErrorDuplicateSource
                ret = #False
              EndIf
            Else
              deb("repository:: "+url$+" has no source information or could not extract modRepository Information from JSON")
              *RepoInfo\error = #ErrorNoSource
              ret = #False
            EndIf
          Else
            deb("repository:: "+url$+" already loaded")
            *RepoInfo\error = #ErrorDuplicateURL
            ret = #False
          EndIf
        Else
          deb("repository:: invalid JSON type in "+url$)
          *RepoInfo\error = #ErrorJSON
          ret = #False
        EndIf
        FreeJSON(json)
      Else
        deb("repository:: could not parse JSON from "+url$)
        *RepoInfo\error = #ErrorJSON
        ret = #False
      EndIf
      DeleteFile(file$, #PB_FileSystem_Force)
    Else
      deb("repository:: download failed "+url$)
      *RepoInfo\error = #ErrorDownloadFailed
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
    Protected *file
    
    ; can only download mods to "manual" mods/ folder, not to workshop or staging area!
    If Left(foldername$, 1) = "*" Or Left(foldername$, 1) = "?"
      Debug "repository:: looking for a workshop or staging area mod in repo. removeing prefix!"
      foldername$ = Mid(foldername$, 2)
      Debug "search for "+foldername$
    EndIf
    
    LockMutex(mutexFilesMap)
    ; check if "foldername" is version independend, e.g. "urbangames_vehicles_no_end_year" (no _1 at the end)
    If #False
      ;TODO search version independen, e.g. also find _1 when searchign for _0 ?
      ; by UG definition, major versions are incompatible to each other - thus no need to find these versions.
      
      ; try to find a file matching the foldername without the version
      Protected regExpFolder, version
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
  
  Procedure.s modGetRepositoryURL(*mod.mod)
    Protected *modRepo.ModRepository
    
    *modRepo.ModRepository = *mod\modRepositoryPointer
    ProcedureReturn *modRepo\url$
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
      
      addToQueue(@queueThumbnail(), *thumbnailData, #True)
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
  
  Declare fileDownloadProgress(*wget.wget::wget)
  Declare fileDownloadError(*wget.wget::wget)
  Declare fileDownloadSuccess(*wget.wget::wget)
  
  Procedure downloadURL(url$, filename$, *userdata=#Null)
    Protected *wget.wget::wget
    *wget = wget::NewDownload(url$, filename$, #RepoDownloadTimeout/1000)
    *wget\setUserAgent(main::VERSION_FULL$)
    *wget\setUserData(*userdata)
    *wget\CallbackOnProgress(@fileDownloadProgress())
    *wget\CallbackOnSuccess(@fileDownloadSuccess())
    *wget\CallbackOnError(@fileDownloadError())
    *wget\download()
  EndProcedure
  
  Procedure fileDownloadProgress(*wget.wget::wget)
    postProgressEvent(*wget\getProgress())
  EndProcedure
  
  Procedure fileDownloadError(*wget.wget::wget)
    Protected *file.file, *mod.mod
    Protected url$
    
    deb("repository:: fileDownloadError()")
    
    *file = *wget\getUserData()
    *mod = *file\mod
    url$ = *wget\getRemote()
    *wget\free()
    *wget = #Null
    
    deb("repository:: download error: "+url$)
    postProgressEvent(-1, _("repository_download_fail", "modname="+*mod\name$))
    
    SignalSemaphore(_semaphoreDownload)
    If events(#EventWorkerStops)
      PostEvent(events(#EventWorkerStops))
    EndIf
  EndProcedure
  
  Procedure fileDownloadSuccess(*wget.wget::wget)
    Protected *file.file, *mod.mod
    Protected filename$
    
    deb("repository:: fileDownloadSuccess()")
    
    *file = *wget\getUserData()
    *mod = *file\mod
    filename$ = *wget\getFilename()
    *wget\free()
    *wget = #Null
    
    postProgressEvent(-1, _("repository_download_finish", "modname="+*mod\name$))
    If events(#EventDownloadSuccess)
      PostEvent(events(#EventDownloadSuccess), *file, 0)
    EndIf
    
    ; additional check:
    ; tpfnet downloads may be a redirect page instead of actual file...
    Protected file, line$
    Protected regExp, redirect$
    If FileSize(filename$) < 50*1024 ; may be a redirtect page
      file = ReadFile(#PB_Any, filename$, #PB_UTF8)
      If file
        regExp = CreateRegularExpression(#PB_Any, ~"<meta http-equiv=\"refresh\" content=\"(\\d+);URL=(.+)\" />")
        While Not Eof(file)
          line$ = ReadString(file)
          If MatchRegularExpression(regExp, line$)
            If ExamineRegularExpression(regExp, line$)
              While NextRegularExpressionMatch(regExp)
                redirect$ = Trim(RegularExpressionGroup(regexp, 2))
              Wend
            EndIf
          EndIf
        Wend
        FreeRegularExpression(regExp)
        CloseFile(file)
      EndIf
    EndIf
    
    If redirect$ = ""
      mods::install(filename$)
    EndIf
    
    SignalSemaphore(_semaphoreDownload)
    If events(#EventWorkerStops)
      PostEvent(events(#EventWorkerStops))
    EndIf
    
    If redirect$
      ; will re-download new URL
      deb("repository:: download was HTML with redirection - redirect to "+redirect$)
      downloadURL(redirect$, filename$, *file)
    EndIf
    
  EndProcedure
  
  Procedure fileDownload(*file.file)
    Protected *wget.wget::wget
    Protected *mod.mod = *file\mod
    Protected filename$, folder$
    
    If threads::isMainThread()
      threads::NewThread(@fileDownload(), *file, "repository::fileDownload")
      ProcedureReturn
    EndIf
    
    ; only one download at a time
    ; simple: just "WaitSemaphore()", TrySemaphore() only for debug
    CompilerIf #PB_Compiler_Debugger
      If Not TrySemaphore(_semaphoreDownload)
        deb("repository:: wait for free download slot...")
        WaitSemaphore(_semaphoreDownload)
        deb("repository:: download slot got available, start now")
      EndIf
    CompilerElse
      WaitSemaphore(_semaphoreDownload)
    CompilerEndIf
    
    If events(#EventWorkerStarts)
      PostEvent(events(#EventWorkerStarts))
    EndIf
    
    ; start
    deb("repository:: download file "+*file\url$)
    postProgressEvent(0, _("repository_download_start", "modname="+*mod\name$))
    
    ; pre-process
    filename$ = *file\filename$
    If filename$ = ""
      filename$ = Str(*mod\id)+".zip"
      deb("repository:: no filename specified for file #"+*file\fileid+" in mod "+*mod\name$+", use "+filename$)
    EndIf
    
    ; download location
    folder$ = misc::Path(settings::getString("", "path") + "/TPFMM/download/")
    misc::CreateDirectoryAll(folder$)
    filename$ = folder$ + #PS$ + filename$
    
    downloadURL(*file\url$, filename$, *file)
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
