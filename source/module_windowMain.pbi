
DeclareModule windowMain
  EnableExplicit
  
  Global window
  
  Enumeration progress
    #Progress_Hide      = -1
    #Progress_NoChange  = -2
  EndEnumeration
  
  Declare start()
  
  Declare updateStrings()
  Declare getSelectedMods(List *mods())
  Declare repoFindModAndDownload(link$)
  Declare handleParameter(parameter$)
  
EndDeclareModule

XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowSettings.pbi"
XIncludeFile "module_mods.h.pbi"
XIncludeFile "module_repository.h.pbi"
XIncludeFile "module_modInformation.pbi"
XIncludeFile "module_modSettings.pbi"
XIncludeFile "module_pack.pbi"
XIncludeFile "module_windowPack.pbi"
XIncludeFile "module_canvasList.pbi"
XIncludeFile "module_tfsave.pbi"
XIncludeFile "animation.pb"
XIncludeFile "windowProgress.pb"
XIncludeFile "threads.pb"

Module windowMain
  UseModule debugger
  UseModule locale
  
  ;{ Structures
  Structure dialog
    dialog.i
    window.i
    listGadget.i
    activeGadget.i
  EndStructure
  
  Structure fileSelectionDialog
    dialog.i
    window.i
    Map repoSelectFilesGadget.i()
  EndStructure
  
  Structure shareMods
    foldername$
    name$
    author$
    version$
    imageB64$
    website$
    download$
    source$
  EndStructure
  
  Structure GithubAssets
    url$
    id.i
    name$
    size.i
    browser_download_url$
  EndStructure
  
  Structure GithubRelease
    url$
    id.i
    name$
    html_url$
    tag_name$
    published_at$
    body$
    List assets.GitHubAssets()
  EndStructure
  
  Structure version
    major.i
    minor.i
    patch.i
  EndStructure
  
  ;}
  
  Macro gadget(name)
    DialogGadget(dialog, name)
  EndMacro
  
  ;{ Enumeration
  Enumeration
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      #PB_Menu_Quit
      #PB_Menu_Preferences
      #PB_Menu_About
    CompilerEndIf
    #MenuItem_AddMod
    #MenuItem_ShowBackups
    #MenuItem_ShowDownloads
    #MenuItem_Homepage
    #MenuItem_Log
    #MenuItem_Enter
    #MenuItem_CtrlA
    #MenuItem_CtrlF
;     #MenuItem_PackNew
;     #MenuItem_PackOpen
    
    #MenuItem_ShareSelected
    #MenuItem_ShareFiltered
    #MenuItem_ShareAll
    
    #MenuItem_AddToPack
  EndEnumeration
  
  Enumeration #PB_Event_FirstCustomValue ; custom events that are processed by the main thread
    #ShowDownloadSelection
    
    #EventStartUpFinished
    #EventCloseNow
    
    #EventModNew
    #EventModRemove
    #EventModStopDraw
    #EventModProgress
    
    #EventRepoAddMod
    #EventRepoClearList
    #EventRepoRefreshFinished
    #EventRepoModFileSelection
    #EventRepoPauseDraw
    #EventRepoProgress
    
    #EventWorkerStarts
    #EventWorkerStops
    
    #EventUpdateAvailable
  EndEnumeration
  
  Enumeration #PB_EventType_FirstCustomValue
    
  EndEnumeration
  
  Enumeration
    #TabMods
    #TabMaps
    #TabOnline
    #TabBackup
    #TabSaves
    #TabSettings
  EndEnumeration
  ;}
  
  ;{ Gobals
  Global xml ; keep xml dialog in order to manipulate for "selectFiles" dialog
  
  Global dialog
  Global modFilter.dialog, modSort.dialog,
         repoFilter.dialog, repoSort.dialog,
         backupFilter.dialog, backupSort.dialog
  Global menu, menuShare
  Global currentTab
  
  Global modShareHTML$
  misc::BinaryAsString("html/mods.html", modShareHTML$)
  
  ;- Timer
  Global TimerMain = 101
  
  ; other stuff
  Declare backupRefreshList()
  
  Global *modList.CanvasList::CanvasList
  Global *repoList.CanvasList::CanvasList
  Global *backupList.CanvasList::CanvasList
  Global *saveModList.CanvasList::CanvasList
  
  Global *workerAnimation.animation::animation
  ;}
  
  ;{ Declares
  ; required declares
  Declare create()
  Declare saveOpenFile(file$)
  
  Declare navBtnMods()
  Declare navBtnMaps()
  Declare navBtnOnline()
  Declare navBtnSaves()
  Declare navBtnBackups()
  ;}
  
  UseJPEGImageEncoder()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure resize()
    ResizeImage(images::Images("headermain"), WindowWidth(window), 8, #PB_Image_Raw)
    SetGadgetState(gadget("headerMain"), ImageID(images::Images("headermain")))
  EndProcedure
  
  Procedure updateModButtons()
    Protected text$, author$
    Protected NewList *items.CanvasList::CanvasListItem()
    Protected *mod.mods::LocalMod
    Protected numSelected, numCanUninstall, numCanBackup
    
    If *modList\GetAllSelectedItems(*items())
      numSelected = ListSize(*items())
      ForEach *items()
        *mod = *items()\GetUserData()
        If *mod\canBackup()
          numCanBackup + 1
        EndIf
        If *mod\canUninstall()
          numCanUninstall + 1
        EndIf
      Next
    EndIf
    
    DisableGadget(gadget("modBackup"),    Bool(numCanBackup = 0))
    DisableGadget(gadget("modUninstall"), Bool(numCanUninstall = 0))
    
    If numSelected = 0
      DisableGadget(gadget("modUpdate"), #True)
      
    Else
      DisableGadget(gadget("modUpdate"), Bool(Not *mod\getRepoMod()))
      
      ; website 
;       If *mod\getWebsite() Or *mod\getTfnetID() Or *mod\getWorkshopID()
;       EndIf
    EndIf
    
  EndProcedure
  
  Procedure updateRepoButtons()
    Protected text$, author$
    Protected NewList *items.CanvasList::CanvasListItem()
    Protected *mod.repository::RepositoryMod
    Protected numSelected, numCanDownload
    
    If *repoList\GetAllSelectedItems(*items())
      numSelected = ListSize(*items())
      ForEach *items()
        *mod = *items()\GetUserData()
        If *mod\canDownload()
          numCanDownload + 1
        EndIf
      Next
    EndIf
    
    DisableGadget(gadget("repoWebsite"), Bool(numSelected <> 1))
    DisableGadget(gadget("repoDownload"), Bool(numCanDownload = 0))
    
  EndProcedure
  
  Procedure updateBackupButtons()
    Protected NewList *items.CanvasList::CanvasListItem()
    If *backupList\GetAllSelectedItems(*items())
      DisableGadget(gadget("backupRestore"), #False)
      DisableGadget(gadget("backupDelete"), #False)
    Else
      DisableGadget(gadget("backupRestore"), #True)
      DisableGadget(gadget("backupDelete"), #True)
    EndIf
  EndProcedure
  
  Procedure getSemanticVersion(string$, *version.version)
    Protected re, ret
    If *version
      re = CreateRegularExpression(#PB_Any, "(\d+)\.(\d+).(\d+)")
      If re And ExamineRegularExpression(re, string$)
        If NextRegularExpressionMatch(re)
          *version\major = Val(RegularExpressionGroup(re, 1))
          *version\minor = Val(RegularExpressionGroup(re, 2))
          *version\patch = Val(RegularExpressionGroup(re, 3))
          ret = #True
        EndIf
        FreeRegularExpression(re)
      EndIf
    EndIf
    ProcedureReturn ret
  EndProcedure
  
  Procedure semanticVersionIsGreater(*current.version, *new.version)
    If *new\major > *current\major
      ProcedureReturn #True
    ElseIf *new\major = *current\major
      If *new\minor > *current\minor
        ProcedureReturn #True
      ElseIf *new\minor = *current\minor
        If *new\patch > *current\patch
          ProcedureReturn #True
        EndIf
      EndIf
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure checkUpdate(*null)
    Protected json, tpfmm
    Protected tmp$, *wget.wget::wget
    Protected local.version, remote.version
    Static latest.GithubRelease ; keep in memory for GUI to access the data
    
    tmp$ = GetTemporaryDirectory() + StringFingerprint(Str(Date()), #PB_Cipher_MD5)
    If FileSize(tmp$) > 0
      DeleteFile(tmp$, #PB_FileSystem_Force)
    EndIf
    *wget = wget::NewDownload(main::#UPDATER$, tmp$, 2, #False)
    *wget\setUserAgent(main::#VERSION$)
    *wget\download()
    If FileSize(tmp$) > 0
      json = LoadJSON(#PB_Any, tmp$, #PB_JSON_NoCase)
      DeleteFile(tmp$, #PB_FileSystem_Force)
      If json
        ExtractJSONStructure(JSONValue(json), @latest, GithubRelease)
        If ListSize(latest\assets()) > 0 ; binaries available
          If getSemanticVersion(main::#VERSION$, @local) And getSemanticVersion(latest\tag_name$, @remote)
            If semanticVersionIsGreater(local, remote)
              PostEvent(#EventUpdateAvailable, window, @latest)
            Else
              deb("windowMain:: updater, no update available")
            EndIf
          Else
            deb("windowMain:: updater, could not read semantic version")
          EndIf
        Else
          deb("windowMain:: updater, could not find json member 'tpfmm'")
        EndIf
        FreeJSON(json)
      Else
        deb("windowMain:: updater, json error '"+JSONErrorMessage()+"'")
      EndIf
    Else
      deb("windowMain:: updater, version information download failed '"+main::#UPDATER$+"'")
    EndIf
  EndProcedure
  
  Procedure updateAvailable()
    Protected *latest.GithubRelease
    *latest = EventGadget()
    
    If *latest
      If MessageRequester(_("update_available"), _("update_available_text", "name="+*latest\name$+#SEP+"tag="+*latest\tag_name$+#SEP+"body="+*latest\body$), #PB_MessageRequester_Info|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
        misc::openLink(*latest\html_url$)
      EndIf
    EndIf
  EndProcedure
  
  Procedure handleParameter(parameter$)
    Select LCase(parameter$)
      Case "-show"
        If window And IsWindow(window)
          ; normal/maximize may behave differently on linux (linux mint 18.1: maximze = normal and normal = on left edge)
          ; catch this behaviour??
          Select GetWindowState(window)
            Case #PB_Window_Minimize
              SetWindowState(window, #PB_Window_Normal)
          EndSelect
        EndIf
        
      Default
        If Left(parameter$, 17) = "tpfmm://download/"
          parameter$ = Mid(parameter$, 18) ; /source/modID/fileID
          repoFindModAndDownload(parameter$)
          
        ElseIf Left(parameter$, 23) = "tpfmm://repository/add/"
          parameter$ = Mid(parameter$, 24)
          windowSettings::show()
          windowSettings::showTab(windowSettings::#TabRepository)
          windowSettings::repositoryAddURL(parameter$)
          
        ElseIf FileSize(parameter$) > 0
          ; install mod... (this function is called, before the main window is created ....
          mods::install(parameter$)
        EndIf
        
    EndSelect
  EndProcedure
  
  ;- exit procedure
  
  Procedure closeThread(Event)
    Protected xmlClose
    ; todo make sure that all resources are correctly freed
    ; e.g. better check mods/repo memory
    ; also close any windows (settings, mod info, dialogs, etc...)
    deb("windowMain:: closeThread("+Event+")")
    
    HideWindow(window, #True)
    
    ; free the worker animation thread in the main windows (window hidden already)
    ; otherwise, if worker is still animated during shutdown, might cause IMA
    *workerAnimation\free()
    *workerAnimation = #Null
    
    windowProgress::setProgressPercent(15)
    windowProgress::setProgressText(_("progress_close"))
    
    settings::setInteger("window", "x", WindowX(windowMain::window, #PB_Window_FrameCoordinate))
    settings::setInteger("window", "y", WindowY(windowMain::window, #PB_Window_FrameCoordinate))
    settings::setInteger("window", "width", WindowWidth(windowMain::window))
    settings::setInteger("window", "height", WindowHeight(windowMain::window))
    
    settings::setInteger("window", "tab", currentTab)
    
    windowProgress::setProgressPercent(30)
    windowProgress::setProgressText(_("progress_stop_worker"))
    deb("windowMain:: stop workers")
    mods::stopQueue()
    windowProgress::setProgressPercent(45)
    wget::freeAll()
    repository::stopQueue()
    
    windowProgress::setProgressPercent(60)
    windowProgress::setProgressText(_("progress_save_list"))
    mods::saveList()
    
    windowProgress::setProgressPercent(75)
    windowProgress::setProgressText(_("progress_cleanup"))
    deb("windowMain:: cleanup")
    mods::freeAll()
    windowProgress::setProgressPercent(90)
    repository::freeAll()
    
    windowProgress::setProgressPercent(99)
    windowProgress::setProgressText(_("progress_goodbye"))
    
    ; free all dialogs
    FreeDialog(modFilter\dialog)
    FreeDialog(modSort\dialog)
    FreeDialog(repoFilter\dialog)
    FreeDialog(repoSort\dialog)
    windowSettings::close()
    
    windowProgress::closeProgressWindow()
    
    locale::logStats()
    PostEvent(event) ; inform main thread that closure procedure is finished
  EndProcedure
  
  Procedure close()
    deb("windowMain:: close window")
    ; the exit procedure will run in a thread and wait for all workers to finish etc...
    windowProgress::showProgressWindow(_("progress_close"), #EventCloseNow)
    CreateThread(@closeThread(), #EventCloseNow)
    ; todo also set up a timer event to close programm after (e.g.) 1 minute if cleanup procedure fails?
  EndProcedure
  
  ;- start procedure
  
  Procedure startThread(EventOnFinish)
    Protected i
    
    windowProgress::setProgressText(_("progress_init"))
    windowProgress::setProgressPercent(0)
    
    ; read gameDirectory from preferences
    deb("main:: - game directory: "+settings::getString("", "path"))
    
    If misc::checkGameDirectory(settings::getString("", "path"), main::_TESTMODE) <> 0
      deb("main:: game directory not correct")
      settings::setString("", "path", "")
    EndIf
    
    windowProgress::setProgressPercent(10)
    
    ; proxy (read from preferences)
    main::initProxy()
    
    ; desktopIntegration
    main::updateDesktopIntegration()
    
    ;{ Restore window location (complicated version)
    Protected nDesktops, desktop, locationOK
    Protected windowX, windowY, windowWidth, windowHeight
    deb("main:: reset main window location")
    
    If #True
      windowX = settings::getInteger("window", "x")
      windowY = settings::getInteger("window", "y")
      windowWidth   = settings::getInteger("window", "width")
      windowHeight  = settings::getInteger("window", "height")
      
      ; get desktops
      nDesktops = ExamineDesktops()
      If Not nDesktops
        deb("main:: cannot find Desktop!")
        End
      EndIf
      
      ; check if location is valid
      locationOK = #False
      For desktop = 0 To nDesktops - 1
        ; location is okay, if whole window is in desktop!
        If windowX                > DesktopX(desktop)                         And ; left
           windowX + windowHeight < DesktopX(desktop) + DesktopWidth(desktop) And ; right
           windowY                > DesktopY(desktop)                         And ; top
           windowY + windowHeight < DesktopY(desktop) + DesktopHeight(desktop)    ; bottom
          locationOK = #True
          deb("main:: window location valid on desktop #"+desktop)
          Break
        EndIf
      Next
      
      If locationOK 
        deb("main:: set window location: ("+windowX+", "+windowY+", "+windowWidth+", "+windowHeight+")")
        ResizeWindow(windowMain::window, windowX, windowY, windowWidth, windowHeight)
        PostEvent(#PB_Event_SizeWindow, windowMain::window, 0)
      EndIf
    EndIf
    ;}
    
    
    windowProgress::setProgressPercent(20)
    
    ; load mods and repository
    If settings::getString("", "path")
      windowProgress::setProgressText(_("progress_load_mods"))
      mods::load(#False)
      windowProgress::setProgressPercent(50)
      
      
      windowProgress::setProgressText(_("progress_load_repo"))
      repository::refreshRepositories(#False)
      windowProgress::setProgressPercent(80)
    EndIf
    
    windowProgress::setProgressPercent(90)
    
    
    windowProgress::setProgressPercent(99)
    
    ; start updater thread
    CreateThread(@checkUpdate(), #Null)
    
    ; open settings dialog if required
    If settings::getString("", "path") = ""
      ; no path specified upon program start -> open settings dialog
      deb("main:: no game directory defined - open settings dialog")
      PostEvent(#PB_Event_Gadget, window, gadget("btnSettings"))
    EndIf
    
    ; select tab
    Select settings::getInteger("window", "tab")
      Case #TabOnline
        navBtnOnline()
      Case #TabBackup
        navBtnBackups()
      Case #TabSaves
        navBtnSaves()
    EndSelect
    
    ; show main window
    windowProgress::closeProgressWindow()
    If locationOK
      HideWindow(window, #False)
    Else
      HideWindow(window, #False, #PB_Window_ScreenCentered)
    EndIf
    PostEvent(EventOnFinish, window, #Null)
  EndProcedure
  
  Procedure startupFinished()
    Protected i
    ; called when startup procedure is finished
    
    If Not threads::isMainThread()
      DebuggerError("must be in main thread")
    EndIf
    
    ; parameter handling
    For i = 0 To CountProgramParameters() - 1
      handleParameter(ProgramParameter(i))
    Next
  EndProcedure
  
  
  ; entry point: start()
  Procedure start()
    Protected i
    
    If Not threads::isMainThread()
      deb("windowMain:: start() not in main thread!")
      RaiseError(#PB_OnError_Breakpoint)
    EndIf
    
    ; open main window and bind events
    create() 
    
    ; open settings window
    windowSettings::create(window)
    
    ; startup procedure
    windowProgress::showProgressWindow(_("progress_start"), #EventCloseNow)
    CreateThread(@startThread(), #EventStartupFinished)
  EndProcedure
  
  ; ---
  
  Procedure handleFile(file$)
    Select LCase(GetExtensionPart(file$))
      Case pack::#EXTENSION
        windowPack::show(window)
        windowPack::packOpen(file$)
      Case "sav"
        saveOpenFile(file$)
        navBtnSaves()
      Case "html"
        ;TODO handle import of HTML files (aka mod lists)
        ; or only use links to mod packs?
      Default
        mods::install(file$)
    EndSelect
  EndProcedure
  
  Procedure websiteTrainFeverNet()
    misc::openLink("http://goo.gl/8Dsb40") ; Homepage (Train-Fever.net)
  EndProcedure
  
  Procedure websiteTrainFeverNetDownloads()
    misc::openLink("http://goo.gl/Q75VIM") ; Downloads / Filebase (Train-Fever.net)
  EndProcedure
  
  ;- Worker & progress
  
  Procedure workerChange(change)
    ; multiple workers can be active at any given time, count # active workers
    Static activeWorkers
    If *workerAnimation
      activeWorkers + change
      If activeWorkers > 0
        If *workerAnimation\isPaused()
          *workerAnimation\play()
        EndIf
      Else
        If Not *workerAnimation\isPaused()
          *workerAnimation\pause()
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  Procedure workerStart()
    workerChange(1)
  EndProcedure
  
  Procedure workerStop()
    workerChange(-1)
  EndProcedure
  
  ;-------------------------------------------------
  ;- TIMER
  
  ;- MENU
  
  Procedure MenuItemHomepage()
    misc::openLink(main::#WEBSITE$) ; Download Page TFMM (Train-Fever.net)
  EndProcedure
  
  Procedure MenuItemLog()
    ; show log file
    Protected log$, file$, file
    ; write log to tmp file as default Windows notepad will not open the active .log file while it is being used by TPFMM
    log$ = debugger::getLog()
    file$ = misc::path(GetTemporaryDirectory()) + "tpfmm-log.txt"
    file = CreateFile(#PB_Any, file$, #PB_File_SharedWrite)
    If file
      WriteString(file, log$)
      CloseFile(file)
      misc::openLink(file$)
    EndIf
  EndProcedure
  
  Procedure MenuItemEnter()
    If GetActiveGadget() = gadget("repoList")
      ;TODO enter hotkey
    EndIf
  EndProcedure
  
  Procedure MenuItemPackNew()
    windowPack::show(window)
  EndProcedure
  
  Procedure MenuItemSelectAll()
    Protected i
    If GetActiveGadget() = gadget("modList")
      For i = 0 To CountGadgetItems(gadget("modList"))-1
        SetGadgetItemState(gadget("modList"), i, #PB_ListIcon_Selected)
      Next
    EndIf
  EndProcedure
  
  Procedure MenuItemPackOpen()
    windowPack::show(window)
    windowPack::packOpen()
  EndProcedure
  
  ;- GADGETS
  
  ;- --------------------
  ;- nav
  
  Procedure hideAllContainer()
    HideGadget(Gadget("containerMods"), #True)
    HideGadget(gadget("containerMaps"), #True)
    HideGadget(gadget("containerOnline"), #True)
    HideGadget(gadget("containerBackups"), #True)
    HideGadget(gadget("containerSaves"), #True)
    
    SetGadgetState(gadget("btnMods"), 0)
    SetGadgetState(gadget("btnMaps"), 0)
    SetGadgetState(gadget("btnOnline"), 0)
    SetGadgetState(gadget("btnBackups"), 0)
    SetGadgetState(gadget("btnSaves"), 0)
    SetGadgetState(gadget("btnSettings"), 0)
  EndProcedure
  
  Procedure navBtnMods()
    deb("windowMain:: navBtnMods()")
    hideAllContainer()
    HideGadget(gadget("containerMods"), #False)
    SetGadgetState(gadget("btnMods"), 1)
    SetActiveGadget(gadget("modList"))
    currentTab = #TabMods
  EndProcedure
  
  Procedure navBtnMaps()
    deb("windowMain:: navBtnMods()")
    hideAllContainer()
    HideGadget(gadget("containerMaps"), #False)
    SetGadgetState(gadget("btnMaps"), 1)
    currentTab = #TabMaps
  EndProcedure
  
  Procedure navBtnOnline()
    deb("windowMain:: navBtnOnline()")
    hideAllContainer()
    HideGadget(gadget("containerOnline"), #False)
    SetGadgetState(gadget("btnOnline"), 1)
    currentTab = #TabOnline
  EndProcedure
  
  Procedure navBtnBackups()
    deb("windowMain:: navBtnBackups()")
    hideAllContainer()
    HideGadget(gadget("containerBackups"), #False)
    SetGadgetState(gadget("btnBackups"), 1)
    currentTab = #TabBackup
  EndProcedure
  
  Procedure navBtnSaves()
    deb("windowMain:: navBtnSaves()")
    hideAllContainer()
    HideGadget(gadget("containerSaves"), #False)
    SetGadgetState(gadget("btnSaves"), 1)
    currentTab = #TabSaves
  EndProcedure
  
  Procedure navBtnSettings()
    deb("windowMain:: navBtnSaves()")
    windowSettings::show()
    SetGadgetState(gadget("btnSettings"), 0)
    
    Select currentTab
      Case #TabMods
        windowSettings::showTab(windowSettings::#TabGeneral)
      Case #TabBackup
        windowSettings::showTab(windowSettings::#TabBackup)
      Case #TabOnline
        windowSettings::showTab(windowSettings::#TabRepository)
    EndSelect
  EndProcedure
  
  Procedure navBtnHelp()
    deb("windowMain:: navBtnHelp()")
    misc::openLink("https://www.transportfevermods.com/tpfmm/help.html")
    SetGadgetState(gadget("btnHelp"), 0)
  EndProcedure
  
  ;- --------------------
  ;- mod tab
  
  Procedure modAddNewMod()
    deb("windowMain:: modAddNewMod()")
    Protected file$
    If FileSize(settings::getString("", "path")) <> -2
      ProcedureReturn #False
    EndIf
    Protected types$
    types$ = "*.zip;*.rar;*.7z;*.gz;*.tar"
    
    file$ = OpenFileRequester(_("management_select_mod"), settings::getString("", "last_file"), _("management_files_archive")+"|"+types$+"|"+_("management_files_all")+"|*.*", 0, #PB_Requester_MultiSelection)
    
    If file$
      settings::setString("","last_file", file$)
    EndIf
    
    While file$
      If FileSize(file$) > 0
        mods::install(file$)
      EndIf
      file$ = NextSelectedFileName()
    Wend
  EndProcedure
  
  Procedure modUninstall() ; Uninstall selected mods (delete from HDD)
    deb("windowMain:: modUninstall()")
    Protected *mod.mods::LocalMod
    Protected NewList *items.CanvasList::CanvasListItem()
    Protected count, result
    Protected name$
    
    If *modList\GetAllSelectedItems(*items())
      ForEach *items()
        *mod = *items()\GetUserData()
        If *mod\canUninstall()
          count + 1
          name$ = *mod\getName()
        EndIf
      Next
    EndIf
    
    If count > 0
      If count = 1
        result = MessageRequester(_("main_uninstall"), _("management_uninstall1", "name="+name$), #PB_MessageRequester_YesNo|#PB_MessageRequester_Warning)
      Else
        result = MessageRequester(_("main_uninstall_pl"), _("management_uninstall2", "count="+count), #PB_MessageRequester_YesNo|#PB_MessageRequester_Warning)
      EndIf
      
      If result = #PB_MessageRequester_Yes
        ForEach *items()
          *mod = *items()\GetUserData()
          If *mod\canUninstall()
            mods::uninstall(*mod\getID())
          EndIf
        Next
      EndIf
    EndIf
  EndProcedure
  
  Procedure modUpdate()
    deb("windowMain:: modUpdate()")
    Protected *mod.mods::LocalMod
    Protected NewList *items.CanvasList::CanvasListItem()
    
    If *modList\GetAllSelectedItems(*items())
      ForEach *items()
        *mod = *items()\GetUserData()
        mods::update(*mod\getID())
      Next
    EndIf
  EndProcedure
  
  Procedure modUpdateAll()
    deb("windowMain:: modUpdateAll()")
    Protected *mod.mods::LocalMod
    Protected NewList*items.CanvasList::CanvasListItem()
    
    If *modList\GetAllItems(*items())
      ForEach *items()
        *mod = *items()\GetUserData()
        If *mod\isUpdateAvailable()
          mods::update(*mod\getID())
        EndIf
      Next
    EndIf
    
  EndProcedure
  
  Procedure modBackup()
    deb("windowMain:: modBackup()")
    Protected *mod.mods::LocalMod
    Protected NewList *items.CanvasList::CanvasListItem()
    
    If *modList\GetAllSelectedItems(*items())
      ForEach *items()
        *mod = *items()\GetUserData()
        If *mod\canBackup()
          mods::backup(*mod\getID())
        EndIf
      Next
    EndIf
  EndProcedure
  
  ;- mod sort functions
  
  Procedure compModName(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *mod1.mods::LocalMod = *item1\GetUserData()
    Protected *mod2.mods::LocalMod = *item2\GetUserData()
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(LCase(*mod1\getName()) <= LCase(*mod2\getName()))
    Else
      ProcedureReturn Bool(LCase(*mod1\getName()) > LCase(*mod2\getName()))
    EndIf
  EndProcedure
  
  Procedure compModAuthor(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *mod1.mods::LocalMod = *item1\GetUserData()
    Protected *mod2.mods::LocalMod = *item2\GetUserData()
    
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(LCase(*mod1\getAuthorsString()) <= LCase(*mod2\getAuthorsString()))
    Else
      ProcedureReturn Bool(LCase(*mod1\getAuthorsString()) > LCase(*mod2\getAuthorsString()))
    EndIf
  EndProcedure
  
  Procedure compModInstall(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *mod1.mods::LocalMod = *item1\GetUserData()
    Protected *mod2.mods::LocalMod = *item2\GetUserData()
    
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(*mod1\getInstallDate() <= *mod2\getInstallDate())
    Else
      ProcedureReturn Bool(*mod1\getInstallDate() > *mod2\getInstallDate())
    EndIf
  EndProcedure
  
  Procedure compModSize(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *mod1.mods::LocalMod = *item1\GetUserData()
    Protected *mod2.mods::LocalMod = *item2\GetUserData()
    
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(*mod1\getSize() <= *mod2\getSize())
    Else
      ProcedureReturn Bool(*mod1\getSize() > *mod2\getSize())
    EndIf
  EndProcedure
  
  Procedure compModID(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *mod1.mods::LocalMod = *item1\GetUserData()
    Protected *mod2.mods::LocalMod = *item2\GetUserData()
    
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(*mod1\getID() <= *mod2\getID())
    Else
      ProcedureReturn Bool(*mod1\getID() > *mod2\getID())
    EndIf
  EndProcedure
  
  ;- mod filter dialog
  
  Procedure modFilterCallback(*item.CanvasList::CanvasListItem, options)
    ; return true if this mod shall be displayed, false if hidden
    Protected *mod.mods::LocalMod = *item\GetUserData()
    Protected string$, s$, i, n
    
    ; check decrepated mods
    If *mod\isDeprecated() And Not GetGadgetState(DialogGadget(modfilter\dialog, "modFilterDeprecated"))
      ProcedureReturn #False
    EndIf
    
    ; check vanilla mod
    If *mod\isVanilla() And Not GetGadgetState(DialogGadget(modfilter\dialog, "modFilterVanilla"))
      ProcedureReturn #False
    EndIf
    
    ; check hidden mod
    If *mod\isHidden() And Not GetGadgetState(DialogGadget(modfilter\dialog, "modFilterHidden"))
      ProcedureReturn #False
    EndIf
    
    ; check workshop mod
    If *mod\isWorkshop() And Not GetGadgetState(DialogGadget(modfilter\dialog, "modFilterWorkshop"))
      ProcedureReturn #False
    EndIf
    
    ; check staging area mod
    If *mod\isStagingArea() And Not GetGadgetState(DialogGadget(modfilter\dialog, "modFilterStaging"))
      ProcedureReturn #False
    EndIf
    
    ; check for search string
    string$ = GetGadgetText(DialogGadget(modfilter\dialog, "modFilterString"))
    If string$
      ; split string in parts
      n = CountString(string$, " ")
      For i = 1 To n+1
        s$ = StringField(string$, i, " ")
        If s$
          ; special search strings
          If LCase(s$) = "!settings"
            If *mod\hasSettings()
              Continue
            Else
              ProcedureReturn #False
            EndIf
          EndIf
          
          If LCase(s$) = "!update"
            If *mod\isUpdateAvailable()
              Continue
            Else
              ProcedureReturn #False
            EndIf
          EndIf
          
          ; check if s$ is found in any of the information of the mod
          If Not FindString(*mod\getName(), s$, 1, #PB_String_NoCase)
            If Not FindString(*mod\getAuthorsString(), s$, 1, #PB_String_NoCase)
              ; search string was NOT found in this mod
              ProcedureReturn #False
            EndIf
          EndIf
          
        EndIf
      Next
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure modFilterChange()
;     deb("windowMain:: modFilterChange()")
    ; save current filter to settings
    settings::setString("modFilter", "filter",    GetGadgetText(DialogGadget(modfilter\dialog, "modFilterString")))
    settings::setInteger("modFilter", "deprecated", GetGadgetState(DialogGadget(modfilter\dialog, "modFilterDeprecated")))
    settings::setInteger("modFilter", "vanilla",  GetGadgetState(DialogGadget(modfilter\dialog, "modFilterVanilla")))
    settings::setInteger("modFilter", "hidden",   GetGadgetState(DialogGadget(modfilter\dialog, "modFilterHidden")))
    settings::setInteger("modFilter", "workshop", GetGadgetState(DialogGadget(modfilter\dialog, "modFilterWorkshop")))
    settings::setInteger("modFilter", "staging",  GetGadgetState(DialogGadget(modfilter\dialog, "modFilterStaging")))
    
    ; opt 1) gather the "filter options" here (read gadget state and save to some filter flag variable"
    ; opt 2) trigger filtering, and let the filter callback read the gadget states.
    ; use opt 2:
    *modList\FilterItems(@modFilterCallback(), 0, #True)
  EndProcedure
  
  Procedure modFilterReset()
    deb("windowMain:: modResetFilterMods()")
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterString"), "")
    SetActiveGadget(DialogGadget(modFilter\dialog, "modFilterString"))
    modFilterChange()
  EndProcedure
  
  ;- mod sort dialog
  
  Procedure modSortChange()
;     deb("windowMain:: modSortChange()")
    ; apply sorting to CanvasList
    Protected *comp, mode, options
    
    mode = GetGadgetState(DialogGadget(modSort\dialog, "sortBox"))
    settings::setInteger("modSort", "mode", mode)
    
    ; get corresponding sorting function
    Select mode
      Case 1
        *comp = @compModAuthor()
        options = #PB_Sort_Ascending
      Case 2
        *comp = @compModInstall()
        options = #PB_Sort_Descending
      Case 3
        *comp = @compModSize()
        options = #PB_Sort_Ascending
      Case 4
        *comp = @compModID()
        options = #PB_Sort_Ascending
      Default
        *comp = @compModName()
        options = #PB_Sort_Ascending
    EndSelect
    
    ; Sort CanvasList and make persistent sort (gadget will be keept sorted automatically)
    *modList\SortItems(CanvasList::#SortByUser, *comp, options, #True)
    
    ; close the mod sort tool window
    PostEvent(#PB_Event_CloseWindow, modSort\window, #Null)
  EndProcedure
  
  ;- mod item icon callbacks
  
  Procedure modIconInfo(*item.CanvasList::CanvasListItem)
    modInformation::modInfoShow(*item\GetUserData(), WindowID(window))
  EndProcedure
  
  Procedure modIconFolder(*item.CanvasList::CanvasListItem)
    Protected *mod.mods::LocalMod = *item\GetUserData()
    misc::openLink(mods::getModFolder(*mod\getID()))
  EndProcedure
  
  Procedure modIconSettings(*item.CanvasList::CanvasListItem)
    modSettings::show(*item\GetUserData(), WindowID(window))
  EndProcedure
  
  Procedure modIconUpdate(*item.CanvasList::CanvasListItem)
    Protected *mod.mods::LocalMod = *item\GetUserData()
    mods::update(*mod\getID())
  EndProcedure
  
  Procedure modIconWebsite(*item.CanvasList::CanvasListItem)
    Protected *mod.mods::LocalMod = *item\GetUserData()
    Protected website$ = *mod\getWebsite()
    If website$
      misc::openLink(website$)
    EndIf
  EndProcedure
  
  Procedure modIconBackup(*item.CanvasList::CanvasListItem)
    Protected *mod.mods::LocalMod = *item\GetUserData()
    mods::backup(*mod\getID())
  EndProcedure
  
  Procedure modIconUninstall(*item.CanvasList::CanvasListItem)
    Protected *mod.mods::LocalMod = *item\GetUserData()
    If MessageRequester(_("main_uninstall"), _("management_uninstall1", "name="+*mod\getName()), #PB_MessageRequester_YesNo|#PB_MessageRequester_Warning) = #PB_MessageRequester_Yes
      mods::uninstall(*mod\getID())
    EndIf
  EndProcedure
  
  ;- mod callbacks
  
  Procedure modItemSetup(*item.CanvasList::CanvasListItem, *mod.mods::LocalMod = #Null)
    Protected.b repoMod, updateAvailable
    
    If *mod = #Null
      *mod = *item\GetUserData()
      If *mod = #Null
        deb("windowMain:: no mod information for item "+*item)
        ProcedureReturn #False
      EndIf
    EndIf
    
    If *mod\getRepoMod()
      repoMod = #True
      If *mod\isUpdateAvailable()
        updateAvailable = #True
      EndIf
    EndIf
    
    ; set image
    *item\SetImage(*mod\getPreviewImage())
    
    ; add buttons (callbacks)
    *item\ClearButtons()
    *item\AddButton(@modIconInfo(), images::Images("itemBtnInfo"), images::images("itemBtnInfoHover"), _("hint_mod_information"))
    *item\AddButton(@modIconFolder(), images::Images("itemBtnFolder"), images::images("itemBtnFolderHover"), _("hint_mod_open_folder"))
    If *mod\hasSettings()
      *item\AddButton(@modIconSettings(), images::Images("itemBtnSettings"), images::images("itemBtnSettingsHover"), _("hint_mod_settings"))
    Else
      *item\AddButton(#Null, images::images("itemBtnSettingsDisabled"))
    EndIf
    If repoMod And updateAvailable
      *item\AddButton(@modIconUpdate(), images::Images("itemBtnUpdate"), images::images("itemBtnUpdateHover"), _("hint_mod_update"))
    Else
      *item\AddButton(#Null, images::images("itemBtnUpdateDisabled"))
    EndIf
    *item\AddButton(@modIconWebsite(),  images::Images("itemBtnWebsite"), images::images("itemBtnWebsiteHover"), _("hint_mod_website"))
    *item\AddButton(@modIconBackup(),   images::Images("itemBtnBackup"),  images::images("itemBtnBackupHover"), _("hint_mod_backup"))
    If *mod\canUninstall()
      *item\AddButton(@modIconUninstall(), images::Images("itemBtnDelete"), images::images("itemBtnDeleteHover"), _("hint_mod_uninstall"))
    Else
      *item\AddButton(#Null, images::images("itemBtnDeleteDisabled"))
    EndIf
    
    
    ; icons
    *item\ClearIcons()
    
    ; location icon
    If *mod\isVanilla()
      *item\AddIcon(images::images("itemIcon_vanilla"), _("hint_mod_source_vanilla"))
    ElseIf *mod\isWorkshop()
      *item\AddIcon(images::images("itemIcon_workshop"), _("hint_mod_source_workshop"))
    ElseIf *mod\isStagingArea()
      ; todo staging area mod icon?
      *item\AddIcon(images::images("itemIcon_mod"), _("hint_mod_source_staging"))
    Else
      *item\AddIcon(images::images("itemIcon_mod"), _("hint_mod_source_manual"))
    EndIf
    
    ; update icon
    If repoMod
      If updateAvailable
        *item\AddIcon(images::images("itemIcon_updateAvailable"), _("hint_mod_update_available"))
      Else
        *item\AddIcon(images::images("itemIcon_up2date"), _("hint_mod_up2date"))
      EndIf
    Else
      *item\AddIcon(images::images("itemIcon_blank"))
    EndIf
    
    ; settings icon
    If *mod\hasSettings()
      *item\AddIcon(images::images("itemIcon_settings"), _("hint_mod_has_settings"))
    Else
      *item\AddIcon(images::images("itemIcon_blank"))
    EndIf
    
    ; deprecated / error
    If *mod\isDeprecated()
      *item\AddIcon(images::images("itemIcon_deprecated"), _("hint_mod_deprecated"))
    EndIf
    If *mod\isLuaError()
      *item\AddIcon(images::images("itemIcon_error"), _("hint_mod_lua_error"))
    EndIf
    
    *modList\redraw() ; after all icons and buttons are added, redraw the gadget
    ProcedureReturn #True
  EndProcedure
  
  Procedure modCallbackNewMod(*mod.mods::LocalMod)
    Protected *item.CanvasList::CanvasListItem
    
    CompilerIf #PB_Compiler_Debugger
      *item = *modList\AddItem(*mod\getName()+#LF$+
                               _("generic_by")+" "+*mod\getAuthorsString()+#LF$+
                               "ID: "+*mod\getID()+", Folder: "+*mod\getFoldername()+", "+
                               FormatDate(_("main_install_date"), *mod\getInstallDate()), *mod)
    CompilerElse
      *item = *modList\AddItem(*mod\getName()+#LF$+
                               _("generic_by")+" "+*mod\getAuthorsString()+#LF$+
                               FormatDate(_("main_install_date"), *mod\getInstallDate()), *mod)
    CompilerEndIf
    
    modItemSetup(*item, *mod)
  EndProcedure
  
  Procedure modCallbackRemoveMod(*mod)
    Protected NewList *items.CanvasList::CanvasListItem()
    
    If *modList\GetAllItems(*items())
      ForEach *items()
        If *mod = *items()\GetUserData()
          *modList\RemoveItem(*items())
          Break
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure modCallbackStopDraw(stop)
    *modList\SetAttribute(CanvasList::#AttributePauseDraw, stop)
    *backupList\SetAttribute(CanvasList::#AttributePauseDraw, stop)
  EndProcedure
  
  Procedure modEventProgress()
    Protected percent, *buffer
    
    percent = EventType()
    If percent = -1
      HideGadget(gadget("progressModBar"), #True)
    Else
      HideGadget(gadget("progressModBar"), #False)
      SetGadgetState(gadget("progressModBar"), percent)
    EndIf
    
    *buffer = EventData()
    If *buffer
;       Debug "########## peek from "+*buffer+" "+PeekS(*buffer)
      SetGadgetText(gadget("progressModText"), PeekS(*buffer))
      FreeMemory(*buffer)
      ; sometimes, this event is called twice and tries to free memory that is already freed!
      ; only occurs when using EventWindow and EventGadget for data transfer...
    EndIf
  EndProcedure
  
  ;- mod other
  
  Procedure modListEvent()
    Select EventType()
      Case #PB_EventType_RightClick
;         DisplayPopupMenu(MenuLibrary, WindowID(window))
      Case #PB_EventType_DragStart
;         DragPrivate(main::#DRAG_MOD)
    EndSelect
  EndProcedure
  
  Procedure modListItemEvent(*item, event)
    Select event
      Case #PB_EventType_LeftDoubleClick
        If *item
          modIconInfo(*item)
        EndIf
        
      Case #PB_EventType_Change
        ; different item selected
        updateModButtons()
    EndSelect
    
  EndProcedure
  
  Procedure modListRefreshStatus()
    ; trigger mods to refresh (check online status)
    Protected NewList *items.CanvasList::CanvasListItem()
    *modList\GetAllItems(*items())
    *modList\SetAttribute(CanvasList::#AttributePauseDraw, #True)
    ForEach *items()
      modItemSetup(*items())
    Next
    *modList\SetAttribute(CanvasList::#AttributePauseDraw, #False)
  EndProcedure
  
  Procedure modAddToPack()
    windowPack::show(window)
    windowPack::addSelectedMods()
  EndProcedure
  
  Procedure modShareList(List *mods.mods::LocalMod())
    deb("mainWindow:: modShareList")
    Protected file$, file
    Protected i, im, *buffer
    Protected json, json$
    Protected html$
    
    If Not ListSize(*mods())
      deb("mainWindow:: no mods in share list")
      ProcedureReturn #False
    EndIf
    
    Protected Dim shareMods.shareMods(ListSize(*mods())-1)
    
    Debug "export "+ListSize(*mods())+" mods"
    
    ; get filename
    file$ = SaveFileRequester(_("management_export_list"), settings::getString("export", "last"), "HTML|*.html", 0)
    If file$ = ""
      ProcedureReturn #False
    EndIf
    
    If LCase(GetExtensionPart(file$)) <> "html"
      file$ = file$ + ".html"
    EndIf
    settings::setString("export", "last", file$)
    
    If FileSize(file$) > 0
      If Not MessageRequester(_("management_export_list"), _("management_overwrite_file"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; prepare export
    i = 0
    ForEach *mods()
      shareMods(i)\foldername$  = *mods()\getFoldername()
      shareMods(i)\name$        = *mods()\getName()
      shareMods(i)\author$      = *mods()\getAuthorsString()
      shareMods(i)\version$     = *mods()\getVersion()
      shareMods(i)\website$     = *mods()\getWebsite()
      shareMods(i)\download$    = *mods()\getDownloadLink()
      If shareMods(i)\download$
        shareMods(i)\download$  = "tpfmm://download/"+shareMods(i)\download$
      EndIf
      
      If *mods()\isVanilla()
        shareMods(i)\source$    = "vanilla"
      ElseIf *mods()\isWorkshop()
        shareMods(i)\source$    = "workshop"
      ElseIf *mods()\isStagingArea()
        shareMods(i)\source$    = ""
      Else
        shareMods(i)\source$    = "manual"
      EndIf
      
      im = *mods()\getPreviewImage() ; resized and centered image of size 320x180
      If im
;         im = CopyImage(im, #PB_Any) : ResizeImage(im, 240, 135) ; create copy and resize
        *buffer = EncodeImage(im, #PB_ImagePlugin_JPEG, 8, 24)
        If *buffer
          Debug "encoded preview image ("+ImageWidth(im)+"x"+ImageHeight(im)+") as JPEG with "+StrD(MemorySize(*buffer)/1024, 2)+" kiB"
          shareMods(i)\imageB64$ = "data:image/jpeg;base64,"+Base64Encoder(*buffer, MemorySize(*buffer))
          FreeMemory(*buffer)
        Else
          Debug "could not encode image"
        EndIf
;         FreeImage(im)
      Else
        Debug "no preview image number"
      EndIf
      
      i + 1
    Next
    
    json = CreateJSON(#PB_Any)
    InsertJSONArray(JSONValue(json), shareMods())
    json$ = ComposeJSON(json, #PB_JSON_PrettyPrint)
    FreeJSON(json)
    
    html$ = modShareHTML$
    html$ = ReplaceString(html$, "{language}", locale::getCurrentLocale(), #PB_String_CaseSensitive, 1, 1)
    html$ = ReplaceString(html$, "{title}", _("share_title"), #PB_String_CaseSensitive, 1, 1)
    html$ = ReplaceString(html$, "{copyright}", _("share_copyright"), #PB_String_CaseSensitive, 1, 1)
    html$ = ReplaceString(html$, "{date}", FormatDate("%yyyy-%mm-%dd", Date()), #PB_String_CaseSensitive, 1, 1)
    html$ = ReplaceString(html$, "{TPFMM-version}", main::#VERSION$, #PB_String_CaseSensitive, 1, 1)
    html$ = ReplaceString(html$, "{mod-list}", json$, #PB_String_CaseSensitive, 1, 1)
    
    ; write file
    file = CreateFile(#PB_Any, file$)
    If file
      WriteString(file, html$, #PB_UTF8)
      CloseFile(file)
      deb("windowMain:: finished exporting mod list")
      misc::openLink(file$)
      ProcedureReturn #True
    Else
      deb("windowMain:: could not create file "+file$)
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure modShareSelected()
    Protected NewList *mods.mods::LocalMod()
    Protected NewList *items.CanvasList::CanvasListItem()
    
    If *modList\GetAllSelectedItems(*items())
      ForEach *items()
        AddElement(*mods())
        *mods() = *items()\GetUserData()
      Next
    EndIf
    
    modShareList(*mods())
  EndProcedure
  
  Procedure modShareFiltered()
    Protected NewList *mods.mods::LocalMod()
    Protected NewList *items.CanvasList::CanvasListItem()
    
    If *modList\GetAllVisibleItems(*items())
      ForEach *items()
        AddElement(*mods())
        *mods() = *items()\GetUserData()
      Next
    EndIf
    
    modShareList(*mods())
  EndProcedure
  
  Procedure modShareAll()
    Protected NewList *mods.mods::LocalMod()
    Protected NewList *items.CanvasList::CanvasListItem()
    
    If *modList\GetAllItems(*items())
      ForEach *items()
        AddElement(*mods())
        *mods() = *items()\GetUserData()
      Next
    EndIf
    
    modShareList(*mods())
  EndProcedure
  
  Procedure modShareShowPopup()
    ;TODO activate/deactivate "selected" menu entry based on items being selected
    Protected NewList *items.CanvasList::CanvasListItem()
    If *modList\GetAllSelectedItems(*items())
      DisableMenuItem(menuShare, #MenuItem_ShareSelected, #False)
    Else
      DisableMenuItem(menuShare, #MenuItem_ShareSelected, #True)
    EndIf
    DisplayPopupMenu(menuShare, WindowID(window))
  EndProcedure
  
  Procedure modShowDownloadFolder()
    If settings::getString("", "path")
      misc::CreateDirectoryAll(settings::getString("", "path")+"TPFMM/download/")
      misc::openLink(settings::getString("", "path")+"TPFMM/download/")
    EndIf
  EndProcedure
  
  ;- --------------------
  ;- repo tab
  
  ;- repo sort functions
  
  Procedure compRepoName(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *mod1.repository::RepositoryMod = *item1\GetUserData()
    Protected *mod2.repository::RepositoryMod = *item2\GetUserData()
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(LCase(*mod1\getName()) <= LCase(*mod2\getName()))
    Else
      ProcedureReturn Bool(LCase(*mod1\getName()) > LCase(*mod2\getName()))
    EndIf
  EndProcedure
  
  Procedure compRepoDate(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *mod1.repository::RepositoryMod = *item1\GetUserData()
    Protected *mod2.repository::RepositoryMod = *item2\GetUserData()
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(*mod1\getTimeChanged() <= *mod2\getTimeChanged())
    Else
      ProcedureReturn Bool(*mod1\getTimeChanged() > *mod2\getTimeChanged())
    EndIf
  EndProcedure
  
  ;- repo filter dialog
  
  Procedure repoFilterCallback(*item.CanvasList::CanvasListItem, options)
    ; return true if this mod shall be displayed, false if hidden
    Protected *mod.repository::RepositoryMod = *item\GetUserData()
    Protected string$, s$, i, n
    Protected date
    
    ; TODO repoFilterCallback() check source
    date = GetGadgetState(DialogGadget(repoFilter\dialog, "filterDate"))
    
    If date
      ; set date to 00:00 of the day
      date = Date(Year(date), Month(date), Day(date), 0, 0, 0)
      If *mod\getTimeChanged() < date
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; check for search string
    string$ = GetGadgetText(DialogGadget(repoFilter\dialog, "filterString"))
    If string$
      ; split string in parts
      n = CountString(string$, " ")
      For i = 1 To n+1
        s$ = StringField(string$, i, " ")
        If s$
          ; check if s$ is found in any of the information of the mod
          If Not FindString(*mod\getName(), s$, 1, #PB_String_NoCase)
            If Not FindString(*mod\getAuthor(), s$, 1, #PB_String_NoCase)
              If Not FindString(*mod\getSource(), s$, 1, #PB_String_NoCase)
                ; search string was NOT found in this mod
                
                Protected NewList *files.repository::RepositoryFile()
                Protected found
                found = #False
                If *mod\getFiles(*files())
                  ForEach *files()
                    If FindString(*files()\getFolderName(), s$, 1, #PB_String_NoCase)
                      found = #True
                      Break
                    EndIf
                  Next
                  ClearList(*files())
                EndIf
                
                ProcedureReturn found
              EndIf
            EndIf
          EndIf
        EndIf
      Next
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure repoFilterChange()
    ; save current filter to settings
    ; TODO repoFilterChange() save current filter to settings?
    
    settings::setString("repoFilter",   "filter", GetGadgetText(DialogGadget(repoFilter\dialog, "filterString")))
    settings::setInteger("repoFilter",  "date",   GetGadgetState(DialogGadget(repoFilter\dialog, "filterDate")))
    ; opt 1) gather the "filter options" here: read gadget state and save to some filter flag variable
    ; opt 2) trigger filtering, and let the filter callback read the gadget states.
    ; use opt 2: (window must stay open)
    *repoList\FilterItems(@repoFilterCallback(), 0, #True)
  EndProcedure
  
  Procedure repoFilterReset()
    SetGadgetText(DialogGadget(repofilter\dialog, "filterString"), "")
    SetActiveGadget(DialogGadget(repofilter\dialog, "filterString"))
    repoFilterChange()
  EndProcedure
  
  ;- repo sort dialog
  
  Procedure repoSortChange()
    ; apply sorting to CanvasList
    Protected *comp, mode, options
    
    mode = GetGadgetState(DialogGadget(repoSort\dialog, "sortBox"))
    settings::setInteger("repoSort", "mode", mode)
    
    ; get corresponding sorting function
    Select mode
      Case 1
        *comp = @compRepoName()
        options = #PB_Sort_Ascending
      Default
        *comp = @compRepoDate()
        options = #PB_Sort_Descending
    EndSelect
    
    ; Sort CanvasList and make persistent sort (gadget will be keept sorted automatically)
    *repoList\SortItems(CanvasList::#SortByUser, *comp, options, #True)
    
    ; close the mod sort tool window
    PostEvent(#PB_Event_CloseWindow, repoSort\window, #Null)
  EndProcedure
  
  ;- repo events
  
  Procedure repoItemWebsite(*item.CanvasList::CanvasListItem)
    Protected *mod.repository::RepositoryMod
    Protected url$
    If *item
      *mod = *item\GetUserData()
      If *mod
        url$ = *mod\getWebsite()
        If url$
          misc::openLink(url$)
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  Procedure repoItemDownload(*item.CanvasList::CanvasListItem)
    Protected *mod.repository::RepositoryMod
    If *item
      *mod = *item\GetUserData()
      If *mod
        *mod\download()
      EndIf
    EndIf
  EndProcedure
  
  Procedure repoListItemEvent(*item, event)
    Select event
      Case #PB_EventType_LeftDoubleClick
        If *item
          repoItemWebsite(*item)
        EndIf
        
      Case #PB_EventType_Change
        ; different item selected
        updateRepoButtons()
    EndSelect
    
  EndProcedure
  
  Procedure repoWebsite()
    Protected *item.CanvasList::CanvasListItem
    
    *item = *repoList\GetSelectedItem()
    repoItemWebsite(*item)
  EndProcedure
  
  Procedure repoDownload()
    Protected NewList *items.CanvasList::CanvasListItem()
    
    If *repoList\GetAllSelectedItems(*items())
      ForEach *items()
        repoItemDownload(*items())
      Next
    EndIf
  EndProcedure
  
  Procedure repoRefresh()
    DisableGadget(gadget("repoRefresh"), #True)
    repository::refreshRepositories()
  EndProcedure
  
  Procedure repoRefreshFinished()
    DisableGadget(gadget("repoRefresh"), #False)
  EndProcedure
  
  ;- repo callbacks
  
  Procedure repoItemSetup(*item.CanvasList::CanvasListItem, *mod.Repository::RepositoryMod = #Null)
    Protected file$, image, installed
    Protected NewList *files.repository::RepositoryFile()
    
    If *mod = #Null
      *mod = *item\GetUserData()
      If *mod = #Null
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; load cached thumbnail images (must free images in windowMain:: manually when list is cleared)
    file$ = *mod\getThumbnailFile()
    If file$
      If FileSize(file$) > 0
        image = LoadImage(#PB_Any, file$)
        If image
          *mod\setThumbnailImage(image)
          *item\SetImage(image)
        EndIf
      EndIf
    EndIf
    
    ; icons
    If IsImage(images::images("itemIcon_"+*mod\getSource()))
      Protected repoInfo.repository::RepositoryInformation
      repository::GetRepositoryInformation(*mod\GetRepositoryURL(), @repoInfo)
      *item\AddIcon(images::images("itemIcon_"+*mod\getSource()), _("hint_repo_source","repo_name="+repoInfo\name$))
    Else
      *item\AddIcon(images::images("itemIcon_blank"))
    EndIf
    installed = #False
    If *mod\getFiles(*files()) ; is mod installed? ... mutliple files per mod possible.. check for each file
      ForEach *files()
        If mods::isInstalled(*files()\getFolderName())
          installed = #True
          Break
        EndIf
      Next
    EndIf
    If installed
      *item\AddIcon(images::images("itemIcon_installed"), _("hint_repo_installed"))
    Else
      *item\AddIcon(images::images("itemIcon_blank"))
    EndIf
    
    ; buttons
    If *mod\canDownload()
      *item\AddButton(@repoItemDownload(), images::images("itemBtnDownload"), images::images("itemBtnDownloadHover"), _("hint_repo_download"))
    EndIf
    *item\AddButton(@repoItemWebsite(), images::images("itemBtnWebsite"), images::images("itemBtnWebsiteHover"), _("hint_repo_website"))
    
  EndProcedure
  
  Procedure repoCallbackAddMods(List *mods.repository::RepositoryMod())
    Protected *mod.repository::RepositoryMod,
              *item.CanvasList::CanvasListItem
    
    ; this is called from the repository thread -> send events to main event loop
    ; posting events instead of directly adding them freezes the window while the function is executed but there is less possibility for IMAs due to race conditions
    
    *repoList\SetAttribute(canvasList::#AttributePauseDraw, #True)
    ForEach *mods()
      *mod = *mods()
      *item = *repoList\AddItem(*mod\getName()+" (v"+*mod\getVersion()+")"+#LF$+*mod\getAuthor()+#LF$+FormatDate("Last update on %yyyy/%mm/%dd",*mod\getTimeChanged()), *mod)
      repoItemSetup(*item, *mod)
    Next
    *repoList\SetAttribute(canvasList::#AttributePauseDraw, #False)
    
    modListRefreshStatus()
;     progressRepo(#Progress_Hide, "finished loading repo")
  EndProcedure
  
  Procedure repoCallbackClearList()
    ; called when repos are cleared
    Protected NewList *items.canvasList::CanvasListItem()
    Protected im
    
    ; free images, they are loaded by windowMain:: and not controlled by either the canvasList or the repository module
    *repoList\SetAttribute(canvasList::#AttributePauseDraw, #True)
    *repoList\GetAllItems(*items())
    ForEach *items()
      im = *items()\GetImage()
      *items()\SetImage(#Null)
      If im And IsImage(im)
        FreeImage(im)
      EndIf
    Next
    *repoList\SetAttribute(canvasList::#AttributePauseDraw, #False)
    
    ; free all items in list
    *repoList\ClearItems()
    
    ; refresh mod list
    modListRefreshStatus()
  EndProcedure
  
  Procedure repoCallbackRefreshFinishedEvent()
    modListRefreshStatus()
    SetGadgetText(gadget("progressRepoText"), "Repsitory refresh finished")
  EndProcedure
  
  Procedure repoCallbackRefreshFinished()
    ; called when all repositories are loaded
    ; TODO repoCallbackRefreshFinished() - update mod list (add update information to mods)
    ; send event to main thread
    PostEvent(#EventRepoRefreshFinished, window, #Null)
    
    ; inform settings window to refresh repo list
    PostEvent(windowSettings::#EventRefreshRepoList, windowSettings::window, #Null)
  EndProcedure
  
  Procedure repoCallbackThumbnail(image, *userdata)
    Debug "repoCallbackThumbnail("+image+", "+*userdata+")"
    ;TODO: repository may download image, but move image load() to windowMain:: ?
    Protected *item.CanvasList::CanvasListItem
    If image And *userdata
      *item = *userdata
      *item\SetImage(image)
    EndIf
  EndProcedure
  
  Procedure repoEventItemVisible(*item.CanvasList::CanvasListItem, event)
    ; callback triggered when item gets visible
    ; load image for this item now
    
    Protected *mod.repository::RepositoryMod
    If Not *item\GetImage()
      *mod = *item\GetUserData()
      *mod\getThumbnailAsync(@repoCallbackThumbnail(), *item)
    EndIf
  EndProcedure
  
  Procedure repoEventProgress() ; progress bar
    Protected percent, *buffer
    
    percent = EventType()
    If percent = -1
      HideGadget(gadget("progressRepoBar"), #True)
    Else
      HideGadget(gadget("progressRepoBar"), #False)
      SetGadgetState(gadget("progressRepoBar"), percent)
    EndIf
    
    *buffer = EventData()
    If *buffer
;       Debug "########## peek from "+*buffer+" "+PeekS(*buffer)
      SetGadgetText(gadget("progressRepoText"), PeekS(*buffer))
      FreeMemory(*buffer)
      ; sometimes, this event is called twice and tries to free memory that is already freed!
      ; only occurs when using EventWindow and EventGadget for data transfer...
    EndIf
  EndProcedure
  
  ;- repo download file selection window...
  
  Procedure repoSelectFilesClose()
    Protected *dialog.fileSelectionDialog
    *dialog = GetWindowData(EventWindow())
    If *dialog
;       DisableWindow(window, #False)
      SetActiveWindow(window)
      CloseWindow(DialogWindow(*dialog\dialog))
      FreeDialog(*dialog\dialog)
      FreeStructure(*dialog)
    EndIf
  EndProcedure
  
  Procedure repoSelectFilesDownload()
    Protected *dialog.fileSelectionDialog
    Protected *file.repository::RepositoryFile
    Protected *mod.repository::RepositoryMod
    *dialog = GetWindowData(EventWindow())
    If *dialog
      *mod = GetGadgetData(DialogGadget(*dialog\dialog, "selectDownload"))
      ForEach *dialog\repoSelectFilesGadget()
        If *dialog\repoSelectFilesGadget() And IsGadget(*dialog\repoSelectFilesGadget())
          If GetGadgetState(*dialog\repoSelectFilesGadget())
            ; selected
            *file = GetGadgetData(*dialog\repoSelectFilesGadget())
            *file\download()
          EndIf
        EndIf
      Next
      PostEvent(#PB_Event_CloseWindow, *dialog\window, 0)
    EndIf
  EndProcedure
  
  Procedure repoSelectFilesUpdateButtons()
    Protected *dialog.fileSelectionDialog
    *dialog = GetWindowData(EventWindow())
    If *dialog
      ForEach *dialog\repoSelectFilesGadget()
        If *dialog\repoSelectFilesGadget() And IsGadget(*dialog\repoSelectFilesGadget())
          If GetGadgetState(*dialog\repoSelectFilesGadget())
            DisableGadget(DialogGadget(*dialog\dialog, "selectDownload"), #False)
            ProcedureReturn #True
          EndIf
        EndIf
      Next
      DisableGadget(DialogGadget(*dialog\dialog, "selectDownload"), #True)
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure repoShowModFileSelection()
    Protected *dialog.fileSelectionDialog
    Protected *mod.repository::RepositoryMod
    Protected NewList *files.repository::RepositoryFile()
    Protected *nodeBase, *node
    Protected *file
    
    *mod = EventWindow()
    If *mod
      deb("windowMain:: show repo mod file selection dialog")
      
      If IsXML(xml)
        *nodeBase = XMLNodeFromID(xml, "selectBox")
        If *nodeBase
          misc::clearXMLchildren(*nodeBase)
          ; add a checkbox for each file in mod
          *mod\getFiles(*files())
          ForEach *files()
            *node = CreateXMLNode(*nodeBase, "checkbox", -1)
            If *node
              SetXMLAttribute(*node, "name", Str(*files()))
              SetXMLAttribute(*node, "text", *files()\getFilename())
            EndIf
          Next
          
          *dialog = AllocateStructure(fileSelectionDialog)
          *dialog\dialog = CreateDialog(#PB_Any)
          
          ; show window now
          If *dialog\dialog And
             OpenXMLDialog(*dialog\dialog, xml, "selectFiles", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(window))
            
            *dialog\window = DialogWindow(*dialog\dialog)
            SetWindowData(*dialog\window, *dialog)
            
            ; get gadgets
            ClearMap(*dialog\repoSelectFilesGadget())
            ForEach *files()
              If *files()\canDownload()
                *dialog\repoSelectFilesGadget(Str(*files())) = DialogGadget(*dialog\dialog, Str(*files()))
                SetGadgetData(*dialog\repoSelectFilesGadget(Str(*files())), *files())
                BindGadgetEvent(*dialog\repoSelectFilesGadget(Str(*files())), @repoSelectFilesUpdateButtons())
              EndIf
            Next
            
            SetWindowTitle(DialogWindow(*dialog\dialog), _("main_select_files"))
            SetGadgetText(DialogGadget(*dialog\dialog, "selectText"), _("main_select_files_text"))
            SetGadgetText(DialogGadget(*dialog\dialog, "selectCancel"), _("main_cancel"))
            SetGadgetText(DialogGadget(*dialog\dialog, "selectDownload"), _("main_download"))
            
            
            BindGadgetEvent(DialogGadget(*dialog\dialog, "selectCancel"), @repoSelectFilesClose())
            BindGadgetEvent(DialogGadget(*dialog\dialog, "selectDownload"), @repoSelectFilesDownload())
            SetGadgetData(DialogGadget(*dialog\dialog, "selectDownload"), *mod)
            
            DisableGadget(DialogGadget(*dialog\dialog, "selectDownload"), #True)
            
            BindEvent(#PB_Event_CloseWindow, @repoSelectFilesClose(), DialogWindow(*dialog\dialog))
            
            RefreshDialog(*dialog\dialog)
            HideWindow(DialogWindow(*dialog\dialog), #False, #PB_Window_WindowCentered)
            
;             DisableWindow(window, #True)
            ProcedureReturn #True
          EndIf
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  ;-------------------
  ;- save tab
  
  Procedure updateModStatus()
    ; for mods in list, check if installed or online available
    Protected NewList *items.CanvasList::CanvasListItem()
    Protected *tfSaveMod.tfsave::mod
    Protected *localmod, *repofile
    
    ;TODO update all icons, bind event for mod install and repo update to refresh mod status as well!
    
    *saveModList\GetAllItems(*items())
    ForEach *items()
      *tfSaveMod = *items()\GetUserData()
      If *tfSaveMod
        ; TODO ...
      EndIf
    Next
  EndProcedure
  
  Procedure saveOpenFile(file$)
    Protected *tfsave.tfsave::tfsave
    Protected *item.CanvasList::CanvasListItem
    Protected download.b
    
    ; free old data if available
    *tfsave = *saveModList\GetUserData()
    If *tfsave
      tfsave::freeInfo(*tfsave)
      *saveModList\SetUserData(#Null)
    EndIf
    *saveModList\ClearItems()
    *saveModList\SetEmptyScreen(_("save_loading"), "")
    
    ; reset gadgets
    SetGadgetText(gadget("saveYear"), " ")
    SetGadgetText(gadget("saveDifficulty"), " ")
    SetGadgetText(gadget("saveMapSize"), " ")
    SetGadgetText(gadget("saveMoney"), " ")
    SetGadgetText(gadget("saveFileSize"), " ")
    SetGadgetText(gadget("saveFileSizeUncompressed"), " ")
    
    ; try to read info from file
    *tfsave = tfsave::readInfo(file$)
    DisableGadget(gadget("saveDownload"), #True)
    
    If *tfsave
      *saveModList\SetUserData(*tfsave)
      Select *tfsave\error
        Case tfsave::#ErrorNotSaveFile
          *saveModList\SetEmptyScreen(_("save_error_not_save_file"), "")
        Case tfsave::#ErrorVersionUnknown
          *saveModList\SetEmptyScreen(_("save_error_version", "version="+*tfsave\version), "")
        Case tfsave::#ErrorModNumberError
          *saveModList\SetEmptyScreen(_("save_error_mod_number_mismatch"), "")
        Case tfsave::#ErrorNoError
          SetGadgetText(gadget("saveName"), _("save_save")+": "+GetFilePart(file$, #PB_FileSystem_NoExtension))
          SetGadgetText(gadget("saveYear"), Str(*tfsave\startYear))
          SetGadgetText(gadget("saveDifficulty"), _("save_difficulty"+Str(*tfsave\difficulty)))
          SetGadgetText(gadget("saveMapSize"), Str(*tfsave\numTilesX/4)+" km x "+Str(*tfsave\numTilesY/4)+" km")
          SetGadgetText(gadget("saveMoney"), "$"+StrF(*tfsave\money/1000000, 2)+" Mio")
          SetGadgetText(gadget("saveFileSize"), misc::printSize(*tfsave\fileSize))
          SetGadgetText(gadget("saveFileSizeUncompressed"), misc::printSize(*tfsave\fileSizeUncompressed))
          
          If ListSize(*tfsave\mods())
            *saveModList\SetAttribute(canvasList::#AttributePauseDraw, #True)
            ForEach *tfsave\mods()
              *item = *saveModList\AddItem(*tfsave\mods()\name$+#LF$+"ID: "+*tfsave\mods()\id$, *tfsave\mods())
              
              *tfsave\mods()\localmod = mods::getModByID(*tfsave\mods()\id$)
              *tfsave\mods()\repofile = repository::getFileByFoldername(*tfsave\mods()\id$)
              
              If *tfsave\mods()\localmod
                *item\AddIcon(images::images("itemIcon_installed"), _("hint_save_installed"))
              Else
                *item\AddIcon(images::images("itemIcon_notInstalled"), _("hint_save_not_installed"))
              EndIf
              If *tfsave\mods()\repofile
                *item\AddIcon(images::images("itemIcon_availableOnline"), _("hint_save_online"))
              Else
                *item\AddIcon(images::images("itemIcon_notAvailableOnline"), _("hint_save_not_online"))
              EndIf
              If *tfsave\mods()\repofile And Not *tfsave\mods()\localmod
                download = #True
              EndIf
            Next
            *saveModList\SetAttribute(canvasList::#AttributePauseDraw, #False)
            If download
              DisableGadget(gadget("saveDownload"), #False)
            EndIf
          Else
            *saveModList\SetEmptyScreen(_("save_error_no_mods"), "")
          EndIf
        Default
          *saveModList\SetEmptyScreen(_("save_error_unknown"), "")
      EndSelect
    Else
      *saveModList\SetEmptyScreen(_("save_error_read_file", "filename="+file$), "")
    EndIf
  EndProcedure
  
  Procedure saveOpen()
    ; open a new savegame
    Protected file$
    
    file$ = OpenFileRequester(_("save_open_title"), settings::getString("save", "last"), "*.sav", 0)
    If file$
      settings::setString("save", "last", file$)
      
      saveOpenFile(file$)
    EndIf
  EndProcedure
  
  Procedure saveDownload()
    ; for each mod not installed but available online, start download
    Protected NewList *items.CanvasList::CanvasListitem()
    Protected *tfsaveMod.tfsave::mod
    Protected *file.repository::RepositoryFile
    deb("windowMain:: download all files from save")
    If *saveModList\GetAllItems(*items())
      ForEach *items()
        *tfsaveMod = *items()\GetUserData()
        If *tfsaveMod\repofile And Not *tfsaveMod\localmod
          deb("windowMain:: download missing mod '"+*tfsaveMod\id$+"'")
          *file = *tfsaveMod\repofile
          *file\download()
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure saveModListEvent()
    If EventType() = #PB_EventType_LeftClick
      If Not *saveModList\GetItemCount()
        saveOpen()
      EndIf
    EndIf
  EndProcedure
  
  ;- backup tab
  
  Procedure backupRestore()
    Protected NewList *items.CanvasList::CanvasListItem()
    Protected *backup.mods::BackupMod
    If *backupList\GetAllSelectedItems(*items())
      ForEach *items()
        *backup = *items()\GetUserData()
        If *backup
          *backup\install()
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure backupDelete()
    Protected NewList *items.CanvasList::CanvasListItem()
    Protected *backup.mods::BackupMod
    
    If *backupList\GetAllSelectedItems(*items())
      ; get backups
      If ListSize(*items()) = 1
        *backup = *items()\GetUserData()
        If MessageRequester(_("backup_delete_mod_title", "name="+*backup\getName()), 
                            _("backup_delete_mod_body", "name="+*backup\getName()),
                            #PB_MessageRequester_Warning|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
          *backup\delete()
        EndIf
      Else ; multiple backups selected
        If MessageRequester(_("backup_delete_mods_title", "number="+ListSize(*items())), 
                            _("backup_delete_mods_body", "number="+ListSize(*items())),
                            #PB_MessageRequester_Warning|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
          ForEach *items()
            *backup = *items()\GetUserData()
            *backup\delete()
          Next
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  Procedure backupFolder()
    Protected folder$ = mods::backupsGetFolder()
    misc::CreateDirectoryAll(folder$)
    misc::openLink(folder$)
  EndProcedure
  
  Procedure backupRefreshList()
    mods::backupsScan()
  EndProcedure
  
  Procedure backupIconOpenFile(*item.CanvasList::CanvasListItem)
    Protected *backup.mods::BackupMod
    *backup = *item\GetUserData()
    If *backup
      misc::openLink(mods::backupsGetFolder()+*backup\getFilename())
    EndIf
  EndProcedure
  
  Procedure backupIconRestore(*item.CanvasList::CanvasListItem)
    Protected *backup.mods::BackupMod
    *backup = *item\GetUserData()
    If *backup
      *backup\install()
    EndIf
  EndProcedure
  
  Procedure backupIconDelete(*item.CanvasList::CanvasListItem)
    Protected *backup.mods::BackupMod
    *backup = *item\GetUserData()
    If *backup
      If MessageRequester(_("backup_delete_mod_title", "name="+*backup\getName()), 
                          _("backup_delete_mod_body", "name="+*backup\getName()),
                          #PB_MessageRequester_Warning|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
        *backup\delete()
      EndIf
    EndIf
  EndProcedure
  
  
  Procedure backupListItemEvent(*item, event)
    Select event
      Case #PB_EventType_LeftDoubleClick
        If *item
          ; item action
        EndIf
      Case #PB_EventType_Change
        updateBackupButtons()
    EndSelect
  EndProcedure
  
  Procedure backupCallbackNewBackup(*backup.mods::BackupMod)
    ; a new backup file was created at "filename"
    Protected *item.CanvasList::CanvasListItem
    
    *item = *backupList\AddItem(*backup\getName()+" v"+*backup\getVersion()+Chr(9)+
                                _("generic_folder")+": "+*backup\getFoldername()+#LF$+
                                _("generic_by")+" "+*backup\getAuthors()+Chr(9)+
                                FormatDate(_("main_backup_date"), *backup\getDate()), *backup)
    
    *item\AddButton(@backupIconOpenFile(), images::Images("itemBtnFile"), images::images("itemBtnFileHover"), _("hint_backup_open_file"))
    *item\AddButton(@backupIconRestore(), images::Images("itemBtnRestore"), images::images("itemBtnRestoreHover"), _("hint_backup_restore"))
    *item\AddButton(@backupIconDelete(),  images::Images("itemBtnDelete"), images::images("itemBtnDeleteHover"), _("hint_backup_delete"))
    
    ; potentially, there already was a backup with this filename
    ; TODO check if backup is duplicate?
  EndProcedure
  
  Procedure backupCallbackRemoveBackup(*backup.mods::BackupMod)
    Protected NewList *items.CanvasList::CanvasListItem()
    If *backupList\GetAllItems(*items())
      ForEach *items()
        If *backup = *items()\GetUserData()
          *backupList\RemoveItem(*items())
          Break
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure backupCallbackClearBackups()
    *backupList\ClearItems()
  EndProcedure
  
  
  ;- backup filter dialog
  
  Procedure backupFilterCallback(*item.CanvasList::CanvasListItem, options)
    ; return true if this mod shall be displayed, false if hidden
    Protected *backup.mods::BackupMod = *item\GetUserData()
    Protected string$, s$, i, n
    Protected date
    
    date = GetGadgetState(DialogGadget(backupFilter\dialog, "filterDate"))
    If date ; match exact date
      date = Date(Year(date), Month(date), Day(date), 0, 0, 0)
      If *backup\getDate() < date Or *backup\getDate() > date + 86400
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; check for search string
    string$ = GetGadgetText(DialogGadget(backupFilter\dialog, "filterString"))
    If string$
      ; split string in parts
      n = CountString(string$, " ")
      For i = 1 To n+1
        s$ = StringField(string$, i, " ")
        If s$
          ; check if s$ is found in any of the information of the mod
          If Not FindString(*backup\getName(), s$, 1, #PB_String_NoCase)
            If Not FindString(*backup\getAuthors(), s$, 1, #PB_String_NoCase)
              If Not FindString(*backup\getFoldername(), s$, 1, #PB_String_NoCase)
                ProcedureReturn #False
              EndIf
            EndIf
          EndIf
        EndIf
      Next
    EndIf
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure backupFilterChange()
    ; save current filter to settings
    settings::setString("backupFilter", "filter", GetGadgetText(DialogGadget(backupFilter\dialog, "filterString")))
    settings::setInteger("backupFilter", "date", GetGadgetState(DialogGadget(backupFilter\dialog, "filterDate")))
    *backupList\FilterItems(@backupFilterCallback(), 0, #True)
  EndProcedure
  
  Procedure backupFilterReset()
    SetGadgetText(DialogGadget(backupFilter\dialog, "filterString"), "")
    SetActiveGadget(DialogGadget(backupFilter\dialog, "filterString"))
    backupFilterChange()
  EndProcedure
  
  ;- repo sort dialog
  
  ;- repo sort functions
  
  Procedure compBackupName(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *backup1.mods::BackupMod = *item1\GetUserData()
    Protected *backup2.mods::BackupMod = *item2\GetUserData()
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(LCase(*backup1\getName()) <= LCase(*backup2\getName()))
    Else
      ProcedureReturn Bool(LCase(*backup1\getName()) > LCase(*backup2\getName()))
    EndIf
  EndProcedure
  
  Procedure compBackupDate(*item1.CanvasList::CanvasListItem, *item2.CanvasList::CanvasListItem, options)
    Protected *backup1.mods::BackupMod = *item1\GetUserData()
    Protected *backup2.mods::BackupMod = *item2\GetUserData()
    If options & #PB_Sort_Descending
      ProcedureReturn Bool(*backup1\getDate() <= *backup2\getDate())
    Else
      ProcedureReturn Bool(*backup1\getDate() > *backup2\getDate())
    EndIf
  EndProcedure
  
  Procedure backupSortChange()
    ; apply sorting to CanvasList
    Protected *comp, mode, options
    
    mode = GetGadgetState(DialogGadget(backupSort\dialog, "sortBox"))
    settings::setInteger("backupSort", "mode", mode)
    
    ; get corresponding sorting function
    Select mode
      Case 1
        *comp = @compBackupName()
        options = #PB_Sort_Ascending
      Default
        *comp = @compBackupDate()
        options = #PB_Sort_Descending
    EndSelect
    
    ; Sort CanvasList and make persistent sort (gadget will be keept sorted automatically)
    *backupList\SortItems(CanvasList::#SortByUser, *comp, options, #True)
    
    ; close the mod sort tool window
    PostEvent(#PB_Event_CloseWindow, backupSort\window, #Null)
  EndProcedure
  
  ;- DRAG & DROP
  
  Procedure HandleDroppedFiles()
    Protected count, i
    Protected file$, files$
    
    files$ = EventDropFiles()
    count  = CountString(files$, Chr(10)) + 1
    For i = 1 To count
      file$ = StringField(files$, i, Chr(10))
      handleFile(file$)
    Next i
  EndProcedure
  
  Procedure getStatusBarHeight()
    Protected window, bar, height
    window = OpenWindow(#PB_Any, 0, 0, 100, 100, "Status Bar", #PB_Window_SystemMenu|#PB_Window_Invisible|#PB_Window_SizeGadget)
    If window
      bar = CreateStatusBar(#PB_Any, WindowID(window))
      AddStatusBarField(#PB_Ignore)
      StatusBarText(bar, 0, "Status Bar", #PB_StatusBar_BorderLess)
      height = StatusBarHeight(bar)
      FreeStatusBar(bar)
      CloseWindow(window)
    EndIf
    ProcedureReturn height
  EndProcedure
  
  ;-------------
  ;- dialogs
  
  Macro dq()
    "
  EndMacro
  Macro BuildDialogWindow(name)
    name\dialog = CreateDialog(#PB_Any)
    If Not name\dialog Or Not OpenXMLDialog(name\dialog, xml, dq()name#dq(), #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(window))
      deb("could not open "+dq()name#dq()+" dialog!")
      End
    EndIf
    name\window = DialogWindow(name\dialog)
    BindEvent(#PB_Event_CloseWindow, @dialogClose(), name\window)
    BindEvent(#PB_Event_DeactivateWindow, @dialogClose(), name\window)
    AddKeyboardShortcut(name\window, #PB_Shortcut_Return, #PB_Event_CloseWindow)
    AddKeyboardShortcut(name\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
    BindEvent(#PB_Event_Menu, @dialogClose(), name\window, #PB_Event_CloseWindow)
    SetWindowData(name\window, @name)
  EndMacro
  
  Procedure dialogClose()
    Protected *dialog.dialog = GetWindowData(EventWindow())
    HideWindow(*dialog\window, #True)
    SetActiveWindow(window)
    PostEvent(#PB_Event_Repaint, window, 0)
    If *dialog\listGadget
      SetActiveGadget(*dialog\listGadget)
    EndIf
  EndProcedure
  
  Procedure dialogShow(*dialog.dialog)
    ResizeWindow(*dialog\window, DesktopMouseX()-WindowWidth(*dialog\window)+5, DesktopMouseY()-5, #PB_Ignore, #PB_Ignore)
    HideWindow(*dialog\window, #False)
    If *dialog\activeGadget
      SetActiveGadget(*dialog\activeGadget)
    EndIf
  EndProcedure
  
  Procedure modSortShow()
    dialogShow(@modSort)
  EndProcedure
  
  Procedure modFilterShow()
    dialogShow(@modFilter)
  EndProcedure
  
  Procedure repoSortShow()
    dialogShow(@repoSort)
  EndProcedure
  
  Procedure repoFilterShow()
    dialogShow(@repoFilter)
  EndProcedure
  
  Procedure backupSortShow()
    dialogShow(@backupSort)
  EndProcedure
  
  Procedure backupFilterShow()
    dialogShow(@backupFilter)
  EndProcedure
  
  ; specific functions
  
  Procedure shortcutCtrlF()
    Select currentTab
      Case #TabMods
        modFilterShow()
      Case #TabOnline
        repoFilterShow()
      Case #TabBackup
        backupFilterShow()
    EndSelect
  EndProcedure
  
  ; create dialogs:
  
  Procedure modFilterDialog()
    BuildDialogWindow(modFilter)
    modFilter\listGadget = gadget("modList")
    modFilter\activeGadget = DialogGadget(modFilter\dialog, "modFilterString")
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterDeprecated"),_("dialog_mods_deprecated"))
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterVanilla"),   _("dialog_mods_vanilla"))
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterHidden"),    _("dialog_mods_hidden"))
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterWorkshop"),  _("dialog_mods_workshop"))
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterStaging"),   _("dialog_mods_staging"))
    RefreshDialog(modFilter\dialog)
    ; load settings
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterString"), "")
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterString"), settings::getString("modFilter", "filter"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterDeprecated"), settings::getInteger("modFilter", "deprecated"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterVanilla"), settings::getInteger("modFilter", "vanilla"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterHidden"), settings::getInteger("modFilter", "hidden"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterWorkshop"), settings::getInteger("modFilter", "workshop"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterStaging"), settings::getInteger("modFilter", "staging"))
    ; bind events
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterString"), @modFilterChange(), #PB_EventType_Change)
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterReset"), @modFilterReset())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterDeprecated"), @modFilterChange())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterVanilla"), @modFilterChange())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterHidden"), @modFilterChange())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterWorkshop"), @modFilterChange())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterStaging"), @modFilterChange())
    ; apply initial filtering
    modFilterChange()
  EndProcedure
  
  Procedure modSortDialog()
    BuildDialogWindow(modSort)
    modSort\listGadget = gadget("modList")
    SetGadgetText(DialogGadget(modSort\dialog, "sortBy"), _("dialog_sort_by"))
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, _("dialog_mod_name"))
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, _("dialog_author_name"))
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, _("dialog_install_date"))
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, _("dialog_folder_size"))
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, _("dialog_folder_name"))
    SetGadgetState(DialogGadget(modSort\dialog, "sortBox"), 0)
    RefreshDialog(modSort\dialog)
    BindGadgetEvent(DialogGadget(modSort\dialog, "sortBox"), @modSortChange())
    ; load settings
    SetGadgetState(DialogGadget(modSort\dialog, "sortBox"), settings::getInteger("modSort", "mode"))
    ; apply initial sorting
    modSortChange()
  EndProcedure
  
  Procedure repoFilterDialog()
    BuildDialogWindow(repoFilter)
    repoFilter\listGadget = gadget("repoList")
    repoFilter\activeGadget = DialogGadget(repoFilter\dialog, "filterString")
    SetGadgetText(DialogGadget(repoFilter\dialog, "filterDateLabel"), _("dialog_updated_not_before"))
    RefreshDialog(repoFilter\dialog)
    ; load settings
    SetGadgetAttribute(DialogGadget(repoFilter\dialog, "filterDate"), #PB_Calendar_Maximum, Date())
    SetGadgetAttribute(DialogGadget(repoFilter\dialog, "filterDate"), #PB_Calendar_Minimum, Date(2014, 8, 12, 0, 0, 0))
    SetGadgetText(DialogGadget(repoFilter\dialog, "filterString"), "")
    SetGadgetText(DialogGadget(repoFilter\dialog, "filterString"), settings::getString("repoFilter", "filter"))
    SetGadgetState(DialogGadget(repoFilter\dialog, "filterDate"), settings::getInteger("repoFilter", "date"))
    ; dynamically add available sources!
    ; bind events
    BindGadgetEvent(DialogGadget(repoFilter\dialog, "filterString"), @repoFilterChange(), #PB_EventType_Change)
    BindGadgetEvent(DialogGadget(repoFilter\dialog, "filterReset"), @repoFilterReset())
    BindGadgetEvent(DialogGadget(repoFilter\dialog, "filterDate"), @repoFilterChange(), #PB_EventType_Change)
;     BindGadgetEvent(DialogGadget(repoFilter\dialog, "filterReset"), @repoFilterReset())
    ; apply initial filtering
    repoFilterChange()
  EndProcedure
  
  Procedure repoSortDialog()
    BuildDialogWindow(repoSort)
    repoSort\listGadget = gadget("repoList")
    SetGadgetText(DialogGadget(repoSort\dialog, "sortBy"), _("dialog_sort_by"))
    AddGadgetItem(DialogGadget(repoSort\dialog, "sortBox"), -1, _("dialog_updated"))
    AddGadgetItem(DialogGadget(repoSort\dialog, "sortBox"), -1, _("dialog_mod_name"))
    SetGadgetState(DialogGadget(repoSort\dialog, "sortBox"), 0)
    RefreshDialog(repoSort\dialog)
    BindGadgetEvent(DialogGadget(repoSort\dialog, "sortBox"), @repoSortChange())
    ; load settings
    SetGadgetState(DialogGadget(repoSort\dialog, "sortBox"), settings::getInteger("repoSort", "mode"))
    ; apply initial sorting
    repoSortChange()
  EndProcedure
  
  Procedure backupFilterDialog()
    BuildDialogWindow(backupFilter)
    backupFilter\listGadget = gadget("backupList")
    backupFilter\activeGadget = DialogGadget(backupFilter\dialog, "filterString")
    SetGadgetText(DialogGadget(backupFilter\dialog, "filterDateLabel"), _("dialog_backup_on"))
    RefreshDialog(backupFilter\dialog)
    ; load settings
    SetGadgetAttribute(DialogGadget(backupFilter\dialog, "filterDate"), #PB_Calendar_Maximum, Date())
    SetGadgetAttribute(DialogGadget(backupFilter\dialog, "filterDate"), #PB_Calendar_Minimum, Date(2018, 1, 1, 0, 0, 0))
    SetGadgetText(DialogGadget(backupFilter\dialog, "filterString"), "")
    SetGadgetText(DialogGadget(backupFilter\dialog, "filterString"), settings::getString("backupFilter", "filter"))
    SetGadgetState(DialogGadget(backupFilter\dialog, "filterDate"), settings::getInteger("backupFilter", "date"))
    ; dynamically add available sources!
    ; bind events
    BindGadgetEvent(DialogGadget(backupFilter\dialog, "filterString"), @backupFilterChange(), #PB_EventType_Change)
    BindGadgetEvent(DialogGadget(backupFilter\dialog, "filterReset"), @backupFilterReset())
    BindGadgetEvent(DialogGadget(backupFilter\dialog, "filterDate"), @backupFilterChange(), #PB_EventType_Change)
    ; apply initial filtering
    backupFilterChange()
  EndProcedure
  
  Procedure backupSortDialog()
    BuildDialogWindow(backupSort)
    backupSort\listGadget = gadget("backupList")
    SetGadgetText(DialogGadget(backupSort\dialog, "sortBy"), _("dialog_sort_by"))
    AddGadgetItem(DialogGadget(backupSort\dialog, "sortBox"), -1, _("dialog_backup_date"))
    AddGadgetItem(DialogGadget(backupSort\dialog, "sortBox"), -1, _("dialog_mod_name"))
    SetGadgetState(DialogGadget(backupSort\dialog, "sortBox"), 0)
    RefreshDialog(backupSort\dialog)
    BindGadgetEvent(DialogGadget(backupSort\dialog, "sortBox"), @backupSortChange())
    ; load settings
    SetGadgetState(DialogGadget(backupSort\dialog, "sortBox"), settings::getInteger("backupSort", "mode"))
    ; apply initial sorting
    backupSortChange()
  EndProcedure
  
  ;--------------
  ; - strings
  
  Procedure updateStrings()
    UseModule locale
    ; nav
    GadgetToolTip(gadget("btnMods"),      _("main_mods"))
    GadgetToolTip(gadget("btnMaps"),      _("main_maps"))
    GadgetToolTip(gadget("btnOnline"),    _("main_repository"))
    GadgetToolTip(gadget("btnBackups"),   _("main_backups"))
    GadgetToolTip(gadget("btnSaves"),     _("main_saves"))
    GadgetToolTip(gadget("btnSettings"),  _("menu_settings"))
    GadgetToolTip(gadget("btnHelp"),      _("main_help"))
    
    ; mod tab
    GadgetToolTip(gadget("modFilter"),          _("hint_mods_filter"))
    GadgetToolTip(gadget("modSort"),            _("hint_mods_sort"))
    GadgetToolTip(gadget("modUpdate"),          _("hint_mods_update"))
    GadgetToolTip(gadget("modBackup"),          _("hint_mods_backup"))
    GadgetToolTip(gadget("modUninstall"),       _("hint_mods_uninstall"))
    GadgetToolTip(gadget("modShare"),           _("hint_mods_share"))
    GadgetToolTip(gadget("modUpdateAll"),       _("hint_mods_update_all"))
    
    ; repo tab
    GadgetToolTip(gadget("repoFilter"),         _("hint_repo_filter"))
    GadgetToolTip(gadget("repoSort"),           _("hint_repo_sort"))
    GadgetToolTip(gadget("repoDownload"),       _("hint_repo_download"))
    GadgetToolTip(gadget("repoWebsite"),        _("hint_repo_website"))
    GadgetToolTip(gadget("repoRefresh"),        _("hint_repo_refresh"))
    
    ; backup tab
    GadgetToolTip(gadget("backupFilter"),       _("hint_backup_filter"))
    GadgetToolTip(gadget("backupSort"),         _("hint_backup_sort"))
    GadgetToolTip(gadget("backupRestore"),      _("hint_backup_restore"))
    GadgetToolTip(gadget("backupDelete"),       _("hint_backup_delete"))
    GadgetToolTip(gadget("backupFolder"),       _("hint_backup_folder"))
    GadgetToolTip(gadget("backupRefresh"),      _("hint_backup_refresh"))
    
    ; saves tab
    *saveModList\SetEmptyScreen(_("main_save_click_open"), "")
    SetGadgetText(gadget("saveName"),           _("main_save_start"))
    GadgetToolTip(gadget("saveOpen"),           _("hint_save_open")+":")
    GadgetToolTip(gadget("saveDownload"),       _("hint_save_download")+":")
    SetGadgetText(gadget("saveLabelYear"),      _("save_year")+":")
    SetGadgetText(gadget("saveLabelDifficulty"),_("save_difficulty")+":")
    SetGadgetText(gadget("saveLabelMapSize"),   _("save_mapsize")+":")
    SetGadgetText(gadget("saveLabelMoney"),     _("save_money")+":")
    SetGadgetText(gadget("saveLabelFileSize"),  _("save_filesize")+":")
    SetGadgetText(gadget("saveLabelFileSizeUncompressed"),  _("save_filesize_uncompressed")+":")
    
    UnuseModule locale
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create()
    UseModule locale ; import namespace "locale" for shorthand "l()" access
    
    misc::IncludeAndLoadXML(xml, "dialogs/main.xml")
    
    ; dialog does not take menu height and statusbar height into account
    ; workaround: placeholder node in dialog tree with required offset.
    SetXMLAttribute(XMLNodeFromID(xml, "placeholder"), "margin", "bottom:"+Str(MenuHeight()-8)) ; getStatusBarHeight()
    
    dialog = CreateDialog(#PB_Any)
    If Not dialog Or Not OpenXMLDialog(dialog, xml, "main")
      MessageRequester("Critical Error", "Could not open main window!", #PB_MessageRequester_Error)
      End
    EndIf
    
    window = DialogWindow(dialog)
    
    ;- load window icon under Linux
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
      Protected iconPath$, iconError, file
      DataSection
        icon:
        IncludeBinary "images/TPFMM.png"
        iconEnd:
      EndDataSection
      iconPath$ = GetTemporaryDirectory()+"/tpfmm-icon.png"
      misc::extractBinary(iconPath$, ?icon, ?iconEnd - ?icon)
      gtk_window_set_icon_from_file_(WindowID(window), iconPath$, iconError)
    CompilerEndIf
    
    ; fonts
    Protected fontMono  = LoadFont(#PB_Any, "Courier", misc::getDefaultFontSize())
    Protected fontBig   = LoadFont(#PB_Any, misc::getDefaultFontName(), misc::getDefaultFontSize()*1.2, #PB_Font_Bold|#PB_Font_HighQuality)
    
    ;- Set window events & timers
    AddWindowTimer(window, TimerMain, 100)
    BindEvent(#PB_Event_SizeWindow, @resize(), window)
    BindEvent(#PB_Event_MaximizeWindow, @resize(), window)
    BindEvent(#PB_Event_RestoreWindow, @resize(), window)
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    BindEvent(#PB_Event_WindowDrop, @HandleDroppedFiles(), window)
    BindEvent(#EventCloseNow, main::@exit())
    BindEvent(#EventUpdateAvailable, @updateAvailable(), window)
    BindEvent(#EventStartUpFinished, @startupFinished(), window)
    
    
    ;- custom canvas gadgets
    Protected theme$
    
    *modList = CanvasList::NewCanvasListGadget(#PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, gadget("modList"))
    *modList\BindItemEvent(#PB_EventType_LeftDoubleClick,   @modListItemEvent())
    *modList\BindItemEvent(#PB_EventType_Change,            @modListItemEvent())
    
    *repoList = CanvasList::NewCanvasListGadget(#PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, gadget("repoList"))
    *repoList\BindItemEvent(CanvasList::#OnItemFirstVisible, @repoEventItemVisible()) ; dynamically load images when items get visible
    *repoList\BindItemEvent(#PB_EventType_LeftDoubleClick,   @repoListItemEvent())
    *repoList\BindItemEvent(#PB_EventType_Change,            @repoListItemEvent())
    
    *backupList = CanvasList::NewCanvasListGadget(#PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, gadget("backupList"))
    *backupList\BindItemEvent(#PB_EventType_LeftDoubleClick, @backupListItemEvent())
    *backupList\BindItemEvent(#PB_EventType_Change,          @backupListItemEvent())
    misc::BinaryAsString("theme/backupList.json", theme$)
    *backupList\SetTheme(theme$)
    
    *saveModList = CanvasList::NewCanvasListGadget(#PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, gadget("saveModList"))
    misc::BinaryAsString("theme/saveModList.json", theme$)
    *saveModList\SetTheme(theme$)
    
    ;- worker animation
    *workerAnimation = animation::new()
    *workerAnimation\setCanvas(gadget("workerCanvas"))
    *workerAnimation\setBackgroundColor(misc::GetWindowBackgroundColor(WindowID(window))) ; GetWindowColor(window)
    *workerAnimation\setInterval(1000/60)
    *workerAnimation\loadAni("images/logo/logo.ani")
    *workerAnimation\draw(0) ; draw first frame
    BindEvent(#EventWorkerStarts, @workerStart())
    BindEvent(#EventWorkerStops, @workerStop())
    
    
    ;-------------------
    ;-initialize gadget images
    SetGadgetText(gadget("version"), main::#VERSION$)
    
    ; nav
    SetGadgetAttribute(gadget("btnMods"),     #PB_Button_Image,   ImageID(images::Images("navMods")))
    SetGadgetAttribute(gadget("btnOnline"),   #PB_Button_Image,   ImageID(images::Images("navOnline")))
    SetGadgetAttribute(gadget("btnBackups"),  #PB_Button_Image,   ImageID(images::Images("navBackups")))
    SetGadgetAttribute(gadget("btnMaps"),     #PB_Button_Image,   ImageID(images::Images("navMaps")))
    SetGadgetAttribute(gadget("btnSaves"),    #PB_Button_Image,   ImageID(images::Images("navSaves")))
    SetGadgetAttribute(gadget("btnSettings"), #PB_Button_Image,   ImageID(images::Images("navSettings")))
    SetGadgetAttribute(gadget("btnHelp"),     #PB_Button_Image,   ImageID(images::Images("navHelp")))
    DisableGadget(gadget("btnMaps"), #True)
    
    ; mod tab
    SetGadgetAttribute(gadget("modFilter"),     #PB_Button_Image, ImageID(images::images("btnFilter")))
    SetGadgetAttribute(gadget("modSort"),       #PB_Button_Image, ImageID(images::images("btnSort")))
    
    SetGadgetAttribute(gadget("modUpdate"),     #PB_Button_Image, ImageID(images::images("btnUpdate")))
    SetGadgetAttribute(gadget("modShare"),      #PB_Button_Image, ImageID(images::images("btnShare")))
    SetGadgetAttribute(gadget("modBackup"),     #PB_Button_Image, ImageID(images::images("btnBackup")))
    SetGadgetAttribute(gadget("modUninstall"),  #PB_Button_Image, ImageID(images::images("btnUninstall")))
    SetGadgetAttribute(gadget("modUpdateAll"),  #PB_Button_Image, ImageID(images::images("btnUpdateAll")))
    
    ; repo tab
    SetGadgetAttribute(gadget("repoFilter"),     #PB_Button_Image, ImageID(images::images("btnFilter")))
    SetGadgetAttribute(gadget("repoSort"),       #PB_Button_Image, ImageID(images::images("btnSort")))
    
    SetGadgetAttribute(gadget("repoDownload"),  #PB_Button_Image, ImageID(images::images("btnDownload")))
    SetGadgetAttribute(gadget("repoWebsite"),   #PB_Button_Image, ImageID(images::images("btnWebsite")))
    SetGadgetAttribute(gadget("repoRefresh"),   #PB_Button_Image, ImageID(images::images("btnUpdate")))
    
    ; saves tab
    SetGadgetAttribute(gadget("saveOpen"),      #PB_Button_Image, ImageID(images::images("btnOpen")))
    SetGadgetAttribute(gadget("saveDownload"),  #PB_Button_Image, ImageID(images::images("btnDownload")))
    SetGadgetFont(gadget("saveName"), FontID(fontBig))
    SetGadgetColor(gadget("saveName"), #PB_Gadget_FrontColor, $42332a);$63472F) ; #2F4763
    DisableGadget(gadget("saveDownload"), #True)
    
    ; backup tab
    SetGadgetAttribute(gadget("backupFilter"),  #PB_Button_Image, ImageID(images::images("btnFilter")))
    SetGadgetAttribute(gadget("backupSort"),    #PB_Button_Image, ImageID(images::images("btnSort")))
    SetGadgetAttribute(gadget("backupRestore"), #PB_Button_Image, ImageID(images::images("btnRestore")))
    SetGadgetAttribute(gadget("backupDelete"),  #PB_Button_Image, ImageID(images::images("btnUninstall")))
    SetGadgetAttribute(gadget("backupRefresh"), #PB_Button_Image, ImageID(images::images("btnUpdate")))
    SetGadgetAttribute(gadget("backupFolder"),  #PB_Button_Image, ImageID(images::images("btnFolder")))
    
    
    ;- update gadget texts
    updateStrings()
    
    
    ;- Bind Gadget Events
    ; nav
    BindGadgetEvent(gadget("btnMods"),          @navBtnMods())
    BindGadgetEvent(gadget("btnMaps"),          @navBtnMaps())
    BindGadgetEvent(gadget("btnOnline"),        @navBtnOnline())
    BindGadgetEvent(gadget("btnBackups"),       @navBtnBackups())
    BindGadgetEvent(gadget("btnSaves"),         @navBtnSaves())
    BindGadgetEvent(gadget("btnSettings"),      @navBtnSettings())
    BindGadgetEvent(gadget("btnHelp"),          @navBtnHelp())
    
    ; mod tab
    BindGadgetEvent(gadget("modFilter"),        @modFilterShow())
    BindGadgetEvent(gadget("modSort"),          @modSortShow())
    BindGadgetEvent(gadget("modUpdate"),        @modUpdate())
    BindGadgetEvent(gadget("modUpdateAll"),     @modUpdateAll())
    BindGadgetEvent(gadget("modBackup"),        @modBackup())
    BindGadgetEvent(gadget("modUninstall"),     @modUninstall())
    BindGadgetEvent(gadget("modList"),          @modListEvent())
    BindGadgetEvent(gadget("modShare"),         @modShareShowPopup())
    
    ; repo tab
    BindGadgetEvent(gadget("repoSort"),         @repoSortShow())
    BindGadgetEvent(gadget("repoFilter"),       @repoFilterShow())
    BindGadgetEvent(gadget("repoWebsite"),      @repoWebsite())
    BindGadgetEvent(gadget("repoDownload"),     @repoDownload())
    BindGadgetEvent(gadget("repoRefresh"),      @repoRefresh())
    BindEvent(#EventRepoRefreshFinished, @repoRefreshFinished(), window)
    
    ; backup tab
    BindGadgetEvent(gadget("backupSort"),       @backupSortShow())
    BindGadgetEvent(gadget("backupFilter"),     @backupFilterShow())
    BindGadgetEvent(gadget("backupRestore"),    @backupRestore())
    BindGadgetEvent(gadget("backupDelete"),     @backupDelete())
    BindGadgetEvent(gadget("backupFolder"),     @backupFolder())
    BindGadgetEvent(gadget("backupRefresh"),    @backupRefreshList())
    
    ; saves tab
    BindGadgetEvent(gadget("saveModList"), @saveModListEvent())
    BindGadgetEvent(gadget("saveOpen"), @saveOpen())
    BindGadgetEvent(gadget("saveDownload"), @saveDownload())
    
    
    ;- Menu
    menu = CreateMenu(#PB_Any, WindowID(window))
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      MenuTitle(_("menu_file"))
    CompilerEndIf
    MenuItem(#PB_Menu_Preferences, _("menu_settings") + Chr(9) + "Ctrl + P")
    MenuItem(#PB_Menu_Quit, _("menu_close") + Chr(9) + "Alt + F4")
    MenuTitle(_("menu_mods"))
    MenuItem(#MenuItem_AddMod, _("menu_mod_add") + Chr(9) + "Ctrl + O")
;     MenuItem(#MenuItem_, _("menu_mod_export"))
    MenuBar()
    MenuItem(#MenuItem_ShowBackups, _("menu_show_backups"))
    MenuItem(#MenuItem_ShowDownloads, _("menu_show_downloads"))
;     MenuTitle(_("menu_pack"))
;     MenuItem(#MenuItem_PackNew, _("menu_pack_new"))
;     MenuItem(#MenuItem_PackOpen, _("menu_pack_open"))
    MenuTitle(_("menu_about"))
    MenuItem(#MenuItem_Homepage, _("menu_homepage") + Chr(9) + "F1")
;     MenuItem(#PB_Menu_About, _("menu_license") + Chr(9) + "Ctrl + L")
    MenuItem(#MenuItem_Log, _("menu_log"))
    
    BindMenuEvent(menu, #PB_Menu_Preferences, @navBtnSettings())
    BindMenuEvent(menu, #PB_Menu_Quit, @close())
    BindMenuEvent(menu, #MenuItem_AddMod, @modAddNewMod())
    BindMenuEvent(menu, #MenuItem_ShowBackups, @backupFolder())
    BindMenuEvent(menu, #MenuItem_ShowDownloads, @modShowDownloadFolder())
    BindMenuEvent(menu, #MenuItem_Homepage, @MenuItemHomepage())
    BindMenuEvent(menu, #MenuItem_Log, @MenuItemLog())
;     BindMenuEvent(menu, #MenuItem_PackNew, @MenuItemPackNew())
;     BindMenuEvent(menu, #MenuItem_PackOpen, @MenuItemPackOpen())
    
    
    ;- create shortcuts
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      ; Mac OS X has predefined shortcuts
      AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_P, #PB_Menu_Preferences)
      AddKeyboardShortcut(window, #PB_Shortcut_Alt | #PB_Shortcut_F4, #PB_Menu_Quit)
      AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_L, #PB_Menu_About)
    CompilerEndIf
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_O, #MenuItem_AddMod)
    AddKeyboardShortcut(window, #PB_Shortcut_F1, #MenuItem_Homepage)
    AddKeyboardShortcut(window, #PB_Shortcut_Return, #MenuItem_Enter)
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_A, #MenuItem_CtrlA)
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_F, #MenuItem_CtrlF)
    
    BindMenuEvent(menu, #MenuItem_Enter, @MenuItemEnter())
    BindMenuEvent(menu, #MenuItem_CtrlA, @MenuItemSelectAll())
    BindMenuEvent(menu, #MenuItem_CtrlF, @shortCutCtrlF())
    
    
    ; popup menu
    menuShare = CreatePopupMenu(#PB_Any)
    If menuShare
      MenuItem(#MenuItem_ShareSelected, _("menu_share_selected"))
      MenuItem(#MenuItem_ShareFiltered, _("menu_share_filtered"))
      MenuItem(#MenuItem_ShareAll,      _("menu_share_all"))
      
      BindMenuEvent(menuShare, #MenuItem_ShareSelected, @modShareSelected())
      BindMenuEvent(menuShare, #MenuItem_ShareFiltered, @modShareFiltered())
      BindMenuEvent(menuShare, #MenuItem_ShareAll,      @modShareAll())
    EndIf
    
    
    ; indicate testmode in window title
    If main::_TESTMODE
      SetWindowTitle(window, GetWindowTitle(window) + " (Test Mode Enabled)")
    EndIf
    
    
    ; load images
    ResizeImage(images::Images("headermain"), GadgetWidth(gadget("headerMain")), GadgetHeight(gadget("headerMain")), #PB_Image_Raw)
    SetGadgetState(gadget("headerMain"), ImageID(images::Images("headermain")))
    
    
    ; Drag & Drop
    EnableWindowDrop(window, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
    
    
    ; mod module
    mods::BindEventCallback(mods::#EventNewMod, @modCallbackNewMod())
    mods::BindEventCallback(mods::#EventRemoveMod, @modCallbackRemoveMod())
    mods::BindEventCallback(mods::#EventStopDraw, @modCallbackStopDraw())
    mods::BindEventPost(mods::#EventProgress, #EventModProgress, @modEventProgress())
    mods::BindEventPost(mods::#EventWorkerStarts, #EventWorkerStarts, #Null) ; worker events already linked
    mods::BindEventPost(mods::#EventWorkerStops, #EventWorkerStops, #Null)
    mods::BindEventCallback(mods::#EventNewBackup, @backupCallbackNewBackup())
    mods::BindEventCallback(mods::#EventRemoveBackup, @backupCallbackRemoveBackup())
    mods::BindEventCallback(mods::#EventClearBackups, @backupCallbackClearBackups())
    
    ; repository module
    repository::BindEventCallback(repository::#EventAddMods, @repoCallbackAddMods())
    repository::BindEventCallback(repository::#EventClearMods, @repoCallbackClearList())
    repository::BindEventCallback(repository::#EventRefreshFinished, @repoCallbackRefreshFinished())
    repository::BindEventPost(repository::#EventShowModFileSelection, #EventRepoModFileSelection, @repoShowModFileSelection())
    repository::BindEventPost(repository::#EventProgress, #EventRepoProgress, @repoEventProgress())
    repository::BindEventPost(repository::#EventWorkerStarts, #EventWorkerStarts, #Null) ; worker events already linked
    repository::BindEventPost(repository::#EventWorkerStops, #EventWorkerStops, #Null)
    
    
    ;-------------------
    ;- open dialogs (sort / filter / ...)
    modFilterDialog()
    modSortDialog()
    repoFilterDialog()
    repoSortDialog()
    backupFilterDialog()
    backupSortDialog()
    
    ;-------------------
    ;-init gui texts and button states
    updateModButtons()
    updateRepoButtons()
    updateBackupButtons()
    
    ;-------------------
    ;-apply sizes
    RefreshDialog(dialog)
    resize()
    navBtnMods()
    
    UnuseModule locale
  EndProcedure
  
  Procedure getColumnWidth(column)
    ProcedureReturn GetGadgetItemAttribute(gadget("modList"), #PB_Any, #PB_Explorer_ColumnWidth, column)
  EndProcedure
  
  Procedure repoFindModAndDownloadThread(*link)
    Protected link$
    Protected *repoMod.repository::RepositoryMod
    Protected *repoFile.repository::RepositoryFile
    
    link$ = PeekS(*link)
    FreeMemory(*link)
    
    ; wait for repository for finish loading
    While Not repository::isLoaded()
      Delay(100)
    Wend
    
    *repoFile = repository::getFileByLink(link$)
    If *repoFile
      *repoFile\download()
    Else
      *repoMod = repository::getModByLink(link$)
      If *repoMod
        *repoMod\download()
      EndIf
    EndIf
    
  EndProcedure
  
  Procedure repoFindModAndDownload(link$)
    ; search for a mod in repo and initiate download
    
    Protected *link
    *link = AllocateMemory(StringByteLength(link$)+SizeOf(Character))
    PokeS(*link, link$)
    
    ; start in thread in order to wait for repository to finish
    CreateThread(@repoFindModAndDownloadThread(), *link)
  EndProcedure
  
  Procedure getSelectedMods(List *mods())
    Protected i, k
    ClearList(*mods())
    
    For i = 0 To CountGadgetItems(gadget("modList"))-1
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
        AddElement(*mods())
        *mods() = GetGadgetItemData(gadget("modList"), i)
        k + 1
      EndIf
    Next
    
    ProcedureReturn k
  EndProcedure
  
EndModule