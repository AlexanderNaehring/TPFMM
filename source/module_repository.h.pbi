XIncludeFile "module_mods.h.pbi"

DeclareModule repository
  EnableExplicit
  
  ; file interface
  Interface RepositoryFile
    getMod()
    isInstalled()
    canDownload()
    download()
    getLink.s()
    getFolderName.s()
  EndInterface
  
  ; mod interface
  Interface RepositoryMod
    getName.s()
    getVersion.s()
    getAuthor.s()
    getFiles(List *files.RepositoryFile())
    isInstalled()
    getSource.s()
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
  Declare clearCache()
  
  ; source handling
  Declare AddRepository(url$)
  Declare CanRemoveRepository(url$) ; default repositories cannot be removed
  Declare RemoveRepository(url$)
  Declare GetRepositories(List urls$())
  Declare GetRepositoryModCount(url$)
  
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
  
  ; callbacks to GUI
  Declare BindEventCallback(Event, *callback)
  Declare BindEventPost(RepositoryEvent, WindowEvent)
  
  ; Event Callbacks
  Enumeration 0 ; Event Callbacks
    #CallbackAddMods    ; add a list of mods to the GUI    
    #CallbackClearList  ; clear the mod list
    #CallbackRefreshFinished ; information: repo refresh finish
  EndEnumeration
  
  Prototype CallbackAddMods(List *mods.RepositoryMod())
  Prototype CallbackClearList()
  Prototype CallbackRefreshFinished()
  
  Prototype CallbackThumbnail(image, *userdata)
  
  
;   ; check functions
;   Declare getModByID(source$, id.q)
;   Declare getFileByID(*repoMod.mod, fileID.q)
;   Declare canDownloadModByID(source$, id.q, fileID.q = 0)
;   Declare canDownloadMod(*repoMod.mod)
;   Declare canDownloadFile(*file.file)
;   Declare download(source$, id.q, fileID.q = 0)
;   
;   ; search for mod by link or foldername
;   Declare getModByLink(link$)
;   Declare getModByFoldername(foldername$)
;   Declare.s getLinkByFoldername(foldername$)
;   
;   ; other
;   Declare refresh()
;   Declare clearCache()
;   Declare listRepositories(Map gadgets()) ; used by settings window
;   
;   Global TPFMM_UPDATE.tpfmm
;   Global _READY
  
EndDeclareModule