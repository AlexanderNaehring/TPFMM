
DeclareModule windowMain
  EnableExplicit
  
  Global window
  
  Enumeration progress
    #Progress_Hide      = -1
    #Progress_NoChange  = -2
  EndEnumeration
  
  Declare start()
  
  Declare getSelectedMods(List *mods())
  Declare repoFindModAndDownload(link$)
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

Module windowMain
  UseModule debugger
  
  ;{ Structures
  Structure dialog
    dialog.i
    window.i
  EndStructure
  
  Structure fileSelectionDialog
    dialog.i
    window.i
    Map repoSelectFilesGadget.i()
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
    #MenuItem_PackNew
    #MenuItem_PackOpen
    
    #MenuItem_ShareSelected
    #MenuItem_ShareFiltered
    #MenuItem_ShareAll
    
    #MenuItem_Information
    #MenuItem_Backup
    #MenuItem_Uninstall
    #MenuItem_ModWebsite
    #MenuItem_ModFolder
    #MenuItem_RepositoryRefresh
    #MenuItem_RepositoryClearCache
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
         repoFilter.dialog, repoSort.dialog
  Global menu, menuShare
  Global currentTab
  
  ;- Timer
  Global TimerMain = 101
  
  ; other stuff
  Declare backupRefreshList()
  
  Global *modList.CanvasList::CanvasList
  Global *repoList.CanvasList::CanvasList
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
    Protected item, checked
    Protected gadgetTree
    
    If settings::getString("", "path")
      gadgetTree = gadget("backupTree")
      For item = 0 To CountGadgetItems(gadgetTree) - 1
        If GetGadgetItemAttribute(gadgetTree, item, #PB_Tree_SubLevel) = 1
          If GetGadgetItemState(gadgetTree, item) & #PB_Tree_Checked
            checked + 1
          EndIf
        EndIf
      Next
      
      DisableGadget(gadget("backupTree"), #False)
      DisableGadget(gadget("backupFolder"), #False)
      
      DisableGadget(gadget("backupRestore"), Bool(Not checked))
      DisableGadget(gadget("backupDelete"), Bool(Not checked))
      
    Else
      
      DisableGadget(gadget("backupTree"), #True)
      DisableGadget(gadget("backupRestore"), #True)
      DisableGadget(gadget("backupDelete"), #True)
      DisableGadget(gadget("backupFolder"), #True)
    EndIf
    
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
    
    main::setProgressPercent(15)
    main::setProgressText(locale::l("progress", "close"))
    
    settings::setInteger("window", "x", WindowX(windowMain::window, #PB_Window_FrameCoordinate))
    settings::setInteger("window", "y", WindowY(windowMain::window, #PB_Window_FrameCoordinate))
    settings::setInteger("window", "width", WindowWidth(windowMain::window))
    settings::setInteger("window", "height", WindowHeight(windowMain::window))
    
    settings::setInteger("window", "tab", currentTab)
    
    main::setProgressPercent(30)
    main::setProgressText(locale::l("progress", "stop_worker"))
    deb("windowMain:: stop workers")
    mods::stopQueue()
    main::setProgressPercent(45)
    wget::freeAll()
    repository::stopQueue()
    
    main::setProgressPercent(60)
    main::setProgressText(locale::l("progress", "save_list"))
    mods::saveList()
    
    main::setProgressPercent(75)
    main::setProgressText(locale::l("progress", "cleanup"))
    deb("windowMain:: cleanup")
    mods::freeAll()
    main::setProgressPercent(90)
    repository::freeAll()
    
    main::setProgressPercent(99)
    main::setProgressText(locale::l("progress", "goodbye"))
    
    ; free all dialogs
    FreeDialog(modFilter\dialog)
    FreeDialog(modSort\dialog)
    FreeDialog(repoFilter\dialog)
    FreeDialog(repoSort\dialog)
    windowSettings::close()
    
    main::closeProgressWindow()
    PostEvent(event) ; inform main thread that closure procedure is finished
  EndProcedure
  
  Procedure close()
    deb("windowMain:: close window")
    ; the exit procedure will run in a thread and wait for all workers to finish etc...
    main::showProgressWindow(locale::l("progress", "close"), #EventCloseNow)
    CreateThread(@closeThread(), #EventCloseNow)
    ; todo also set up a timer event to close programm after (e.g.) 1 minute if cleanup procedure fails?
  EndProcedure
  
  ;- start procedure
  
  Procedure startThread(EventOnFinish)
    Protected i
    
    main::setProgressText(locale::l("progress", "init"))
    main::setProgressPercent(0)
    
    ; read gameDirectory from preferences
    deb("main:: - game directory: "+settings::getString("", "path"))
    
    If misc::checkGameDirectory(settings::getString("", "path"), main::_TESTMODE) <> 0
      deb("main:: game directory not correct")
      settings::setString("", "path", "")
    EndIf
    
    main::setProgressPercent(10)
    
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
      Else
        
        deb("main:: window location not valid")
        windowWidth = #PB_Ignore
        windowHeight = #PB_Ignore
        
        deb("main:: center main window on primary desktop")
        windowX = (DesktopWidth(0)  - windowWidth ) /2
        windowY = (DesktopHeight(0) - windowHeight) /2
      EndIf
    EndIf
    ;}
    
    ; select tab
    Select settings::getInteger("window", "tab")
      Case #TabOnline
        navBtnOnline()
      Case #TabBackup
        navBtnBackups()
      Case #TabSaves
        navBtnSaves()
    EndSelect
    
    
    main::setProgressPercent(20)
    
    ; load mods and repository
    If settings::getString("", "path")
      main::setProgressText(locale::l("progress", "load_mods"))
      mods::load(#False)
      main::setProgressPercent(50)
      
      
      main::setProgressText(locale::l("progress", "load_repo"))
      repository::refreshRepositories(#False)
      main::setProgressPercent(80)
    EndIf
    
    main::setProgressPercent(90)
    
    ; parameter handling
    For i = 0 To CountProgramParameters() - 1
      main::handleParameter(ProgramParameter(i))
    Next
    
    main::setProgressPercent(99)
    
    ; show main window
    main::closeProgressWindow()
    HideWindow(windowMain::window, #False)
    
    
    If settings::getString("", "path") = ""
      ; no path specified upon program start -> open settings dialog
      deb("main:: no game directory defined - open settings dialog")
      ; post event to show settings
      windowSettings::show()
    EndIf
    
    
  EndProcedure
  
  Procedure start()
    Protected i
    
    If Not main::isMainThread()
      deb("windowMain:: start() not in main thread!")
      RaiseError(#PB_OnError_Breakpoint)
    EndIf
    
    ; open main window and bind events
    create() 
    
    ; open settings window
    windowSettings::create(window)
    
    
    ; startup procedure
    main::showProgressWindow(locale::l("progress", "start"), #EventCloseNow)
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
  
  ; ---
  
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
    misc::openLink(main::WEBSITE$) ; Download Page TFMM (Train-Fever.net)
  EndProcedure
  
  Procedure MenuItemLog()
    ; show log file
    Protected log$, file$, file
    ; write log to tmp file as default Windows notepad will not open the active .log file while it is being used by TPFMM
    log$ = debugger::getLog()
    file$ = misc::path(GetTemporaryDirectory())+"tpfmm-log.txt"
    file = CreateFile(#PB_Any, file$, #PB_File_SharedWrite)
    If file
      WriteString(file, log$)
      CloseFile(file)
      misc::openLink(file$)
    EndIf
  EndProcedure
  
  Procedure MenuItemSettings() ; open settings window
    windowSettings::show()
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
    MenuItemSettings()
    SetGadgetState(gadget("btnSettings"), 0)
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
    
    file$ = OpenFileRequester(locale::l("management","select_mod"), settings::getString("", "last_file"), locale::l("management","files_archive")+"|"+types$+"|"+locale::l("management","files_all")+"|*.*", 0, #PB_Requester_MultiSelection)
    
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
    Protected NewMap strings$()
    
    If *modList\GetAllSelectedItems(*items())
      ForEach *items()
        *mod = *items()\GetUserData()
        If *mod\canUninstall()
          count + 1
          strings$("name") = *mod\getName()
        EndIf
      Next
    EndIf
    
    If count > 0
      If count = 1
        result = MessageRequester(locale::l("main","uninstall"), locale::getEx("management", "uninstall1", strings$()), #PB_MessageRequester_YesNo)
      Else
        ClearMap(strings$())
        strings$("count") = Str(count)
        result = MessageRequester(locale::l("main","uninstall_pl"), locale::getEx("management", "uninstall2", strings$()), #PB_MessageRequester_YesNo)
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
  
  Procedure modResetFilterMods()
    deb("windowMain:: modResetFilterMods()")
    SetGadgetText(gadget("modFilterString"), "")
    SetActiveGadget(gadget("modFilterString"))
  EndProcedure
  
  Procedure modFilterClose()
;     deb("windowMain:: modFilterClose()")
    HideWindow(modFilter\window, #True)
    SetActiveWindow(window)
    PostEvent(#PB_Event_Repaint, window, 0)
    SetActiveGadget(gadget("modList"))
  EndProcedure
  
  Procedure modFilterCallback(*item.CanvasList::CanvasListItem, options)
    ; return true if this mod shall be displayed, false if hidden
    Protected *mod.mods::LocalMod = *item\GetUserData()
    Protected string$, s$, i, n
    
    ; TODO tf mod support not implemented
    
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
    settings::setInteger("modFilter", "tf",       GetGadgetState(DialogGadget(modfilter\dialog, "modFilterTF")))
    settings::setInteger("modFilter", "vanilla",  GetGadgetState(DialogGadget(modfilter\dialog, "modFilterVanilla")))
    settings::setInteger("modFilter", "hidden",   GetGadgetState(DialogGadget(modfilter\dialog, "modFilterHidden")))
    settings::setInteger("modFilter", "workshop", GetGadgetState(DialogGadget(modfilter\dialog, "modFilterWorkshop")))
    settings::setInteger("modFilter", "staging",  GetGadgetState(DialogGadget(modfilter\dialog, "modFilterStaging")))
    
    ; opt 1) gather the "filter options" here (read gadget state and save to some filter flag variable"
    ; opt 2) trigger filtering, and let the filter callback read the gadget states.
    ; use opt 2:
    *modList\FilterItems(@modFilterCallback(), 0, #True)
  EndProcedure
  
  Procedure modFilterShow()
;     deb("windowMain:: modFilterShow()")
    ResizeWindow(modFilter\window, DesktopMouseX()-WindowWidth(modFilter\window)+5, DesktopMouseY()-5, #PB_Ignore, #PB_Ignore)
    HideWindow(modFilter\window, #False)
    SetActiveGadget(DialogGadget(modFilter\dialog, "modFilterString"))
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      SendMessage_(GadgetID(DialogGadget(modfilter\dialog, "modFilterString")), #EM_SETSEL, 0, -1)
    CompilerEndIf
  EndProcedure
  
  ;- mod sort dialog
  
  Procedure modSortClose()
;     deb("windowMain:: modSortClose()")
    HideWindow(modSort\window, #True)
    SetActiveWindow(window)
;     PostEvent(#PB_Event_Repaint, window, 0)
    SetActiveGadget(gadget("modList"))
  EndProcedure
  
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
    modSortClose()
  EndProcedure
  
  Procedure modSortShow()
;     deb("windowMain:: modSortShow()")
    ResizeWindow(modSort\window, DesktopMouseX()-WindowWidth(modSort\window)+5, DesktopMouseY()-5, #PB_Ignore, #PB_Ignore)
    HideWindow(modSort\window, #False)
    SetActiveGadget(DialogGadget(modFilter\dialog, "modSortBox"))
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
  
  
  ;- mod callbacks
  Procedure modItemSetup(*item.CanvasList::CanvasListItem, *mod.mods::LocalMod = #Null)
    Protected icon
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
    
    ; add callbacks
    *item\ClearButtons()
    *item\AddButton(@modIconInfo(),     images::Images("itemBtnInfo"), images::images("itemBtnInfoHover"), images::images("itemBtnInfoDisabled"))
    *item\AddButton(@modIconFolder(),   images::Images("itemBtnFolder"), images::images("itemBtnFolderHover"), images::images("itemBtnFolderDisabled"))
    If *mod\hasSettings()
      *item\AddButton(@modIconSettings(), images::Images("itemBtnSettings"), images::images("itemBtnSettingsHover"), images::images("itemBtnSettingsDisabled"))
    Else
      *item\AddButton(#Null, images::Images("itemBtnSettings"), images::images("itemBtnSettingsHover"), images::images("itemBtnSettingsDisabled"))
    EndIf
    If repoMod And updateAvailable
      *item\AddButton(@modIconUpdate(), images::Images("itemBtnUpdate"), images::images("itemBtnUpdateHover"), images::images("itemBtnUpdateDisabled"))
    Else
      *item\AddButton(#Null, images::Images("itemBtnUpdate"), images::images("itemBtnUpdateHover"), images::images("itemBtnUpdateDisabled"))
    EndIf
    *item\AddButton(@modIconWebsite(),  images::Images("itemBtnWebsite"), images::images("itemBtnWebsiteHover"), images::images("itemBtnWebsiteDisabled"))
    
    ; icons
    *item\ClearIcons()
    ; folder icon
    If *mod\isVanilla()
      icon = images::images("itemIcon_vanilla")
    ElseIf *mod\isWorkshop()
      icon = images::images("itemIcon_workshop")
    ElseIf *mod\isStagingArea()
      ; todo staging area mod icon?
      icon = images::images("itemIcon_mod")
    Else
      icon = images::images("itemIcon_mod")
    EndIf
    *item\AddIcon(icon)
    ; settings icon
    If *mod\hasSettings()
      *item\AddIcon(images::images("itemIcon_settings"))
    Else
      *item\AddIcon(images::images("itemIcon_blank"))
    EndIf
    ; update icon
    If repoMod
      If updateAvailable
        *item\AddIcon(images::images("itemIcon_updateAvailable"))
      Else
        *item\AddIcon(images::images("itemIcon_up2date"))
      EndIf
    Else
      *item\AddIcon(images::images("itemIcon_blank"))
    EndIf
    
    *modList\redraw() ; after all icons and buttons are added, redraw the gadget
    ProcedureReturn #True
  EndProcedure
  
  Procedure modCallbackNewMod(*mod.mods::LocalMod)
    Protected *item.CanvasList::CanvasListItem
    
    *item = *modList\AddItem(*mod\getName()+#LF$+*mod\getAuthorsString()+#LF$+"ID: "+*mod\getID()+", Folder: "+*mod\getFoldername()+", "+FormatDate("Installed on %yyyy/%mm/%dd", *mod\getInstallDate()), *mod)
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
    *modList\GetAllItems(*items())
  EndProcedure
  
  Procedure modCallbackStopDraw(stop)
    *modList\SetAttribute(CanvasList::#AttributePauseDraw, stop)
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
        DragPrivate(main::#DRAG_MOD)
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
  Global modShareHTML$
  misc::BinaryAsString("html/mods.html", modShareHTML$)
  
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
    file$ = SaveFileRequester(locale::l("management", "export_list"), settings::getString("export", "last"), "HTML|*.html", 0)
    If file$ = ""
      ProcedureReturn #False
    EndIf
    
    If LCase(GetExtensionPart(file$)) <> "html"
      file$ = file$ + ".html"
    EndIf
    settings::setString("export", "last", file$)
    
    If FileSize(file$) > 0
      If Not MessageRequester(locale::l("management", "export_list"), locale::l("management", "overwrite_file"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
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
    html$ = ReplaceString(html$, "{title}", locale::l("share", "title"), #PB_String_CaseSensitive, 1, 1)
    html$ = ReplaceString(html$, "{copyright}", locale::l("share", "copyright"), #PB_String_CaseSensitive, 1, 1)
    html$ = ReplaceString(html$, "{date}", FormatDate("%yyyy-%mm-%dd", Date()), #PB_String_CaseSensitive, 1, 1)
    html$ = ReplaceString(html$, "{TPFMM-version}", main::VERSION$, #PB_String_CaseSensitive, 1, 1)
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
  
  ;tbd
  
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
  
  ; repo filter dialog
  
  Procedure repoFilterClose()
    HideWindow(repoFilter\window, #True)
    SetActiveWindow(window)
;     PostEvent(#PB_Event_Repaint, window, 0)
    SetActiveGadget(gadget("repoList"))
  EndProcedure
  
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
    
    ; opt 1) gather the "filter options" here: read gadget state and save to some filter flag variable
    ; opt 2) trigger filtering, and let the filter callback read the gadget states.
    ; use opt 2: (window must stay open)
    *repoList\FilterItems(@repoFilterCallback(), 0, #True)
  EndProcedure
  
  Procedure repoFilterReset()
    SetGadgetText(DialogGadget(repofilter\dialog, "filterString"), "")
    SetActiveGadget(DialogGadget(repofilter\dialog, "filterString"))
  EndProcedure
  
  Procedure repoFilterShow()
    ResizeWindow(repoFilter\window, DesktopMouseX()-WindowWidth(repoFilter\window)+5, DesktopMouseY()-5, #PB_Ignore, #PB_Ignore)
    HideWindow(repoFilter\window, #False)
    SetActiveGadget(DialogGadget(repoFilter\dialog, "filterString"))
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      SendMessage_(GadgetID(DialogGadget(repoFilter\dialog, "filterString")), #EM_SETSEL, 0, -1)
    CompilerEndIf
  EndProcedure
  
  ; repo sort dialog
  
  Procedure repoSortClose()
    HideWindow(repoSort\window, #True)
    SetActiveWindow(window)
    PostEvent(#PB_Event_Repaint, window, 0)
    SetActiveGadget(gadget("repoList"))
  EndProcedure
  
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
    modSortClose()
  EndProcedure
  
  Procedure repoSortShow()
    ResizeWindow(repoSort\window, DesktopMouseX()-WindowWidth(repoSort\window)+5, DesktopMouseY()-5, #PB_Ignore, #PB_Ignore)
    HideWindow(repoSort\window, #False)
    SetActiveGadget(DialogGadget(repoFilter\dialog, "modSortBox"))
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
    
    ; load preview image (slow)
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
      *item\AddIcon(images::images("itemIcon_"+*mod\getSource()))
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
      *item\AddIcon(images::images("itemIcon_installed"))
    Else
      *item\AddIcon(images::images("itemIcon_blank"))
    EndIf
    
    
    ; buttons
    *item\AddButton(@repoItemDownload(), images::images("itemBtnDownload"), images::images("itemBtnDownloadHover"), images::images("itemBtnDownloadDisabled"))
    *item\AddButton(@repoItemWebsite(), images::images("itemBtnWebsite"), images::images("itemBtnWebsiteHover"), images::images("itemBtnWebsiteDisabled"))
    
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
    *repoList\ClearItems()
    ; TODO repoCallbackClearList() - update mod list (remove all update information from mods)
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
    PostEvent(#EventRepoRefreshFinished)
  EndProcedure
  
  Procedure repoCallbackThumbnail(image, *userdata)
    Debug "repoCallbackThumbnail("+image+", "+*userdata+")"
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
            
            SetWindowTitle(DialogWindow(*dialog\dialog), locale::l("main","select_files"))
            SetGadgetText(DialogGadget(*dialog\dialog, "selectText"), locale::l("main","select_files_text"))
            SetGadgetText(DialogGadget(*dialog\dialog, "selectCancel"), locale::l("main","cancel"))
            SetGadgetText(DialogGadget(*dialog\dialog, "selectDownload"), locale::l("main","download"))
            
            
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
  
  Procedure saveOpenFile(file$)
    Protected *tfsave.tfsave::tfsave
    Protected *item.CanvasList::CanvasListItem
    Protected download.b
    
    ; free old data if available
    *tfsave = *saveModList\GetUserData()
    If *tfsave
      FreeStructure(*tfsave)
    EndIf
    *saveModList\ClearItems()
    *tfsave = tfsave::readInfo(file$)
    
    If *tfsave
      *saveModList\SetUserData(*tfsave)
      SetGadgetText(gadget("saveName"), locale::l("save", "save")+": "+GetFilePart(file$, #PB_FileSystem_NoExtension))
      
      SetGadgetText(gadget("saveYear"), Str(*tfsave\startYear))
      SetGadgetText(gadget("saveDifficulty"), locale::l("save", "difficulty"+Str(*tfsave\difficulty)))
      SetGadgetText(gadget("saveMapSize"), Str(*tfsave\numTilesX/4)+" km × "+Str(*tfsave\numTilesY/4)+" km")
      SetGadgetText(gadget("saveMoney"), "$"+StrF(*tfsave\money/1000000, 2)+" Mio")
      SetGadgetText(gadget("saveFileSize"), misc::printSize(*tfsave\fileSize))
      SetGadgetText(gadget("saveFileSizeUncompressed"), misc::printSize(*tfsave\fileSizeUncompressed))
      
      If ListSize(*tfsave\mods())
        ForEach *tfsave\mods()
          *item = *saveModList\AddItem(*tfsave\mods()\name$+#LF$+"ID: "+*tfsave\mods()\id$, *tfsave\mods())
          ; the "major version" (e.g. _1) is not saved in the "ID".
          ; e.g. mod "urbangames_vehicles_no_end_year" may be version _0, _1, _2, ...
          ; must check version independend
          
          *tfsave\mods()\localmod = mods::getModByFoldername(*tfsave\mods()\id$)
          *tfsave\mods()\repofile = repository::getFileByFoldername(*tfsave\mods()\id$)
          
          If *tfsave\mods()\localmod
            *item\AddIcon(images::images("itemIcon_installed"))
          Else
            *item\AddIcon(images::images("itemIcon_notInstalled"))
          EndIf
          If *tfsave\mods()\repofile
            *item\AddIcon(images::images("itemIcon_availableOnline"))
            download = #True
          Else
            *item\AddIcon(images::images("itemIcon_notAvailableOnline"))
          EndIf
        Next
        If download
          DisableGadget(gadget("saveDownload"), #False)
        EndIf
      Else
        *saveModList\AddItem(locale::l("save", "no_mods"))
        DisableGadget(gadget("saveDownload"), #True)
      EndIf
    Else
      DisableGadget(gadget("saveDownload"), #True)
      
      SetGadgetText(gadget("saveYear"), " ")
      SetGadgetText(gadget("saveDifficulty"), " ")
      SetGadgetText(gadget("saveMapSize"), " ")
      SetGadgetText(gadget("saveMoney"), " ")
      SetGadgetText(gadget("saveFileSize"), " ")
      SetGadgetText(gadget("saveFileSizeUncompressed"), " ")
      *saveModList\AddItem(locale::l("save", "error"))
    EndIf
  EndProcedure
  
  Procedure saveOpen()
    ; open a new savegame
    Protected file$
    
    file$ = OpenFileRequester(locale::l("save", "open_title"), settings::getString("save", "last"), "*.sav", 0)
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
        ;TODO: save full info in userdata, also check if file is installed before downloading!
        *tfsaveMod = *items()\GetUserData()
        If *tfsaveMod\repofile And Not *tfsaveMod\localmod
          deb("windowMain:: download missing mod '"+*tfsaveMod\id$+"'")
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
  
  Procedure backupTree()
    Protected item, level, i, gadget, checked, state, state2
    
    ; update checked items...
    If EventType() = #PB_EventType_LeftClick
      ; the _current_ item was changed!
      gadget = EventGadget()
      ; get current item:
      item = GetGadgetState(gadget)
      If item <> -1
        state = GetGadgetItemState(gadget, item)
        state & #PB_Tree_Checked
        
        level = GetGadgetItemAttribute(gadget, item, #PB_Tree_SubLevel)
        If level = 0
          ; top level item -> apply state to all lower level items
          ; iterate to next items until an item with same level is found
          For i = item + 1 To CountGadgetItems(gadget) - 1
            If GetGadgetItemAttribute(gadget, i, #PB_Tree_SubLevel) = level
              Break
            EndIf
            ; apply parent "state" to all child items:
            SetGadgetItemState(gadget, i, state) ; checked or 0
          Next
        ElseIf level = 1
          ; lower level -> check state of sibling items and apply corresponding state to parent item
          ; iterate down to end of this level
          For i = item To CountGadgetItems(gadget) - 1
            If GetGadgetItemAttribute(gadget, i, #PB_Tree_SubLevel) < level ; found another high level item
              i - 1
              Break
            EndIf
          Next
          If i > (CountGadgetItems(gadget) - 1)
            i = CountGadgetItems(gadget) - 1
          EndIf
          
          ; i is now the last item of this sublevel
          ; iterate "up" to parent and check the states while 
          For i = i To 0 Step -1
            If GetGadgetItemAttribute(gadget, i, #PB_Tree_SubLevel) < level
              Break
            EndIf
            
            state2 = GetGadgetItemState(gadget, i)
            If (state & #PB_Tree_Checked And Not state2 & #PB_Tree_Checked) Or
               (state2 & #PB_Tree_Checked And Not state & #PB_Tree_Checked)
              state = #PB_Tree_Inbetween
;             ElseIf state & #PB_Tree_Checked And state2 & #PB_Tree_Checked And i <> item
;               ; set all other sublevel items that are checked to inbetween
;               SetGadgetItemState(gadget, i , #PB_Tree_Inbetween)
            EndIf
          Next
          SetGadgetItemState(gadget, i, state)
        EndIf
      EndIf
    EndIf
    
    updateBackupButtons()
    
  EndProcedure
  
  Procedure backupRestore()
    Protected gadget, item
    Protected *buffer.mods::backupInfoLocal
    Protected backupFolder$
    
    If settings::getString("", "path") = ""
      ProcedureReturn #False
    EndIf
    
    backupFolder$ = mods::getBackupFolder()
    
    gadget = gadget("backupTree")
    ; iterate all items, only use the first checked item of sublevel 1,
    ; then wait For the Next level 0 item befor accepting new items form level 1
    For item = 0 To CountGadgetItems(gadget) - 1
      If GetGadgetItemAttribute(gadget, item, #PB_Tree_SubLevel) = 1
        If GetGadgetItemState(gadget, item) & #PB_Tree_Checked
          ; use this item!
          *buffer = GetGadgetItemData(gadget, item)
          If *buffer
            mods::install(backupFolder$ + PeekS(*buffer))
          EndIf
          
          
          ; skip following level 1 items and skip to next level 0 item
          For item = item To CountGadgetItems(gadget) - 1
            If GetGadgetItemAttribute(gadget, item, #PB_Tree_SubLevel) = 0
              Break
            EndIf
          Next
        EndIf
      EndIf
    Next
    
  EndProcedure
  
  Procedure backupDelete()
    Protected gadget, item
    Protected *buffer, file$
    
    gadget = gadget("backupTree")
    For item = 0 To CountGadgetItems(gadget) - 1
      If GetGadgetItemState(gadget, item) & #PB_Tree_Checked
        *buffer = GetGadgetItemData(gadget, item)
        If *buffer
          file$ = PeekS(*buffer)
          mods::backupDelete(file$)
        EndIf
      EndIf
    Next
    
    backupRefreshList()
  EndProcedure
  
  Procedure backupFolder()
    misc::openLink(mods::getBackupFolder())
  EndProcedure
  
  Procedure backupExpand()
    Protected gadget, item, state
    
    gadget = gadget("backupTree")
    For item = 0 To CountGadgetItems(gadget)
      state = GetGadgetItemState(gadget, item)
      If state & #PB_Tree_Collapsed
        state ! #PB_Tree_Collapsed
        state | #PB_Tree_Expanded
        SetGadgetItemState(gadget, item, state)
      EndIf
    Next
  EndProcedure
  
  Procedure backupCollapse()
    Protected gadget, item, state
    gadget = gadget("backupTree")
    For item = 0 To CountGadgetItems(gadget)
      state = GetGadgetItemState(gadget, item)
      If state & #PB_Tree_Expanded
        state ! #PB_Tree_Expanded
        state | #PB_Tree_Collapsed
        SetGadgetItemState(gadget, item, state)
      EndIf
    Next
  EndProcedure
  
  Procedure backupCheck()
    Protected gadget, item
    gadget = gadget("backupTree")
    For item = 0 To CountGadgetItems(gadget)
      SetGadgetItemState(gadget, item, #PB_Tree_Checked)
    Next
    updateBackupButtons()
  EndProcedure
  
  Procedure backupClear()
    Protected gadget, item
    gadget = gadget("backupTree")
    For item = 0 To CountGadgetItems(gadget)
      SetGadgetItemState(gadget, item, 0)
    Next
    updateBackupButtons()
  EndProcedure
  
  Procedure backupRefreshList()
    Protected NewList allBackups.mods::backupInfoLocal()
    Protected NewList tpf_id$()
    Protected NewList someBackups.mods::backupInfoLocal()
    Protected found, item
    Protected text$, filter$
    Protected *buffer
    
    Debug "windowMain::backupRefreshList()"
    
    For item = 0 To CountGadgetItems(gadget("backupTree")) - 1
      *buffer = GetGadgetItemData(gadget("backupTree"), item)
      If *buffer
        FreeMemory(*buffer)
      EndIf
    Next
    
    ClearGadgetItems(gadget("backupTree"))
    item = 0
    
    filter$ = GetGadgetText(gadget("backupFilter"))
    
    If mods::getBackupList(allBackups(), filter$)
      ; create individual lists for each tpf_id, sorted by date.
      
      ; first: extract the tpf_ids
      ForEach allBackups()
        ; check if the tpf_id of this backup is already in list...
        found = #False
        ForEach tpf_id$()
          If tpf_id$() = allBackups()\tpf_id$
            ; already in list
            found = #True
            Break
          EndIf
        Next
        ; if not: add to list
        If Not found
          AddElement(tpf_id$())
          tpf_id$() = allBackups()\tpf_id$
        EndIf
      Next
      
      ; second: order all tpf_id by name
      SortList(tpf_id$(), #PB_Sort_Ascending|#PB_Sort_NoCase)
      
      ; third: iterate all tpf_id and display all backups with this ID sorted by date
      ForEach tpf_id$()
        ; find all backups with this tpf_id
        ClearList(someBackups())
        ForEach allBackups()
          If allBackups()\tpf_id$ = tpf_id$()
            AddElement(someBackups())
            ; copy values to temporary list
            someBackups() = allBackups()
          EndIf
        Next
        
        ; sort someBackups by date (newest first)
        SortStructuredList(someBackups(), #PB_Sort_Descending, OffsetOf(mods::backupInfoLocal\time), TypeOf(mods::backupInfoLocal\time))
        
        ; add top level entry to tree gadget
        If ListSize(someBackups()) = 1
          text$ = someBackups()\name$ 
          If someBackups()\version$
            text$ + " v" + someBackups()\version$
          EndIf
          text$ + Space(4) + "(" +  misc::printSize(someBackups()\size) + ")"
        Else
          text$ = "" + ListSize(someBackups()) + " " + locale::l("main","backup_files")
        EndIf
        AddGadgetItem(gadget("backupTree"), item, text$, 0, 0)
;         If someBackups()\installed
;           SetGadgetItemColor(gadget("backupTree"), item, #PB_Gadget_FrontColor, RGB($00, $66, $00))
;         Else
;           SetGadgetItemColor(gadget("backupTree"), item, #PB_Gadget_FrontColor, RGB($66, $00, $00))
;         EndIf
        item + 1
        
        ; add entry for each backup
        ForEach someBackups()
          With someBackups()
            text$ = \name$
            If \version$
              text$ + " v" + \version$
            EndIf
            text$ + " (" +  misc::printSize(\size) + ")"
            If \time
              text$ = "[" + FormatDate("%dd.%mm. %hh:%ii", \time) + "] " + text$
            EndIf
            
            ; remember the filename for later actions (restore, delete)
            ; memory must be freed manually!!!
            *buffer = AllocateMemory(StringByteLength(\filename$) + SizeOf(character))
            PokeS(*buffer, \filename$)
            
            AddGadgetItem(gadget("backupTree"), item, text$, 0, 1)
            SetGadgetItemData(gadget("backupTree"), item, *buffer)
            If ListSize(someBackups()) > 1 And ListIndex(someBackups()) = 0
              SetGadgetItemState(gadget("backupTree"), item-1, #PB_Tree_Expanded)
            EndIf
            item + 1
          EndWith
        Next
      Next
    EndIf
    
  EndProcedure
  
  Procedure backupFilterReset()
    SetGadgetText(gadget("backupFilter"), "")
    backupRefreshList()
  EndProcedure
  
  ;- shortcuts
  
  Procedure shortcutCtrlF()
    Select currentTab
      Case #TabMods
        modFilterShow()
      Case #TabOnline
        repoFilterShow()
    EndSelect
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
  
  ;- dialogs
  
  Procedure modFilterDialog()
    modFilter\dialog = CreateDialog(#PB_Any)
    If Not modFilter\dialog Or Not OpenXMLDialog(modFilter\dialog, xml, "modFilter", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(window))
      MessageRequester("Critical Error", "Could not open filter dialog!", #PB_MessageRequester_Error)
      End
    EndIf
    modFilter\window = DialogWindow(modFilter\dialog)
    BindEvent(#PB_Event_CloseWindow, @modFilterClose(), modFilter\window)
    BindEvent(#PB_Event_DeactivateWindow, @modFilterClose(), modFilter\window)
    AddKeyboardShortcut(modFilter\window, #PB_Shortcut_Return, #PB_Event_CloseWindow)
    AddKeyboardShortcut(modFilter\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
    BindEvent(#PB_Event_Menu, @modFilterClose(), modFilter\window, #PB_Event_CloseWindow)
    SetGadgetText(DialogGadget(modFilter\dialog, "modFilterString"), "")
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterTF"), settings::getInteger("modFilter", "tf"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterVanilla"), settings::getInteger("modFilter", "vanilla"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterHidden"), settings::getInteger("modFilter", "hidden"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterWorkshop"), settings::getInteger("modFilter", "workshop"))
    SetGadgetState(DialogGadget(modFilter\dialog, "modFilterStaging"), settings::getInteger("modFilter", "staging"))
    ; bind events
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterString"), @modFilterChange(), #PB_EventType_Change)
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterTF"), @modFilterChange())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterVanilla"), @modFilterChange())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterHidden"), @modFilterChange())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterWorkshop"), @modFilterChange())
    BindGadgetEvent(DialogGadget(modFilter\dialog, "modFilterStaging"), @modFilterChange())
    ; apply initial filtering
    modFilterChange()
  EndProcedure
  
  Procedure modSortDialog()
    modSort\dialog = CreateDialog(#PB_Any)
    If Not modSort\dialog Or Not OpenXMLDialog(modSort\dialog, xml, "modSort", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(window))
      MessageRequester("Critical Error", "Could not open sort dialog!", #PB_MessageRequester_Error)
      End
    EndIf
    modSort\window = DialogWindow(modSort\dialog)
    ; bind window events
    BindEvent(#PB_Event_CloseWindow, @modSortClose(), modSort\window)
    BindEvent(#PB_Event_DeactivateWindow, @modSortClose(), modSort\window)
    ; use window menu for keyboard shortcuts
    AddKeyboardShortcut(modSort\window, #PB_Shortcut_Return, #PB_Event_CloseWindow)
    AddKeyboardShortcut(modSort\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
    BindEvent(#PB_Event_Menu, @modSortClose(), modSort\window, #PB_Event_CloseWindow)
    ; sorting options
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, "Mod Name")
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, "Author Name")
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, "Installation Date")
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, "Folder Size")
    AddGadgetItem(DialogGadget(modSort\dialog, "sortBox"), -1, "Folder Name")
    SetGadgetState(DialogGadget(modSort\dialog, "sortBox"), 0)
    RefreshDialog(modSort\dialog)
    BindGadgetEvent(DialogGadget(modSort\dialog, "sortBox"), @modSortChange())
    ; load settings
    SetGadgetState(DialogGadget(modSort\dialog, "sortBox"), settings::getInteger("modSort", "mode"))
    ; apply initial sorting
    modSortChange()
  EndProcedure
  
  Procedure repoFilterDialog()
    repoFilter\dialog = CreateDialog(#PB_Any)
    If Not repoFilter\dialog Or Not OpenXMLDialog(repoFilter\dialog, xml, "repoFilter", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(window))
      MessageRequester("Critical Error", "Could not open repo filter dialog!", #PB_MessageRequester_Error)
      End
    EndIf
    repoFilter\window = DialogWindow(repoFilter\dialog)
    BindEvent(#PB_Event_CloseWindow, @repoFilterClose(), repoFilter\window)
    BindEvent(#PB_Event_DeactivateWindow, @repoFilterClose(), repoFilter\window)
    AddKeyboardShortcut(repoFilter\window, #PB_Shortcut_Return, #PB_Event_CloseWindow)
    AddKeyboardShortcut(repoFilter\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
    BindEvent(#PB_Event_Menu, @repoFilterClose(), repoFilter\window, #PB_Event_CloseWindow)
    SetGadgetText(DialogGadget(repoFilter\dialog, "filterString"), "")
    ; dynamically add available sources!
    ; bind events
    BindGadgetEvent(DialogGadget(repoFilter\dialog, "filterString"), @repoFilterChange(), #PB_EventType_Change)
    BindGadgetEvent(DialogGadget(repoFilter\dialog, "filterDate"), @repoFilterChange(), #PB_EventType_Change)
;     BindGadgetEvent(DialogGadget(repoFilter\dialog, "filterReset"), @repoFilterReset())
    ; apply initial filtering
    modFilterChange()
    
  EndProcedure
  
  Procedure repoSortDialog()
    repoSort\dialog = CreateDialog(#PB_Any)
    If Not repoSort\dialog Or Not OpenXMLDialog(repoSort\dialog, xml, "repoSort", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(window))
      MessageRequester("Critical Error", "Could not open sort dialog!", #PB_MessageRequester_Error)
      End
    EndIf
    repoSort\window = DialogWindow(repoSort\dialog)
    ; bind window events
    BindEvent(#PB_Event_CloseWindow, @repoSortClose(), repoSort\window)
    BindEvent(#PB_Event_DeactivateWindow, @repoSortClose(), repoSort\window)
    ; use window menu for keyboard shortcuts
    AddKeyboardShortcut(repoSort\window, #PB_Shortcut_Return, #PB_Event_CloseWindow)
    AddKeyboardShortcut(repoSort\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
    BindEvent(#PB_Event_Menu, @repoSortClose(), repoSort\window, #PB_Event_CloseWindow)
    ; sorting options
    AddGadgetItem(DialogGadget(repoSort\dialog, "sortBox"), -1, "Last Update")
    AddGadgetItem(DialogGadget(repoSort\dialog, "sortBox"), -1, "Mod Name")
    SetGadgetState(DialogGadget(repoSort\dialog, "sortBox"), 0)
    RefreshDialog(repoSort\dialog)
    BindGadgetEvent(DialogGadget(repoSort\dialog, "sortBox"), @repoSortChange())
    ; load settings
    SetGadgetState(DialogGadget(repoSort\dialog, "sortBox"), settings::getInteger("repoSort", "mode"))
    ; apply initial sorting
    repoSortChange()
  EndProcedure
  
  ; - strings
  
  Procedure updateStrings()
    UseModule locale
    ; nav
    GadgetToolTip(gadget("btnMods"),      l("main","mods"))
    GadgetToolTip(gadget("btnMaps"),      l("main","maps"))
    GadgetToolTip(gadget("btnOnline"),    l("main","repository"))
    GadgetToolTip(gadget("btnBackups"),   l("main","backups"))
    GadgetToolTip(gadget("btnSaves"),     l("main","saves"))
    GadgetToolTip(gadget("btnSettings"),  l("menu","settings"))
    GadgetToolTip(gadget("btnHelp"),      l("main","help"))
    
    ; mod tab
    GadgetToolTip(gadget("modFilter"),          l("main","filter"))
    GadgetToolTip(gadget("modSort"),            l("main","sort"))
    GadgetToolTip(gadget("modUpdate"),          l("main","update_tip"))
    GadgetToolTip(gadget("modBackup"),          l("main","backup"))
    GadgetToolTip(gadget("modUninstall"),       l("main","uninstall"))
    GadgetToolTip(gadget("modUpdateAll"),       l("main","update_all_tip"))
    
    ; repo tab
    GadgetToolTip(gadget("repoFilter"),         l("main","filter"))
    GadgetToolTip(gadget("repoSort"),           l("main","sort"))
    GadgetToolTip(gadget("repoDownload"),       l("main","download"))
    GadgetToolTip(gadget("repoWebsite"),        l("main","website"))
    
    ; backup tab
    SetGadgetText(gadget("backupFrame"),        l("main","backup_manage"))
    SetGadgetText(gadget("backupRestore"),      l("main","backup_restore"))
    SetGadgetText(gadget("backupDelete"),       l("main","backup_delete"))
    SetGadgetText(gadget("backupFolder"),       l("main","backup_folder"))
    SetGadgetText(gadget("backupExpand"),       l("main","backup_expand"))
    SetGadgetText(gadget("backupCollapse"),     l("main","backup_collapse"))
    SetGadgetText(gadget("backupCheck"),        l("main","backup_check"))
    SetGadgetText(gadget("backupClear"),        l("main","backup_clear"))
    SetGadgetText(gadget("backupFrameFilter"),  l("main","backup_filter"))
    
    ; saves tab
    *saveModList\SetEmptyScreen(l("main", "save_click_open"), "")
    SetGadgetText(gadget("saveName"),           l("main","save_start")+":")
    GadgetToolTip(gadget("saveOpen"),           l("main","save_open")+":")
    GadgetToolTip(gadget("saveDownload"),       l("main","save_download")+":")
    SetGadgetText(gadget("saveLabelYear"),      l("save", "year")+":")
    SetGadgetText(gadget("saveLabelDifficulty"),l("save", "difficulty")+":")
    SetGadgetText(gadget("saveLabelMapSize"),   l("save", "mapsize")+":")
    SetGadgetText(gadget("saveLabelMoney"),     l("save", "money")+":")
    SetGadgetText(gadget("saveLabelFileSize"),  l("save", "filesize")+":")
    SetGadgetText(gadget("saveLabelFileSizeUncompressed"),  l("save", "filesize_uncompressed")+":")
    
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
    
    
    ;- custom canvas gadgets
    Protected theme$
    
    *modList = CanvasList::NewCanvasListGadget(#PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, gadget("modList"))
    *modList\BindItemEvent(#PB_EventType_LeftDoubleClick,   @modListItemEvent())
    *modList\BindItemEvent(#PB_EventType_Change,            @modListItemEvent())
    
    *repoList = CanvasList::NewCanvasListGadget(#PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, gadget("repoList"))
    *repoList\BindItemEvent(CanvasList::#OnItemFirstVisible, @repoEventItemVisible()) ; dynamically load images when items get visible
    *repoList\BindItemEvent(#PB_EventType_LeftDoubleClick,   @repoListItemEvent())
    *repoList\BindItemEvent(#PB_EventType_Change,            @repoListItemEvent())
    
    *saveModList = CanvasList::NewCanvasListGadget(#PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, gadget("saveModList"))
    misc::BinaryAsString("theme/saveModList.json", theme$)
    *saveModList\SetTheme(theme$)
    
    ;- worker animation
    *workerAnimation = animation::new()
    *workerAnimation\setCanvas(gadget("workerCanvas"))
    *workerAnimation\setBackgroundColor(misc::GetWindowBackgroundColor(WindowID(window)))
    *workerAnimation\setInterval(1000/60)
    *workerAnimation\loadAni("images/logo/logo.ani")
    *workerAnimation\draw(0) ; draw first frame
    BindEvent(#EventWorkerStarts, @workerStart())
    BindEvent(#EventWorkerStops, @workerStop())
    
    
    ;- initialize gadget images
    SetGadgetText(gadget("version"), main::VERSION$)
    
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
    
    ; saves tab
    SetGadgetAttribute(gadget("saveOpen"),      #PB_Button_Image, ImageID(images::images("btnOpen")))
    SetGadgetAttribute(gadget("saveDownload"),  #PB_Button_Image, ImageID(images::images("btnDownload")))
    SetGadgetFont(gadget("saveName"), FontID(fontBig))
    SetGadgetColor(gadget("saveName"), #PB_Gadget_FrontColor, $42332a);$63472F) ; #2F4763
    DisableGadget(gadget("saveDownload"), #True)

    
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
    
    ; backup tab
    BindGadgetEvent(gadget("backupTree"),       @backupTree())
    BindGadgetEvent(gadget("backupRestore"),    @backupRestore())
    BindGadgetEvent(gadget("backupDelete"),     @backupDelete())
    BindGadgetEvent(gadget("backupFolder"),     @backupFolder())
    BindGadgetEvent(gadget("backupExpand"),     @backupExpand())
    BindGadgetEvent(gadget("backupCollapse"),   @backupCollapse())
    BindGadgetEvent(gadget("backupCheck"),      @backupCheck())
    BindGadgetEvent(gadget("backupClear"),      @backupClear())
    BindGadgetEvent(gadget("backupFilter"),     @backupRefreshList())
    BindGadgetEvent(gadget("backupFilterReset"),  @backupFilterReset())
    
    ; saves tab
    BindGadgetEvent(gadget("saveModList"), @saveModListEvent())
    BindGadgetEvent(gadget("saveOpen"), @saveOpen())
    BindGadgetEvent(gadget("saveDownload"), @saveDownload())
    
    
    ;- Menu
    menu = CreateMenu(#PB_Any, WindowID(window))
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      MenuTitle(l("menu","file"))
    CompilerEndIf
    MenuItem(#PB_Menu_Preferences, l("menu","settings") + Chr(9) + "Ctrl + P")
    MenuItem(#PB_Menu_Quit, l("menu","close") + Chr(9) + "Alt + F4")
    MenuTitle(l("menu","mods"))
    MenuItem(#MenuItem_AddMod, l("menu","mod_add") + Chr(9) + "Ctrl + O")
;     MenuItem(#MenuItem_, l("menu","mod_export"))
    MenuBar()
    MenuItem(#MenuItem_ShowBackups, l("menu","show_backups"))
    MenuItem(#MenuItem_ShowDownloads, l("menu","show_downloads"))
    MenuTitle(l("menu","pack"))
    MenuItem(#MenuItem_PackNew, l("menu","pack_new"))
    MenuItem(#MenuItem_PackOpen, l("menu","pack_open"))
    MenuTitle(l("menu","repository"))
    MenuItem(#MenuItem_RepositoryRefresh, l("menu","repo_refresh"))
    MenuItem(#MenuItem_RepositoryClearCache, l("menu","repo_clear"))
    MenuTitle(l("menu","about"))
    MenuItem(#MenuItem_Homepage, l("menu","homepage") + Chr(9) + "F1")
;     MenuItem(#PB_Menu_About, l("menu","license") + Chr(9) + "Ctrl + L")
    MenuItem(#MenuItem_Log, l("menu","log"))
    
    
    BindMenuEvent(menu, #PB_Menu_Preferences, @MenuItemSettings())
    BindMenuEvent(menu, #PB_Menu_Quit, @close())
    BindMenuEvent(menu, #MenuItem_AddMod, @modAddNewMod())
    BindMenuEvent(menu, #MenuItem_ShowBackups, @backupFolder())
    BindMenuEvent(menu, #MenuItem_ShowDownloads, @modShowDownloadFolder())
    BindMenuEvent(menu, #MenuItem_Homepage, @MenuItemHomepage())
    BindMenuEvent(menu, #MenuItem_Log, @MenuItemLog())
    BindMenuEvent(menu, #MenuItem_PackNew, @MenuItemPackNew())
    BindMenuEvent(menu, #MenuItem_PackOpen, @MenuItemPackOpen())
    
    
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
      MenuItem(#MenuItem_ShareSelected, l("menu", "share_selected"))
      MenuItem(#MenuItem_ShareFiltered, l("menu", "share_filtered"))
      MenuItem(#MenuItem_ShareAll,      l("menu", "share_all"))
      
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
    
    
    ; repository module
    repository::BindEventCallback(repository::#EventAddMods, @repoCallbackAddMods())
    repository::BindEventCallback(repository::#EventClearMods, @repoCallbackClearList())
    repository::BindEventCallback(repository::#EventRefreshFinished, @repoCallbackRefreshFinished())
    repository::BindEventPost(repository::#EventShowModFileSelection, #EventRepoModFileSelection, @repoShowModFileSelection())
    repository::BindEventPost(repository::#EventProgress, #EventRepoProgress, @repoEventProgress())
    repository::BindEventPost(repository::#EventWorkerStarts, #EventWorkerStarts, #Null) ; worker events already linked
    repository::BindEventPost(repository::#EventWorkerStops, #EventWorkerStops, #Null)
    
    
    ;------ open dialogs (sort / filter / ...)
    modFilterDialog()
    modSortDialog()
    repoFilterDialog()
    repoSortDialog()
    
    ;---
    ;- init gui texts and button states
    updateModButtons()
    updateRepoButtons()
    updateBackupButtons()
    
    ; apply sizes
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