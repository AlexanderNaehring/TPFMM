
DeclareModule windowMain
  EnableExplicit
  
  Global window, dialog
    
  Enumeration FormMenu
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      #PB_Menu_Quit
      #PB_Menu_Preferences
      #PB_Menu_About
    CompilerEndIf
    #MenuItem_AddMod
    #MenuItem_ExportList
    #MenuItem_ShowBackups
    #MenuItem_ShowDownloads
    #MenuItem_Homepage
    #MenuItem_License
    #MenuItem_Log
    #MenuItem_Enter
    #MenuItem_CtrlA
    #MenuItem_PackNew
    #MenuItem_PackOpen
  EndEnumeration
  
  
  Enumeration progress
    #Progress_Hide      = -1
    #Progress_NoChange  = -2
  EndEnumeration
  
  Declare create()
  
  Declare stopGUIupdate(stop = #True)
  Declare setColumnWidths(Array widths(1))
  Declare getColumnWidth(column)
  Declare getSelectedMods(List *mods())
  
  Declare progressMod(percent, text$=Chr(1))
  Declare progressRepo(percent, text$=Chr(1))
  
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

Module windowMain
  
  Macro gadget(name)
    DialogGadget(windowMain::dialog, name)
  EndMacro
  
  ; rightclick menu on library gadget
  Global MenuLibrary
  Enumeration FormMenu
    #MenuItem_Information
    #MenuItem_Backup
    #MenuItem_Uninstall
    #MenuItem_ModWebsite
    #MenuItem_ModFolder
    #MenuItem_RepositoryRefresh
    #MenuItem_RepositoryClearCache
    #MenuItem_AddToPack
  EndEnumeration
  
  Enumeration #PB_Event_FirstCustomValue
    #ShowDownloadSelection
  EndEnumeration
  
  
  Global xml ; keep xml dialog in order to manipulate for "selectFiles" dialog
  
  ;- Timer
  Global TimerMainGadgets = 101
  
  ; other stuff
  Global NewMap PreviewImages.i()
  Global _noUpdate
  
  Declare repoDownload()
  Declare modOpenModFolder()
  Declare modInformation()
  Declare backupRefreshList()
  
  Global *modList.CanvasList::CanvasList
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  
  Procedure resize()
    ResizeImage(images::Images("headermain"), WindowWidth(window), 8, #PB_Image_Raw)
    SetGadgetState(gadget("headerMain"), ImageID(images::Images("headermain")))
  EndProcedure
  
  Procedure updateModButtons()
    Protected i, numSelected, numCanUninstall, numCanBackup
    Protected *mod.mods::mod
    Protected text$, author$
    
    If _noUpdate
      ProcedureReturn #False
    EndIf
    
    
    numSelected     = 0
    numCanUninstall = 0
    numCanBackup    = 0
    
    For i = 0 To CountGadgetItems(gadget("modList")) - 1
      *mod = GetGadgetItemData(gadget("modList"), i)
      If Not *mod
        Continue
      EndIf
      
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
        numSelected + 1
        If mods::canUninstall(*mod)
          numCanUninstall + 1
        EndIf
        If mods::canBackup(*mod)
          numCanBackup + 1
        EndIf
      EndIf
    Next
    
    If numSelected = 1
      DisableGadget(gadget("modInfo"), #False)
    Else
      DisableGadget(gadget("modInfo"), #True)
    EndIf
    
    If numCanBackup = 0
      DisableGadget(gadget("modBackup"),  #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Backup, #True)
    Else
      DisableGadget(gadget("modBackup"), #False)
      DisableMenuItem(MenuLibrary, #MenuItem_Backup, #False)
    EndIf
    
    If numCanUninstall = 0
      DisableGadget(gadget("modUninstall"),  #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Uninstall, #True)
    Else
      DisableGadget(gadget("modUninstall"),  #False)
      DisableMenuItem(MenuLibrary, #MenuItem_Uninstall, #False)
    EndIf
    
    If numCanBackup > 1
      SetMenuItemText(MenuLibrary, #MenuItem_Backup,    locale::l("main","backup_pl"))
    Else
      SetMenuItemText(MenuLibrary, #MenuItem_Backup,    locale::l("main","backup"))
    EndIf
    
    If numCanUninstall > 1
      SetMenuItemText(MenuLibrary, #MenuItem_Uninstall, locale::l("main","uninstall_pl"))
    Else
      SetMenuItemText(MenuLibrary, #MenuItem_Uninstall, locale::l("main","uninstall"))
    EndIf
    
    If numSelected = 1
      ; one mod selected
      ; display image
      *mod = GetGadgetItemData(gadget("modList"), GetGadgetState(gadget("modList")))
      
      Protected im
      im = mods::getPreviewImage(*mod)
      If IsImage(im)
        ; display image
        If GetGadgetState(gadget("modPreviewImage")) <> ImageID(im)
          SetGadgetState(gadget("modPreviewImage"), ImageID(im))
        EndIf
      Else
        ; else: display normal logo
        If GetGadgetState(gadget("modPreviewImage")) <> ImageID(images::Images("logo"))
          SetGadgetState(gadget("modPreviewImage"), ImageID(images::Images("logo")))
        EndIf
      EndIf
      
      
      If mods::getRepoMod(*mod)
        DisableGadget(gadget("modUpdate"), #False)
      Else
        DisableGadget(gadget("modUpdate"), #True)
      EndIf
      
      ; website 
      If *mod\url$ Or *mod\aux\tfnetID Or *mod\aux\workshopID
        DisableMenuItem(MenuLibrary, #MenuItem_ModWebsite, #False)
      Else
        DisableMenuItem(MenuLibrary, #MenuItem_ModWebsite, #True)
      EndIf
      
      ; settings
      If ListSize(*mod\settings()) > 0
        DisableGadget(gadget("modSettings"), #False)
      Else
        DisableGadget(gadget("modSettings"), #True)
      EndIf
      
      DisableMenuItem(MenuLibrary, #MenuItem_ModFolder, #False)
    Else
      ; multiple mods or none selected
      
;       DisableGadget(gadget("modSettings"), #True)
      DisableGadget(gadget("modUpdate"), #True)
      
      DisableMenuItem(MenuLibrary, #MenuItem_ModWebsite, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_ModFolder, #True)
      
      
;       If GetGadgetState(gadget("modPreviewImage")) <> ImageID(images::Images("logo"))
;         SetGadgetState(gadget("modPreviewImage"), ImageID(images::Images("logo")))
;       EndIf
    EndIf
    
    If numSelected = 0
      DisableMenuItem(MenuLibrary, #MenuItem_AddToPack, #True)
    Else
      DisableMenuItem(MenuLibrary, #MenuItem_AddToPack, #False)
    EndIf
    
  EndProcedure
  
  Procedure updateRepoButtons()
    Protected numSelected, numCanDownload
    Protected *repoMod.repository::mod
    Protected i
    
    If _noUpdate
      ProcedureReturn #False
    EndIf
    
    numSelected = 0
    numCanDownload = 0
    
    For i = 0 To CountGadgetItems(gadget("repoList")) - 1
      *repoMod = GetGadgetItemData(gadget("repoList"), i)
      If Not *repoMod
        Continue
      EndIf
      
      If GetGadgetItemState(gadget("repoList"), i) & #PB_ListIcon_Selected
        numSelected + 1
        If repository::canDownloadMod(*repoMod)
          numCanDownload + 1
        EndIf
      EndIf
    Next
    
    SetGadgetText(gadget("repoInstall"), locale::l("main", "install"))
    
    If numCanDownload = 1
      DisableGadget(gadget("repoInstall"), #False)
      
      *repoMod = GetGadgetItemData(gadget("repoList"), GetGadgetState(gadget("repoList")))
      If *repoMod\installed
        SetGadgetText(gadget("repoInstall"), locale::l("main", "install_update"))
      EndIf
      
    Else
      DisableGadget(gadget("repoInstall"), #True)
    EndIf
    
    If numSelected = 1
      DisableGadget(gadget("repoWebsite"), #False)
    Else
      DisableGadget(gadget("repoWebsite"), #True)
    EndIf
    
  EndProcedure
  
  Procedure updateBackupButtons()
    Protected item, checked
    Protected gadgetTree
    Debug "windowMain::updateBackupButtons()"
    
    If main::gameDirectory$
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
  
  Procedure close()
    HideWindow(window, #True)
    main::exit()
  EndProcedure
  
  ;-------------------------------------------------
  ;- TIMER
  
  Procedure TimerMain()
    Static LastDir$ = ""
    If EventTimer() = TimerMainGadgets
      
      ; check changed working Directory
      If LastDir$ <> main::gameDirectory$
        Debug "windowMain::timerMain() - Working Directory Changed"
        LastDir$ = main::gameDirectory$
        If misc::checkGameDirectory(main::gameDirectory$) = 0
          ; ok
        Else
          main::gameDirectory$ = ""
          windowSettings::show()
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  ;- MENU
  
  Procedure MenuItemHomepage()
    misc::openLink(main::WEBSITE$) ; Download Page TFMM (Train-Fever.net)
  EndProcedure
  
  Procedure MenuItemLicense()
    Protected TPFMM$, ThirdParty$, About$
    
    TPFMM$ = "Transport Fever Mod Manager (" + main::VERSION$ + ")" + #CRLF$ +
             "Copyright © 2014-"+FormatDate("%yyyy", Date())+" Alexander Nähring" + #CRLF$ +
             "Distributed on https://www.transportfevermods.com/" + #CRLF$ +
             "  and https://www.transportfever.net/"
    
    CompilerSelect #PB_Compiler_OS 
      CompilerCase #PB_OS_Windows
        ThirdParty$ = "Used Third-Party Software:" + #CRLF$ + 
                      "7-Zip Copyright © 1999-2016 Igor Pavlov." + #CRLF$ +
                      "  License: GNU LGPL http://www.gnu.org/" + #CRLF$ +
                      "  unRAR © Alexander Roshal" + #CRLF$ + 
                      "LUA Copyright © 1994-2017 Lua.org, PUC-Rio." + #CRLF$ + 
                      "  License: MIT http://www.opensource.org/licenses/mit-license.html"
        
      CompilerCase #PB_OS_Linux
        ThirdParty$ = "Used Third-Party Software:" + #CRLF$ + 
                      "LUA Copyright © 1994-2017 Lua.org, PUC-Rio." + #CRLF$ + 
                      "  License: MIT http://www.opensource.org/licenses/mit-license.html" + #CRLF$ + 
                      #CRLF$ + 
                      "Additional required packages: zip, unzip, unrar"
        
    CompilerEndSelect
    
    About$ = TPFMM$ + #CRLF$ + #CRLF$ + ThirdParty$
      
    MessageRequester("About", About$, #PB_MessageRequester_Info)
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
  
  Procedure MenuItemExport()
    mods::exportList()
  EndProcedure
  
  Procedure MenuItemEnter()
    If GetActiveGadget() = gadget("repoList")
      repoDownload()
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
  
;   Procedure panel()
;     If EventType() = #PB_EventType_Change
;       If GetGadgetState(gadget("panel")) = 2
;         updateBackupButtons()
;         backupRefreshList()
;       EndIf
;     EndIf
;   EndProcedure
  
  Procedure hideAllContainer()
    HideGadget(Gadget("containerMods"), #True)
    HideGadget(gadget("containerMaps"), #True)
    HideGadget(gadget("containerOnline"), #True)
    HideGadget(gadget("containerBackups"), #True)
    
    SetGadgetState(gadget("btnMods"), 0)
    SetGadgetState(gadget("btnMaps"), 0)
    SetGadgetState(gadget("btnOnline"), 0)
    SetGadgetState(gadget("btnBackups"), 0)
    SetGadgetState(gadget("btnSettings"), 0)
  EndProcedure
  
  Procedure btnMods()
    hideAllContainer()
    HideGadget(gadget("containerMods"), #False)
    SetGadgetState(gadget("btnMods"), 1)
    SetActiveGadget(gadget("modList"))
  EndProcedure
  
  Procedure btnMaps()
    hideAllContainer()
    HideGadget(gadget("containerMaps"), #False)
    SetGadgetState(gadget("btnMaps"), 1)
  EndProcedure
  
  Procedure btnOnline()
    hideAllContainer()
    HideGadget(gadget("containerOnline"), #False)
    SetGadgetState(gadget("btnOnline"), 1)
  EndProcedure
  
  Procedure btnBackups()
    hideAllContainer()
    HideGadget(gadget("containerBackups"), #False)
    SetGadgetState(gadget("btnBackups"), 1)
  EndProcedure
  
  Procedure btnSettings()
    MenuItemSettings()
    SetGadgetState(gadget("btnSettings"), 0)
  EndProcedure
  
  
  ;- mod tab
  
  Procedure modAddNewMod()
    Protected file$
    If FileSize(main::gameDirectory$) <> -2
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
    debugger::Add("windowMain::GadgetButtonUninstall()")
    Protected *mod.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(gadget("modList")) - 1
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected 
        *mod = GetGadgetItemData(gadget("modList"), i)
        If mods::canUninstall(*mod)
          count + 1
        EndIf
      EndIf
    Next i
    If count > 0
      If count = 1
        ClearMap(strings$())
        strings$("name") = *mod\name$
        result = MessageRequester(locale::l("main","uninstall"), locale::getEx("management", "uninstall1", strings$()), #PB_MessageRequester_YesNo)
      Else
        ClearMap(strings$())
        strings$("count") = Str(count)
        result = MessageRequester(locale::l("main","uninstall_pl"), locale::getEx("management", "uninstall2", strings$()), #PB_MessageRequester_YesNo)
      EndIf
      
      If result = #PB_MessageRequester_Yes
        For i = 0 To CountGadgetItems(gadget("modList")) - 1
          If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
            *mod = GetGadgetItemData(gadget("modList"), i)
            If mods::canUninstall(*mod)
;               debugger::add("windowMain::GadgetButtonUninstall() - {"+*mod\name$+"}")
              mods::uninstall(*mod\tpf_id$)
            EndIf
          EndIf
        Next i
      EndIf
    EndIf
  EndProcedure
  
  Procedure modBackup()
    debugger::Add("windowMain::GadgetButtonBackup()")
    
    Protected *mod.mods::mod
    Protected i, count
    Protected backupFolder$
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(gadget("modList")) - 1
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected 
        *mod = GetGadgetItemData(gadget("modList"), i)
        If mods::canBackup(*mod)
          count + 1
        EndIf
      EndIf
    Next i
    If count > 0
      
      For i = 0 To CountGadgetItems(gadget("modList")) - 1
        If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
          *mod = GetGadgetItemData(gadget("modList"), i)
          If mods::canBackup(*mod)
            mods::backup(*mod\tpf_id$)
          EndIf
        EndIf
      Next i
      
    EndIf
  EndProcedure
  
  Procedure modList()
    updateModButtons()
    
    Select EventType()
      Case #PB_EventType_LeftDoubleClick
        modInformation()
      Case #PB_EventType_RightClick
        DisplayPopupMenu(MenuLibrary, WindowID(windowMain::window))
      Case #PB_EventType_DragStart
        DragPrivate(main::#DRAG_MOD)
    EndSelect
  EndProcedure
  
  Procedure websiteTrainFeverNet()
    misc::openLink("http://goo.gl/8Dsb40") ; Homepage (Train-Fever.net)
  EndProcedure
  
  Procedure websiteTrainFeverNetDownloads()
    misc::openLink("http://goo.gl/Q75VIM") ; Downloads / Filebase (Train-Fever.net)
  EndProcedure
  
  Procedure modPreviewImage()
    Protected event = EventType()
    If event = #PB_EventType_LeftClick
      If GetGadgetState(gadget("modPreviewImage")) = ImageID(images::Images("logo"))
        websiteTrainFeverNet()
      EndIf
    EndIf
  EndProcedure
  
  Procedure modUpdateList()
    ; TODO
    ; when filter changed, etc...
    
    ; sort
    *modList\SortItems(CanvasList::#SortByText)
    ; filter
    
  EndProcedure
  
  Procedure modResetFilterMods()
    SetGadgetText(gadget("modFilterString"), "")
    SetActiveGadget(gadget("modFilterString"))
    modUpdateList()
  EndProcedure
  
  Procedure modShowDownloadFolder()
    If main::gameDirectory$
      misc::CreateDirectoryAll(main::gameDirectory$+"TPFMM/download/")
      misc::openLink(main::gameDirectory$+"TPFMM/download/")
    EndIf
  EndProcedure
  
  Procedure modInformation()
    Protected *mod.mods::mod
    
    *mod = GetGadgetItemData(gadget("modList"), GetGadgetState(gadget("modList")))
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    modInformation::modInfoShow(*mod, WindowID(window))
  EndProcedure
  
  Procedure modSettings()
    Protected *mod.mods::mod
    
    *mod = GetGadgetItemData(gadget("modList"), GetGadgetState(gadget("modList")))
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    modSettings::show(*mod, WindowID(window))
  EndProcedure
  
  Procedure modUpdate()
    debugger::add("windowMain::modUpdate()")
    Protected *mod.mods::mod
    Protected i
    
    For i = 0 To CountGadgetItems(gadget("modList"))-1
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
        *mod = GetGadgetItemData(gadget("modList"), i)
        mods::update(*mod\tpf_id$)
      EndIf
    Next
  EndProcedure
  
  Procedure modUpdateAll()
    debugger::add("windowMain::modUpdateAll()")
    Protected *mod.mods::mod
    Protected i
    
    For i = 0 To CountGadgetItems(gadget("modList"))-1
      *mod = GetGadgetItemData(gadget("modList"), i)
      If mods::isUpdateAvailable(*mod)
        mods::update(*mod\tpf_id$)
      EndIf
    Next
  EndProcedure
  
  ;- mod callbacks
  
  Procedure modCallbackNewMod(*mod.mods::mod)
    Debug "##### DISPLAY MOD: "+*mod\tpf_id$
    Protected item
    item = *modList\AddItem(*mod\name$+#LF$+mods::getAuthorsString(*mod))
    *modList\SetItemImage(item, mods::getPreviewImage(*mod))
    *modList\SetItemUserData(item, *mod)
    modUpdateList()
  EndProcedure
  
  Procedure modCallbackRemoveMod(modID$)
    Debug "##### REMOVE MOD: "+modID$
    ; TODO
    modUpdateList()
  EndProcedure
  
  Procedure modCallbackStopDraw(stop)
    Debug "##### STOP DRAW: "+stop
    *modList\SetAttribute(CanvasList::#AttributePauseDraw, stop)
  EndProcedure
  
  ;- repo tab
  
  Procedure repoList()
    updateRepoButtons()
  EndProcedure
  
  Procedure MenuRepoListAuthor()
    Protected selected, *repoMod.repository::mod
    
    selected = GetGadgetState(gadget("repoList"))
    If selected <> -1
      *repoMod = GetGadgetItemData(gadget("repoList"), selected)
    EndIf
    
    If *repoMod
      SetGadgetText(gadget("repoFilterString"), *repoMod\author$)
      SetActiveGadget(gadget("repoFilterString"))
    EndIf
  EndProcedure
  
  Procedure repoListShowMenu()
    Protected selected, *repoMod.repository::mod
    Static menuID
    
    If menuID And IsMenu(MenuID)
      FreeMenu(MenuID)
    EndIf
    
    selected = GetGadgetState(gadget("repoList"))
    If selected <> -1
      *repoMod = GetGadgetItemData(gadget("repoList"), selected)
    EndIf
    
    If *repoMod
      menuID = CreatePopupMenu(#PB_Any)
      Protected NewMap strings$()
      If *repoMod\installed
        MenuItem(5000, locale::l("main", "install_update"))
      Else
        MenuItem(5000, locale::l("main", "install"))
      EndIf
      If Not repository::canDownloadMod(*repoMod)
        DisableMenuItem(menuID, 5000, #True)
      EndIf
      BindMenuEvent(menuID, 5000, @repoDownload())
      
      MenuBar()
      
      strings$("author") = *repoMod\author$
      MenuItem(5001, locale::getEx("repository", "more_author", strings$()))
      BindMenuEvent(menuID, 5001, @MenuRepoListAuthor())
      DisplayPopupMenu(menuID, WindowID(window))
    EndIf
  EndProcedure
  
  Procedure repoResetFilter()
    SetGadgetText(gadget("repoFilterString"), "")
    SetActiveGadget(gadget("repoFilterString"))
  EndProcedure
  
  Procedure repoWebsite()
    Protected item
    Protected *mod.repository::mod
    
    ; currently: only one file at a time! -> only get first selected
    
    ; get selected mod from list:
    item = GetGadgetState(gadget("repoList"))
    If item = -1
      ProcedureReturn #False
    EndIf
    
    *mod = GetGadgetItemData(gadget("repoList"), item)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    If *mod\url$
      misc::openLink(*mod\url$) ; open in browser
    EndIf
  EndProcedure
  
  ; repo download file selection window...
  
  Global dialogSelectFiles
  Global mutexDialogSelectFiles = CreateMutex()
  Global NewMap repoSelectFilesGadget()
  
  Procedure repoSelectFilesClose()
    DisableWindow(window, #False)
    SetActiveWindow(window)
    If dialogSelectFiles And IsDialog(dialogSelectFiles)
      CloseWindow(DialogWindow(dialogSelectFiles))
      FreeDialog(dialogSelectFiles)
    EndIf
    UnlockMutex(mutexDialogSelectFiles)
  EndProcedure
  
  Procedure repoSelectFilesDownload()
    Protected *file.repository::file
    Protected *repo_mod.repository::mod
    If dialogSelectFiles And IsDialog(dialogSelectFiles)
      *repo_mod = GetGadgetData(DialogGadget(dialogSelectFiles, "selectDownload"))
      ; find selected 
      ForEach repoSelectFilesGadget()
        If repoSelectFilesGadget() And IsGadget(repoSelectFilesGadget())
          If GetGadgetState(repoSelectFilesGadget())
            ; init download if selected
            *file = GetGadgetData(repoSelectFilesGadget())
            
            repository::download(*repo_mod\source$, *repo_mod\id, *file\fileID)
          EndIf
        EndIf
      Next
    EndIf
    repoSelectFilesClose()
  EndProcedure
  
  Procedure repoSelectFilesUpdateButtons()
    ForEach repoSelectFilesGadget()
      If repoSelectFilesGadget() And IsGadget(repoSelectFilesGadget())
        If GetGadgetState(repoSelectFilesGadget())
          DisableGadget(DialogGadget(dialogSelectFiles, "selectDownload"), #False)
          ProcedureReturn #True
        EndIf
      EndIf
    Next
    DisableGadget(DialogGadget(dialogSelectFiles, "selectDownload"), #True)
    ProcedureReturn #False
  EndProcedure
  
  Procedure repoDownloadShowSelection(*repo_mod.repository::mod)
    Protected *nodeBase, *node
    Protected *file
    
    If IsDialog(dialogSelectFiles)
      If IsWindow(DialogWindow(dialogSelectFiles))
        CloseWindow(DialogWindow(dialogSelectFiles))
      EndIf
      FreeDialog(dialogSelectFiles)
    EndIf
    
    If IsXML(xml)
      *nodeBase = XMLNodeFromID(xml, "selectBox")
      If *nodeBase
        misc::clearXMLchildren(*nodeBase)
        ; add a checkbox for each file in mod
        ForEach *repo_mod\files()
          *node = CreateXMLNode(*nodeBase, "checkbox", -1)
          If *node
            SetXMLAttribute(*node, "name", Str(*repo_mod\files()))
            SetXMLAttribute(*node, "text", *repo_mod\files()\filename$)
          EndIf
        Next
        
        ; show window now
        dialogSelectFiles = CreateDialog(#PB_Any)
        If dialogSelectFiles And OpenXMLDialog(dialogSelectFiles, xml, "selectFiles", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(window))
          
          ; get gadgets
          ClearMap(repoSelectFilesGadget())
          ForEach *repo_mod\files()
            *file = *repo_mod\files()
            If repository::canDownloadFile(*file)
              repoSelectFilesGadget(Str(*file)) = DialogGadget(dialogSelectFiles, Str(*file))
              SetGadgetData(repoSelectFilesGadget(Str(*file)), *file)
              BindGadgetEvent(repoSelectFilesGadget(Str(*file)), @repoSelectFilesUpdateButtons())
            EndIf
          Next
          
          SetWindowTitle(DialogWindow(dialogSelectFiles), locale::l("main","select_files"))
          SetGadgetText(DialogGadget(dialogSelectFiles, "selectText"), locale::l("main","select_files_text"))
          SetGadgetText(DialogGadget(dialogSelectFiles, "selectCancel"), locale::l("main","cancel"))
          SetGadgetText(DialogGadget(dialogSelectFiles, "selectDownload"), locale::l("main","download"))
          
          RefreshDialog(dialogSelectFiles)
          HideWindow(DialogWindow(dialogSelectFiles), #False, #PB_Window_WindowCentered)
          
          BindGadgetEvent(DialogGadget(dialogSelectFiles, "selectCancel"), @repoSelectFilesClose())
          BindGadgetEvent(DialogGadget(dialogSelectFiles, "selectDownload"), @repoSelectFilesDownload())
          SetGadgetData(DialogGadget(dialogSelectFiles, "selectDownload"), *repo_mod)
          
          DisableGadget(DialogGadget(dialogSelectFiles, "selectDownload"), #True)
          
          BindEvent(#PB_Event_CloseWindow, @repoSelectFilesClose(), DialogWindow(dialogSelectFiles))
          
          DisableWindow(window, #True)
          ProcedureReturn #True
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  Procedure repoEventShowSelection()
    Protected *repoMod
    *repoMod = EventData()
    If *repoMod
      repoDownloadShowSelection(*repoMod)
    EndIf
  EndProcedure
  
  Procedure repoDownload()
    ; download and install mod from source
    Protected item, url$, nFiles
    Protected *repo_mod.repository::mod, *file.repository::file
    Protected download.repository::download
    
    ; currently: only one file at a time! -> only get first selected
    
    ; get selected mod from list:
    item = GetGadgetState(gadget("repoList"))
    If item = -1
      ProcedureReturn #False
    EndIf
    
    *repo_mod = GetGadgetItemData(gadget("repoList"), item)
    If Not *repo_mod
      ProcedureReturn #False
    EndIf
    
    ; check if download is available!
    nFiles = repository::canDownloadMod(*repo_mod)
    If Not nFiles
      ProcedureReturn
    EndIf
    
    ; single file? start download!
    If nFiles = 1
      ForEach *repo_mod\files()
        *file = *repo_mod\files()
        If repository::canDownloadFile(*file) ; search for the single downloadable file
          repository::download(*repo_mod\source$, *repo_mod\id, *file\fileID)
          SetActiveGadget(gadget("repoList"))
          ProcedureReturn #True
        EndIf
      Next
    EndIf
    
    ; more files? show selection window
    
    ; manipulate xml before opening dialog
    repoDownloadShowSelection(*repo_mod)
    
    ProcedureReturn #False
  EndProcedure
  
  Procedure repoRefresh()
    repository::refresh()
  EndProcedure
  
  Procedure repoClearCache()
    repository::clearCache()
    MessageRequester(locale::l("main","repo_clear_title"), locale::l("main","repo_clear_text"), #PB_MessageRequester_Info)
  EndProcedure
  
  ;
  
  Procedure modShowWebsite()
    Protected item, *mod.mods::mod
    item = GetGadgetState(gadget("modList"))
    If item <> -1
      *mod = GetGadgetItemData(gadget("modList"), item)
      If *mod
        If *mod\url$
          misc::openLink(*mod\url$)
        ElseIf *mod\aux\tfnetID
          misc::openLink("https://www.transportfever.net/filebase/index.php/Entry/"+*mod\aux\tfnetID)
        ElseIf *mod\aux\workshopID
          misc::openLink("http://steamcommunity.com/sharedfiles/filedetails/?id="+*mod\aux\workshopID)
        EndIf
        
        ProcedureReturn #True
      EndIf
    EndIf
    ProcedureReturn #True
  EndProcedure
  
  Procedure modOpenModFolder()
    Protected item, *mod.mods::mod
    item = GetGadgetState(gadget("modList"))
    If item <> -1
      *mod = GetGadgetItemData(gadget("modList"), item)
      If *mod 
        misc::openLink(mods::getModFolder(*mod\tpf_id$, *mod\aux\type$))
        ProcedureReturn #True
      EndIf
    EndIf
    ProcedureReturn #True
  EndProcedure
  
  Procedure modAddToPack()
    windowPack::show(window)
    windowPack::addSelectedMods()
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
    
    If main::gameDirectory$ = ""
      ProcedureReturn #False
    EndIf
    
    backupFolder$ = misc::path(main::gameDirectory$+"TPFMM/backups/")
    
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
  
  
  ;- DRAG & DROP
  
  Procedure HandleDroppedFiles()
    Protected count, i
    Protected file$, files$
    
    files$ = EventDropFiles()
    
    debugger::Add("dropped files:")
    count  = CountString(files$, Chr(10)) + 1
    For i = 1 To count
      file$ = StringField(files$, i, Chr(10))
      
      If LCase(GetExtensionPart(file$)) = pack::#EXTENSION
        windowPack::show(window)
        windowPack::packOpen(file$)
      Else
        mods::install(file$)
      EndIf
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
  
  Procedure progressMod(percent, text$=Chr(1))
    Static max
    If max <> 100
      max = 100
      SetGadgetAttribute(gadget("progressModBar"), #PB_ProgressBar_Maximum, max)
    EndIf
    
    If percent = #Progress_Hide
      HideGadget(gadget("progressModBar"), #True)
    Else
      HideGadget(gadget("progressModBar"), #False)
      SetGadgetState(gadget("progressModBar"), percent)
    EndIf
    
    If text$ <> Chr(1)
      SetGadgetText(gadget("progressModText"), text$)
    EndIf
  EndProcedure
  
  Procedure progressRepo(percent, text$=Chr(1))
    Static max
    If max <> 100
      max = 100
      SetGadgetAttribute(gadget("progressRepoBar"), #PB_ProgressBar_Maximum, max)
    EndIf
    
    If percent <> #Progress_NoChange
      If percent = #Progress_Hide
        HideGadget(gadget("progressRepoBar"), #True)
      Else
        HideGadget(gadget("progressRepoBar"), #False)
        SetGadgetState(gadget("progressRepoBar"), percent)
      EndIf
    EndIf
    
    If text$ <> Chr(1)
      SetGadgetText(gadget("progressRepoText"), text$)
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        RefreshDialog(dialog)
        ; causes segmentation violation in Linux
      CompilerEndIf
    EndIf
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create()
    UseModule locale ; import namespace "locale" for shorthand "l()" access
    
    DataSection
      mainDialogXML:
      IncludeBinary "dialogs/main.xml"
      mainDialogXMLend:
    EndDataSection
    
    ; open dialog
    xml = CatchXML(#PB_Any, ?mainDialogXML, ?mainDialogXMLend - ?mainDialogXML)
    If Not xml Or XMLStatus(xml) <> #PB_XML_Success
      MessageRequester("Critical Error", "Could not read window definition!", #PB_MessageRequester_Error)
      End
    EndIf
    
    ; dialog does not take menu height and statusbar height into account
    ; workaround: placeholder node in dialog tree with required offset.
    SetXMLAttribute(XMLNodeFromID(xml, "placeholder"), "margin", "bottom:"+Str(MenuHeight()-8)) ; getStatusBarHeight()
    
    dialog = CreateDialog(#PB_Any)
    If Not dialog Or Not OpenXMLDialog(dialog, xml, "main")
      MessageRequester("Critical Error", "Could not open main window!", #PB_MessageRequester_Error)
      End
    EndIf
    
    window = DialogWindow(dialog)
    
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
    
    ; Set window events & timers
    AddWindowTimer(window, TimerMainGadgets, 100)
    BindEvent(#PB_Event_SizeWindow, @resize(), window)
    BindEvent(#PB_Event_MaximizeWindow, @resize(), window)
    BindEvent(#PB_Event_RestoreWindow, @resize(), window)
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    BindEvent(#PB_Event_Timer, @TimerMain(), window)
    BindEvent(#PB_Event_WindowDrop, @HandleDroppedFiles(), window)
    BindEvent(#ShowDownloadSelection, @repoEventShowSelection())
    
    
    ; init custom canvas gadgets
    *modList = CanvasList::NewCanvasListGadget(#PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, gadget("modList"))
    *modList\AddItemButton(images::Images("iconInfo"), 01)
    *modList\AddItemButton(images::Images("iconFolder"), 0)
    *modList\AddItemButton(images::Images("iconSettings"), 0)
    *modList\AddItemButton(images::Images("iconWebsite"), 0)
    
    
    ; initialize gadgets
;     SetGadgetText(gadget("modFilterFrame"),     l("main","filter"))
;     SetGadgetText(gadget("modFilterHidden"),    l("main","filter_hidden"))
;     SetGadgetText(gadget("modFilterVanilla"),   l("main","filter_vanilla"))
;     SetGadgetText(gadget("modManagementFrame"), l("main","management"))
;     SetGadgetText(gadget("modSettings"),        l("main","settings"))
    
    SetGadgetAttribute(gadget("modFilter"),     #PB_Button_Image, ImageID(images::images("btnFilter")))
    SetGadgetAttribute(gadget("modSort"),       #PB_Button_Image, ImageID(images::images("btnSort")))
    GadgetToolTip(gadget("modFilter"),          l("main","filter"))
    GadgetToolTip(gadget("modSort"),            l("main","sort"))
    
    
    SetGadgetAttribute(gadget("modInfo"),       #PB_Button_Image, ImageID(images::images("btnInfo")))
    SetGadgetAttribute(gadget("modUpdate"),     #PB_Button_Image, ImageID(images::images("btnUpdate")))
    SetGadgetAttribute(gadget("modBackup"),     #PB_Button_Image, ImageID(images::images("btnBackup")))
    SetGadgetAttribute(gadget("modUninstall"),  #PB_Button_Image, ImageID(images::images("btnUninstall")))
    SetGadgetAttribute(gadget("modUpdateAll"),  #PB_Button_Image, ImageID(images::images("btnUpdateAll")))
    GadgetToolTip(gadget("modInfo"),            l("main","information"))
    GadgetToolTip(gadget("modUpdate"),          l("main","update_tip"))
    GadgetToolTip(gadget("modBackup"),          l("main","backup"))
    GadgetToolTip(gadget("modUninstall"),       l("main","uninstall"))
    GadgetToolTip(gadget("modUpdateAll"),       l("main","update_all_tip"))
    
    SetGadgetText(gadget("repoFilterFrame"),    l("main","filter"))
    SetGadgetText(gadget("repoManagementFrame"), l("main","management"))
    SetGadgetText(gadget("repoWebsite"),        l("main","mod_website"))
    SetGadgetText(gadget("repoInstall"),        l("main","install"))
    
    SetGadgetText(gadget("backupFrame"),        l("main","backup_manage"))
;     SetGadgetText(gadget("backupRefresh"),      l("main","backup_refresh"))
    SetGadgetText(gadget("backupRestore"),      l("main","backup_restore"))
    SetGadgetText(gadget("backupDelete"),       l("main","backup_delete"))
    SetGadgetText(gadget("backupFolder"),       l("main","backup_folder"))
    SetGadgetText(gadget("backupExpand"),       l("main","backup_expand"))
    SetGadgetText(gadget("backupCollapse"),     l("main","backup_collapse"))
    SetGadgetText(gadget("backupCheck"),        l("main","backup_check"))
    SetGadgetText(gadget("backupClear"),        l("main","backup_clear"))
    SetGadgetText(gadget("backupFrameFilter"),  l("main","backup_filter"))
    
    SetGadgetAttribute(gadget("btnMods"),     #PB_Button_Image,   ImageID(images::Images("navMods")))
    SetGadgetAttribute(gadget("btnMaps"),     #PB_Button_Image,   ImageID(images::Images("navMaps")))
    SetGadgetAttribute(gadget("btnOnline"),   #PB_Button_Image,   ImageID(images::Images("navOnline")))
    SetGadgetAttribute(gadget("btnBackups"),  #PB_Button_Image,   ImageID(images::Images("navBackups")))
    SetGadgetAttribute(gadget("btnSettings"), #PB_Button_Image,   ImageID(images::Images("navSettings")))
    
    GadgetToolTip(gadget("btnMods"),      l("main","mods"))
    GadgetToolTip(gadget("btnMaps"),      l("main","maps"))
    GadgetToolTip(gadget("btnOnline"),    l("main","repository"))
    GadgetToolTip(gadget("btnBackups"),   l("main","backups"))
    GadgetToolTip(gadget("btnSettings"),  l("menu","settings"))
    
    DisableGadget(gadget("btnMaps"), #True)
    
    ; Bind Gadget Events
;     BindGadgetEvent(gadget("panel"),            @panel())
    BindGadgetEvent(gadget("btnMods"),          @btnMods())
    BindGadgetEvent(gadget("btnMaps"),          @btnMaps())
    BindGadgetEvent(gadget("btnOnline"),        @btnOnline())
    BindGadgetEvent(gadget("btnBackups"),       @btnBackups())
    BindGadgetEvent(gadget("btnSettings"),      @btnSettings())
    
    BindGadgetEvent(gadget("modInfo"),          @modInformation())
;     BindGadgetEvent(gadget("modSettings"),      @modSettings())
    BindGadgetEvent(gadget("modUpdate"),        @modUpdate())
    BindGadgetEvent(gadget("modUpdateAll"),     @modUpdateAll())
    BindGadgetEvent(gadget("modBackup"),        @modBackup())
    BindGadgetEvent(gadget("modUninstall"),     @modUninstall())
    BindGadgetEvent(gadget("modList"),          @modList())
;     BindGadgetEvent(gadget("modFilterString"),  @modUpdateList(), #PB_EventType_Change)
;     BindGadgetEvent(gadget("modFilterReset"),   @modResetFilterMods())
;     BindGadgetEvent(gadget("modFilterHidden"),  @modUpdateList())
;     BindGadgetEvent(gadget("modFilterVanilla"), @modUpdateList())
;     BindGadgetEvent(gadget("modFilterFolder"),  @modUpdateList(), #PB_EventType_Change)
    
    BindGadgetEvent(gadget("repoList"),         @repoList())
    BindGadgetEvent(gadget("repoList"),         @repoListShowMenu(), #PB_EventType_RightClick)
    BindGadgetEvent(gadget("repoFilterReset"),  @repoResetFilter())
    BindGadgetEvent(gadget("repoWebsite"),      @repoWebsite())
    BindGadgetEvent(gadget("repoInstall"),      @repoDownload())
    
    BindGadgetEvent(gadget("backupTree"),       @backupTree())
;     BindGadgetEvent(gadget("backupRefresh"),    @backupRefreshList())
    BindGadgetEvent(gadget("backupRestore"),    @backupRestore())
    BindGadgetEvent(gadget("backupDelete"),     @backupDelete())
    BindGadgetEvent(gadget("backupFolder"),     @backupFolder())
    BindGadgetEvent(gadget("backupExpand"),     @backupExpand())
    BindGadgetEvent(gadget("backupCollapse"),   @backupCollapse())
    BindGadgetEvent(gadget("backupCheck"),      @backupCheck())
    BindGadgetEvent(gadget("backupClear"),      @backupClear())
    BindGadgetEvent(gadget("backupFilter"),     @backupRefreshList())
    BindGadgetEvent(gadget("backupFilterReset"),  @backupFilterReset())
    
    
    ; create shortcuts
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
    
    ; Menu
    CreateMenu(0, WindowID(window))
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      MenuTitle(l("menu","file"))
    CompilerEndIf
    MenuItem(#PB_Menu_Preferences, l("menu","settings") + Chr(9) + "Ctrl + P")
    MenuItem(#PB_Menu_Quit, l("menu","close") + Chr(9) + "Alt + F4")
    MenuTitle(l("menu","mods"))
    MenuItem(#MenuItem_AddMod, l("menu","mod_add") + Chr(9) + "Ctrl + O")
    MenuItem(#MenuItem_ExportList, l("menu","mod_export"))
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
    MenuItem(#PB_Menu_About, l("menu","license") + Chr(9) + "Ctrl + L")
    MenuItem(#MenuItem_Log, l("menu","log"))
    
    ; Menu Events
    BindMenuEvent(0, #PB_Menu_Preferences, @MenuItemSettings())
    BindMenuEvent(0, #PB_Menu_Quit, main::@exit())
    BindMenuEvent(0, #MenuItem_AddMod, @modAddNewMod())
    BindMenuEvent(0, #MenuItem_ExportList, @MenuItemExport())
    BindMenuEvent(0, #MenuItem_ShowBackups, @backupFolder())
    BindMenuEvent(0, #MenuItem_ShowDownloads, @modShowDownloadFolder())
    BindMenuEvent(0, #MenuItem_RepositoryRefresh, @repoRefresh())
    BindMenuEvent(0, #MenuItem_RepositoryClearCache, @repoClearCache())
    BindMenuEvent(0, #MenuItem_Homepage, @MenuItemHomepage())
    BindMenuEvent(0, #PB_Menu_About, @MenuItemLicense())
    BindMenuEvent(0, #MenuItem_Log, @MenuItemLog())
    BindMenuEvent(0, #MenuItem_Enter, @MenuItemEnter())
    BindMenuEvent(0, #MenuItem_CtrlA, @MenuItemSelectAll())
    BindMenuEvent(0, #MenuItem_PackNew, @MenuItemPackNew())
    BindMenuEvent(0, #MenuItem_PackOpen, @MenuItemPackOpen())
    
    SetGadgetText(gadget("version"), main::VERSION$)
    
    ; OS specific
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        SetWindowTitle(window, GetWindowTitle(window) + " for Windows")
      CompilerCase #PB_OS_Linux
        SetWindowTitle(window, GetWindowTitle(window) + " for Linux")
      CompilerCase #PB_OS_MacOS
        SetWindowTitle(window, GetWindowTitle(window) + " for MacOS")
    CompilerEndSelect
    
    
    ; indicate testmode in window title
    If main::_TESTMODE
      SetWindowTitle(window, GetWindowTitle(window) + " (Test Mode Enabled)")
    EndIf
    
    ; fonts...
    Protected fontMono = LoadFont(#PB_Any, "Courier", misc::getDefaultFontSize())
;     SetGadgetFont(gadget("backupTree"), FontID(fontMono))
    
    
    ; load images
    ResizeImage(images::Images("headermain"), GadgetWidth(gadget("headerMain")), GadgetHeight(gadget("headerMain")), #PB_Image_Raw)
    SetGadgetState(gadget("headerMain"), ImageID(images::Images("headermain")))
;     SetGadgetState(gadget("modPreviewImage"), ImageID(images::Images("logo")))
    
    
    ; right click menu on mod item
    MenuLibrary = CreatePopupImageMenu(#PB_Any)
    MenuItem(#MenuItem_ModFolder, l("main","open_folder"))
    MenuItem(#MenuItem_Backup, l("main","backup"), ImageID(images::Images("icon_backup")))
    MenuItem(#MenuItem_Uninstall, l("main","uninstall"), ImageID(images::Images("no")))
    MenuBar()
    MenuItem(#MenuItem_AddToPack, l("main","add_to_pack"), ImageID(images::Images("share")))
    MenuBar()
    MenuItem(#MenuItem_ModWebsite, l("main", "mod_website"))
    
    
    ;AddKeyboardShortcut(window, #PB_Shortcut_Delete, #MenuItem_Uninstall) ; should only work when gadget is active!
    
    BindMenuEvent(MenuLibrary, #MenuItem_ModFolder, @modOpenModFolder())
    BindMenuEvent(MenuLibrary, #MenuItem_Backup, @modBackup())
    BindMenuEvent(MenuLibrary, #MenuItem_Uninstall, @modUninstall())
    BindMenuEvent(MenuLibrary, #MenuItem_ModWebsite, @modShowWebsite())
    BindMenuEvent(MenuLibrary, #MenuItem_AddToPack, @modAddToPack())
    
    ; Drag & Drop
    EnableWindowDrop(window, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
    
    ; mod module
    mods::BindEventCallback(mods::#CallbackNewMod, @modCallbackNewMod())
    mods::BindEventCallback(mods::#CallbackRemoveMod, @modCallbackRemoveMod())
    mods::BindEventCallback(mods::#CallbackStopDraw, @modCallbackStopDraw())
    
    
    ; register to repository module
    Protected json$, *json
    Protected Dim columns.repository::column(0)
    json$ = ReplaceString("[{'name':'name','width':320},"+
                          "{'name':'author_name','width':100},"+
                          "{'name':'version','width':60}]", "'", #DQUOTE$)
    *json = ParseJSON(#PB_Any, json$)
    ExtractJSONArray(JSONValue(*json), columns())
    FreeJSON(*json)
    
    repository::registerWindow(window)
    repository::registerListGadget(gadget("repoList"), columns())
    repository::registerThumbGadget(gadget("repoPreviewImage"))
    repository::registerFilterGadgets(gadget("repoFilterString"), gadget("repoFilterTypes"), gadget("repoFilterSources"), gadget("repoFilterInstalled"))
    
    repository::init() ; only starts thread -> returns quickly
    
    
    ; init gui texts and button states
    updateModButtons()
    updateRepoButtons()
    updateBackupButtons()
    
    ; apply sizes
    RefreshDialog(dialog)
    resize()
    btnMods()
    
    UnuseModule locale
  EndProcedure
  
  Procedure stopGUIupdate(stop = #True)
    _noUpdate = stop
  EndProcedure
  
  Procedure setColumnWidths(Array widths(1))
    Protected i
    For i = 0 To ArraySize(widths())
      If widths(i)
        SetGadgetItemAttribute(gadget("modList"), #PB_Any, #PB_Explorer_ColumnWidth, widths(i), i)
      EndIf
    Next
  EndProcedure
  
  Procedure getColumnWidth(column)
    ProcedureReturn GetGadgetItemAttribute(gadget("modList"), #PB_Any, #PB_Explorer_ColumnWidth, column)
  EndProcedure
  
  Structure findModStruct
    source$
    id.q
    fileID.q
  EndStructure
  
  Procedure repoFindModAndDownloadThread(*buffer.findModStruct)
    Protected source$, id.q, fileID.q
    
    source$ = *buffer\source$
    id      = *buffer\id
    fileID  = *buffer\fileID
    FreeStructure(*buffer)
    
    While Not repository::_READY
      ; wait for repository to be loaded before starting download
      Delay(100)
    Wend
    
    If source$ And id
      ; if not fileID and canDownloadMod > 1  ==> show file selection window!
      ; else -> start download
      
      If Not fileID And repository::canDownloadModByID(source$, id) > 1
        Protected *repoMod.repository::mod
        *repoMod = repository::getModByID(source$, id)
        If *repoMod
          ; cannot directly call "repoDownloadShowSelection()" as this procedure is not called in the main thread!
          ; send event to main window to open the selection
          LockMutex(mutexDialogSelectFiles)
          PostEvent(#ShowDownloadSelection, window, 0, #ShowDownloadSelection, *repoMod)
        EndIf
      Else
        repository::download(source$, id, fileID)
      EndIf
    Else
      debugger::add("windowMain::repoFindModAndDownload("+source$+", "+id+", "+fileID+") - ERROR")
    EndIf
    
  EndProcedure
  
  Procedure repoFindModAndDownload(link$)
    ; search for a mod in repo and initiate download
    
    Protected *buffer.findModStruct
    *buffer = AllocateStructure(findModStruct)
    
    *buffer\source$ =     StringField(link$, 1, "/")
    *buffer\id      = Val(StringField(link$, 2, "/"))
    *buffer\fileID  = Val(StringField(link$, 3, "/"))
    
    ; start in thread in order to wait for repository to finish
    CreateThread(@repoFindModAndDownloadThread(), *buffer)
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