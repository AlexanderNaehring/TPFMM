XIncludeFile "module_mods.h.pbi"

DeclareModule repository
  EnableExplicit
  
  ; Event Callbacks
  
  Enumeration
    #EventAddMods
    #EventClearMods
    #EventRefreshFinished
    #EventWorkerStarts
    #EventWorkerStops
    #EventProgress
    #EventShowModFileSelection
    #EventDownloadSuccess
  EndEnumeration
  Global EventArraySize = #PB_Compiler_EnumerationValue -1
  
  Enumeration
    #ErrorNoError = 0
    #ErrorDownloadFailed
    #ErrorJSON
    #ErrorDuplicateURL
    #ErrorNoSource
    #ErrorDuplicateSource
    #ErrorNoMods
  EndEnumeration
  
  
  Structure RepositoryInformation ; information about the mod repository
    url$
    name$
    maintainer$
    source$
    description$
    info_url$
    terms$
    modCount.i
    error.b
  EndStructure
  
  ; file interface
  Interface RepositoryFile
    getMod()
    isInstalled()
    canDownload()
    download()
    getLink.s()
    getFolderName.s()
    getFileName.s()
  EndInterface
  
  ; mod interface
  Interface RepositoryMod
    getName.s()
    getVersion.s()
    getAuthor.s()
    getFiles(List *files.RepositoryFile())
    isInstalled()
    getSource.s()
    GetRepositoryURL.s()
    canDownload()
    download()
    getLink.s()
    getThumbnailUrl.s()
    getThumbnailFile.s()
    getThumbnailAsync(*callback, *userdata)
    getTimeChanged()
    getWebsite.s()
    setThumbnailImage(image)
  EndInterface
  
  
  
  ; base methods
  Declare refreshRepositories(async=#True)
  Declare freeAll()
  Declare clearThumbCache()
  Declare.b isloaded()
  Declare stopQueue(timeout = 5000)
  
  ; source handling
  Declare AddRepository(url$)
  Declare CanRemoveRepository(url$) ; default repositories cannot be removed
  Declare RemoveRepository(url$)
  Declare ReadSourcesFromFile(List urls$())
  Declare GetRepositoryInformation(url$, *repoInfo.RepositoryInformation)
  Declare CheckRepository(url$, *repositoryInformation.RepositoryInformation)
  
  ; get mod/file object
  Declare getModByFoldername(foldername$)
  Declare getModByLink(link$)
  Declare getFileByFoldername(foldername$)
  Declare getFileByLink(link$)
  
  ; work on mod object
  Declare.s modGetName(*mod)
  Declare.s modGetVersion(*mod)
  Declare.s modGetAuthor(*mod)
  Declare modGetFiles(*mod, List *files.RepositoryFile())
  Declare modIsInstalled(*mod)
  Declare.s modGetSource(*mod)
  Declare.s modGetRepositoryURL(*mod)
  Declare modCanDownload(*mod)
  Declare modDownload(*mod)
  Declare.s modGetLink(*mod)
  Declare.s modGetThumbnailUrl(*mod)
  Declare.s modGetThumbnailFile(*mod)
  Declare modGetThumbnailAsync(*mod, *callback, *userdata=#Null) ; will call callback when image is available
  Declare modGetTimeChanged(*mod)
  Declare.s modGetWebsite(*mod)
  Declare modSetThumbnailImage(*mod, image)
  
  ; work on file object
  Declare fileGetMod(*file)
  Declare fileIsInstalled(*file)
  Declare fileCanDownload(*file)
  Declare fileDownload(*file)
  Declare.s fileGetLink(*file)
  Declare.s fileGetFolderName(*file)
  Declare.s fileGetFilename(*file)
  
  ; callbacks to GUI
  Declare BindEventCallback(Event, *callback)
  Declare BindEventPost(RepoEvent, WindowEvent, *callback)
  
  
  Prototype CallbackAddMods(List *mods.RepositoryMod())
  Prototype CallbackClearList()
  Prototype CallbackRefreshFinished()
  
  Prototype CallbackThumbnail(image, *userdata)
  
EndDeclareModule