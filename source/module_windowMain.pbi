
XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowSettings.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_mods.h.pbi"
XIncludeFile "module_repository.h.pbi"

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
    #MenuItem_Homepage
    #MenuItem_License
  EndEnumeration
  
  Declare create()
  
  Declare stopGUIupdate(stop = #True)
  Declare setColumnWidths(Array widths(1))
  Declare getColumnWidth(column)
  
  Declare progressBar(value, max=-1, text$=Chr(1))
  Declare progressDownload(percent.d)
  
EndDeclareModule

Module windowMain

  ; rightclick menu on library gadget
  Global MenuLibrary
  Enumeration FormMenu
    #MenuItem_Information
    #MenuItem_Backup
    #MenuItem_Uninstall
  EndEnumeration
  
  ;- Gadgets
  Global NewMap gadget()
  
  ;- Timer
  Global TimerMainGadgets = 101
  
  ; other stuff
  Global NewMap PreviewImages.i()
  Global _noUpdate
  
  Declare resize()
  Declare updateGUI()
  
  Declare MenuItemSettings()
  Declare MenuItemHomepage()
  Declare MenuItemLicense()
  Declare MenuItemExport()
  
  Declare GadgetNewMod()
  Declare GadgetLibraryMods()
  Declare GadgetImageMain()
  Declare GadgetButtonStartGame()
  Declare GadgetButtonTrainFeverNetDownloads()
  Declare GadgetButtonInstall()
  Declare GadgetButtonUninstall()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  
  Procedure resize()
    ResizeImage(images::Images("headermain"), GadgetWidth(gadget("headerMain")), 8, #PB_Image_Raw)
    SetGadgetState(gadget("headerMain"), ImageID(images::Images("headermain")))
  EndProcedure
  
  Procedure updateGUI()
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
      *mod = ListIcon::GetListItemData(gadget("modList"), i)
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
    
    DisableGadget(gadget("modInformation"), #True) ;- not yet implemented
;     If numSelected = 0
;       DisableGadget(GadgetButtonInfomation, #True)
;     Else
;       DisableGadget(GadgetButtonInfomation, #False)
;     EndIf
    
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
      SetGadgetText(gadget("modBackup"),     locale::l("main","backup_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_Backup,    locale::l("main","backup_pl"))
    Else
      SetGadgetText(gadget("modBackup"),     locale::l("main","backup"))
      SetMenuItemText(MenuLibrary, #MenuItem_Backup,    locale::l("main","backup"))
    EndIf
    
    If numCanUninstall > 1
      SetGadgetText(gadget("modUninstall"),  locale::l("main","uninstall_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_Uninstall, locale::l("main","uninstall_pl"))
    Else
      SetGadgetText(gadget("modUninstall"),  locale::l("main","uninstall"))
      SetMenuItemText(MenuLibrary, #MenuItem_Uninstall, locale::l("main","uninstall"))
    EndIf
    
    If numSelected = 1
      ; one mod selected
      ; display image
      *mod = ListIcon::GetListItemData(gadget("modList"), GetGadgetState(gadget("modList")))
      
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
    Else
      If GetGadgetState(gadget("modPreviewImage")) <> ImageID(images::Images("logo"))
        SetGadgetState(gadget("modPreviewImage"), ImageID(images::Images("logo")))
      EndIf
    EndIf
    
  EndProcedure
  
  Procedure close()
    HideWindow(window, #True)
    main::exit()
  EndProcedure
  
  Procedure loadRepositoryThread(*dummy)
    repository::loadRepositoryList()
    repository::displayMods("") ; initially fill list
  EndProcedure
  
  ;-------------------------------------------------
  ;- TIMER
  
  Procedure TimerMain()
    Static LastDir$ = ""
    If EventTimer() = TimerMainGadgets
      
      ; check changed working Directory
      If LastDir$ <> main::gameDirectory$
        Debug "Working Directory Changed"
        LastDir$ = main::gameDirectory$
        If misc::checkGameDirectory(main::gameDirectory$) = 0
          main::ready = #True
        Else
          main::ready = #False  ; flag for mod management
          windowSettings::show()
        EndIf
      EndIf
      
      ; working queue
      queue::update()
    EndIf
  EndProcedure
  
  ;- MENU
  
  Procedure MenuItemHomepage()
    misc::openLink("https://www.transportfevermods.com/") ; Download Page TFMM (Train-Fever.net)
  EndProcedure
  
  Procedure MenuItemNewMod()
    GadgetNewMod()
  EndProcedure
  
  Procedure MenuItemLicense()
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      MessageRequester("License",
                       "Transport Fever Mod Manager" + #CRLF$ +
                       main::VERSION$ + #CRLF$ +
                       "© "+FormatDate("%yyyy", Date())+" Alexander Nähring" + #CRLF$ +
                       "Distributed on https://www.transportfevermods.com/" +  #CRLF$ +
                       "unrar © Alexander L. Roshal")
    CompilerElse
      MessageRequester("License",
                       "Transport Fever Mod Manager" + #CRLF$ +
                       main::VERSION$ + #CRLF$ +
                       "© "+FormatDate("%yyyy", Date())+" Alexander Nähring" + #CRLF$ +
                       "Distributed on https://www.transportfevermods.com/")
    CompilerEndIf
  EndProcedure
  
  Procedure MenuItemSettings() ; open settings window
    windowSettings::show()
  EndProcedure
  
  Procedure MenuItemExport()
    mods::exportList()
  EndProcedure
  
  ;- GADGETS
      
  Procedure GadgetNewMod()
    Protected file$
    If FileSize(main::gameDirectory$) <> -2
      ProcedureReturn #False
    EndIf
    file$ = OpenFileRequester(locale::l("management","select_mod"), "", locale::l("management","files_archive")+"|*.zip;*.rar|"+locale::l("management","files_all")+"|*.*", 0, #PB_Requester_MultiSelection)
    While file$
      If FileSize(file$) > 0
        queue::add(queue::#QueueActionInstall, file$)
      EndIf
      file$ = NextSelectedFileName()
    Wend
  EndProcedure

  Procedure GadgetButtonInstall() ; install new mod from repository (online)
    debugger::Add("windowMain::GadgetButtonInstall")
    
  EndProcedure
  
  Procedure GadgetButtonUninstall() ; Uninstall selected mods (delete from HDD)
    debugger::Add("windowMain::GadgetButtonUninstall()")
    Protected *mod.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(gadget("modList")) - 1
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(gadget("modList"), i)
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
            *mod = ListIcon::GetListItemData(gadget("modList"), i)
            If mods::canUninstall(*mod)
;               debugger::add("windowMain::GadgetButtonUninstall() - {"+*mod\name$+"}")
              queue::add(queue::#QueueActionUninstall, *mod\tpf_id$)
            EndIf
          EndIf
        Next i
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetButtonBackup()
    debugger::Add("windowMain::GadgetButtonBackup()")
    
    Protected *mod.mods::mod
    Protected i, count
    Protected backupFolder$
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(gadget("modList")) - 1
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(gadget("modList"), i)
        If mods::canBackup(*mod)
          count + 1
        EndIf
      EndIf
    Next i
    If count > 0
      backupFolder$ = misc::path(main::gameDirectory$+"/TPFMM/backups/")
      misc::CreateDirectoryAll(backupFolder$)
      
      OpenPreferences(main::settingsFile$)
      backupFolder$ = ReadPreferenceString("backupFolder", backupFolder$)
      ClosePreferences()
      
;       backupFolder$ = PathRequester(locale::l("management", "backup"), backupFolder$)
;       If backupFolder$ = ""
;         ProcedureReturn #False
;       EndIf
      
      If FileSize(backupFolder$) <> -2
        debugger::add("windowMain::GadgetButtonBackup() - ERROR: selected folder {"+backupFolder$+"} does not exist")
        ProcedureReturn #False
      EndIf
      
      OpenPreferences(main::settingsFile$)
      WritePreferenceString("backupFolder", backupFolder$)
      ClosePreferences()
      
      For i = 0 To CountGadgetItems(gadget("modList")) - 1
        If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
          *mod = ListIcon::GetListItemData(gadget("modList"), i)
          If mods::canBackup(*mod)
            queue::add(queue::#QueueActionBackup, *mod\tpf_id$, backupFolder$)
          EndIf
        EndIf
      Next i
      
    EndIf
  EndProcedure
  
  Procedure GadgetButtonInfomation()
    Protected *mod.mods::mod
    
    *mod = ListIcon::GetListItemData(gadget("modList"), GetGadgetState(gadget("modList")))
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    debugger::add("windowMain::GadgetButtonInformation() - show information of mod {"+*mod\tpf_id$+"}")
  EndProcedure
  
  Procedure GadgetLibraryMods()
    Protected *mod.mods::mod
    Protected position, event
    
    updateGUI()
    
    Select EventType()
      Case #PB_EventType_LeftDoubleClick
        position = GetGadgetState(EventGadget())
        If position <> -1
          *mod = GetGadgetItemData(EventGadget(), position)
          If *mod
            misc::openLink(mods::getModFolder(*mod\tpf_id$, *mod\aux\type$))
          EndIf
        EndIf
      Case #PB_EventType_RightClick
        DisplayPopupMenu(MenuLibrary, WindowID(windowMain::window))
    EndSelect
  EndProcedure
  
  Procedure GadgetButtonStartGame()
    misc::openLink("steam://run/304730/")
  EndProcedure
  
  Procedure GadgetButtonTrainFeverNet()
    misc::openLink("http://goo.gl/8Dsb40") ; Homepage (Train-Fever.net)
  EndProcedure
  
  Procedure GadgetButtonTrainFeverNetDownloads()
    misc::openLink("http://goo.gl/Q75VIM") ; Downloads / Filebase (Train-Fever.net)
  EndProcedure
  
  Procedure GadgetImageMain()
    Protected event = EventType()
    If event = #PB_EventType_LeftClick
      If GetGadgetState(gadget("modPreviewImage")) = ImageID(images::Images("logo"))
        GadgetButtonTrainFeverNet()
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetFilterMods()
    mods::displayMods()
  EndProcedure
  
  Procedure GadgetResetFilterMods()
    SetGadgetText(gadget("modFilterString"), "")
    SetActiveGadget(gadget("modFilterString"))
    mods::displayMods()
  EndProcedure
  
  Procedure GadgetResetFilterRepository()
    SetGadgetText(gadget("repoFilterString"), "")
    SetActiveGadget(gadget("repoFilterString"))
  EndProcedure
  
  Procedure GadgetRepositoryDownload()
    ; download and install mod from source
    Protected item, nFiles
    Protected url$
    Protected *mod.repository::mod
    Protected *download.repository::download
    
    ; currently: only one file at a time!
    
    ; get selected mod from list:
    item = GetGadgetState(gadget("repoList"))
    If item = -1
      ProcedureReturn #False
    EndIf
    
    *mod = GetGadgetItemData(gadget("repoList"), item)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    *download = AllocateStructure(repository::download)
    *download\mod = *mod
    
    ForEach *mod\files()
      If *mod\files()\url$
        nFiles + 1
        url$ = *mod\files()\url$
        *download\file = *mod\files()
      EndIf
    Next
    
    If nFiles = 1
      ; start download of file and install automatically
      repository::downloadMod(*download)
    Else ; no download url or multiple files
      If *mod\url$
        misc::openLink(*mod\url$) ; open in browser
      EndIf
    EndIf
    
  EndProcedure
  
  Procedure GadgetDLCToggle()
    ;- todo remove
    
  EndProcedure
  
  ; DRAG & DROP
  
  Procedure HandleDroppedFiles()
    Protected count, i
    Protected file$, files$
    
    files$ = EventDropFiles()
    
    debugger::Add("dropped files:")
    count  = CountString(files$, Chr(10)) + 1
    For i = 1 To count
      file$ = StringField(files$, i, Chr(10))
      queue::add(queue::#QueueActionInstall, file$)
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
  
  Procedure progressBar(value, max=-1, text$=Chr(1))
    If value = -1
      ; hide progress bar
      StatusBarText(0, 0, "", #PB_StatusBar_BorderLess)
    Else
      ; show progress
      If max = -1
        StatusBarProgress(0, 0, value, #PB_StatusBar_BorderLess)
      Else
        StatusBarProgress(0, 0, value, #PB_StatusBar_BorderLess, 0, max)
      EndIf
    EndIf
    
    If text$ <> Chr(1)
      StatusBarText(0, 1, text$);, #PB_StatusBar_BorderLess)
    EndIf
  EndProcedure
  
  Procedure progressDownload(percent.d)
    Protected text$
    If percent = 0
      text$ = "Download started"
    ElseIf percent = 1
      text$ = "Download finished"
    Else
      text$ = "Download "+Str(percent*100)+"%"
    EndIf
    
    StatusBarText(0, 2, text$, #PB_StatusBar_Center)
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
    Protected xml
    xml = CatchXML(#PB_Any, ?mainDialogXML, ?mainDialogXMLend - ?mainDialogXML)
    If Not xml Or XMLStatus(xml) <> #PB_XML_Success
      MessageRequester("Critical Error", "Could not read window definition!", #PB_MessageRequester_Error)
      End
    EndIf
    
    ; dialog does not take menu height and statusbar height into account
    ; workaround: placeholder node in dialog tree with required offset.
    SetXMLAttribute(XMLNodeFromID(xml, "placeholder"), "margin", "bottom:"+Str(MenuHeight()+getStatusBarHeight()-8))
    
    dialog = CreateDialog(#PB_Any)
     
    If Not OpenXMLDialog(dialog, xml, "main")
      MessageRequester("Critical Error", "Could not open main window!", #PB_MessageRequester_Error)
      End
    EndIf
    
    window = DialogWindow(dialog)
    
    
    ; Set window events & timers
    AddWindowTimer(window, TimerMainGadgets, 100)
    BindEvent(#PB_Event_SizeWindow, @resize(), window)
    BindEvent(#PB_Event_MaximizeWindow, @resize(), window)
    BindEvent(#PB_Event_RestoreWindow, @resize(), window)
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    BindEvent(#PB_Event_Timer, @TimerMain(), window)
    BindEvent(#PB_Event_WindowDrop, @HandleDroppedFiles(), window)
    
    
    ; get all gadgets
    Macro getGadget(name)
      gadget(name) = DialogGadget(dialog, name)
      Debug "Gadget "+name+":"+gadget(name)
      If Not IsGadget(gadget(name))
        MessageRequester("Critical Error", "Could not create gadget "+name+"!", #PB_MessageRequester_Error)
        End
      EndIf
    EndMacro
    
    getGadget("headerMain")
    getGadget("panel")
    
    getGadget("modList")
    getGadget("modFilterFrame")
    getGadget("modFilterString")
    getGadget("modFilterReset")
    getGadget("modFilterHidden")
    getGadget("modFilterVanilla")
    getGadget("modPreviewImage")
    getGadget("modManagementFrame")
    getGadget("modInformation")
    getGadget("modBackup")
    getGadget("modUninstall")
    
    getGadget("repoList")
    getGadget("repoFilterFrame")
    getGadget("repoFilterSources")
    getGadget("repoFilterTypes")
    getGadget("repoFilterString")
    getGadget("repoFilterReset")
    getGadget("repoManagementFrame")
    getGadget("repoInstall")
    getGadget("repoPreviewImage")
    
    
    ; initialize gadgets
    
    SetGadgetItemText(gadget("panel"), 0,       l("main","mods"))
    SetGadgetItemText(gadget("panel"), 1,       l("main","repository"))
    
    RemoveGadgetColumn(gadget("modList"), 0)
    AddGadgetColumn(gadget("modList"), 0,       l("main","name"), 240)
    AddGadgetColumn(gadget("modList"), 1,       l("main","author"), 90)
    AddGadgetColumn(gadget("modList"), 2,       l("main","category"), 90)
    AddGadgetColumn(gadget("modList"), 3,       l("main","version"), 60)
    SetGadgetText(gadget("modFilterFrame"),     l("main","filter"))
    SetGadgetText(gadget("modFilterHidden"),    l("main","filter_hidden"))
    SetGadgetText(gadget("modFilterVanilla"),   l("main","filter_vanilla"))
    SetGadgetText(gadget("modManagementFrame"), l("main","management"))
    SetGadgetText(gadget("modInformation"),     l("main","information"))
    SetGadgetText(gadget("modBackup"),          l("main","backup"))
    SetGadgetText(gadget("modUninstall"),       l("main","uninstall"))
    
    SetGadgetText(gadget("repoFilterFrame"),    l("main","filter"))
    SetGadgetText(gadget("repoInstall"),        l("main","install"))
    
    
    ; Bind Gadget Events
    BindGadgetEvent(gadget("modInformation"),   @GadgetButtonInfomation())
    BindGadgetEvent(gadget("modBackup"),        @GadgetButtonBackup())
    BindGadgetEvent(gadget("modUninstall"),     @GadgetButtonUninstall())
    BindGadgetEvent(gadget("modList"),          @GadgetLibraryMods())
    BindGadgetEvent(gadget("modFilterString"),  @GadgetFilterMods(), #PB_EventType_Change)
    BindGadgetEvent(gadget("modFilterReset"),   @GadgetResetFilterMods(), #PB_EventType_LeftClick)
    BindGadgetEvent(gadget("modFilterHidden"),  @GadgetFilterMods())
    BindGadgetEvent(gadget("modFilterVanilla"),  @GadgetFilterMods())
    
    
    BindGadgetEvent(gadget("repoFilterReset"),  @GadgetResetFilterRepository())
    BindGadgetEvent(gadget("repoInstall"),      @GadgetRepositoryDownload())
    
    
    ; create shortcuts
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      ; Mac OS X has predefined shortcuts
      AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_S, #PB_Menu_Preferences)
      AddKeyboardShortcut(window, #PB_Shortcut_Alt | #PB_Shortcut_F4, #PB_Menu_Quit)
      AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_L, #PB_Menu_About)
    CompilerEndIf
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_O, #MenuItem_AddMod)
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_E, #MenuItem_ExportList)
    AddKeyboardShortcut(window, #PB_Shortcut_F1, #MenuItem_Homepage)
    
    
    ; Menu
    CreateMenu(0, WindowID(window))
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      MenuTitle(l("menu","file"))
    CompilerEndIf
    MenuItem(#PB_Menu_Preferences, l("menu","settings") + Chr(9) + "Ctrl + S")
    MenuItem(#PB_Menu_Quit, l("menu","close") + Chr(9) + "Alt + F4")
    MenuTitle(l("menu","mods"))
    MenuItem(#MenuItem_AddMod, l("menu","mod_add") + Chr(9) + "Ctrl + O")
    MenuItem(#MenuItem_ExportList, l("menu","mod_export") + Chr(9) + "Ctrl + E")
    CloseSubMenu()
    MenuTitle(l("menu","about"))
    MenuItem(#MenuItem_Homepage, l("menu","homepage") + Chr(9) + "F1")
    MenuItem(#PB_Menu_About, l("menu","license") + Chr(9) + "Ctrl + L")
    
    ; Menu Events
    BindMenuEvent(0, #PB_Menu_Preferences, @MenuItemSettings())
    BindMenuEvent(0, #PB_Menu_Quit, main::@exit())
    BindMenuEvent(0, #MenuItem_AddMod, @MenuItemNewMod())
    BindMenuEvent(0, #MenuItem_ExportList, @MenuItemExport())
    BindMenuEvent(0, #MenuItem_Homepage, @MenuItemHomepage())
    BindMenuEvent(0, #PB_Menu_About, @MenuItemLicense())
    
    
    ; Status bar
    CreateStatusBar(0, WindowID(DialogWindow(dialog)))
    AddStatusBarField(#PB_Ignore)
    AddStatusBarField(240)
    AddStatusBarField(140)
    AddStatusBarField(100)
    StatusBarProgress(0, 0, 0, #PB_StatusBar_BorderLess)
    StatusBarText(0, 1, "", #PB_StatusBar_BorderLess)
    StatusBarText(0, 2, "", #PB_StatusBar_Center)
    StatusBarText(0, 3, main::VERSION$, #PB_StatusBar_Right | #PB_StatusBar_BorderLess)
    
    
    ; OS specific
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        SetWindowTitle(window, GetWindowTitle(window) + " for Windows")
        ListIcon::DefineListCallback(gadget("modList"))
      CompilerCase #PB_OS_Linux
        SetWindowTitle(window, GetWindowTitle(window) + " for Linux")
      CompilerCase #PB_OS_MacOS
        SetWindowTitle(window, GetWindowTitle(window) + " for MacOS")
    CompilerEndSelect
    
    
    ; indicate testmode in window title
    If main::_TESTMODE
      SetWindowTitle(window, GetWindowTitle(window) + " (Test Mode Enabled)")
    EndIf
    
    
    ; load images
    ResizeImage(images::Images("headermain"), GadgetWidth(gadget("headerMain")), GadgetHeight(gadget("headerMain")), #PB_Image_Raw)
    SetGadgetState(gadget("headerMain"), ImageID(images::Images("headermain")))
    SetGadgetState(gadget("modPreviewImage"), ImageID(images::Images("logo")))
    
    
    ; right click menu on mod item
    MenuLibrary = CreatePopupImageMenu(#PB_Any)
    MenuItem(#MenuItem_Backup, l("main","backup"), ImageID(images::Images("icon_backup")))
    MenuItem(#MenuItem_Uninstall, l("main","uninstall"), ImageID(images::Images("no")))
    
    BindMenuEvent(MenuLibrary, #MenuItem_Backup, @GadgetButtonBackup())
    BindMenuEvent(MenuLibrary, #MenuItem_Uninstall, @GadgetButtonUninstall())
    
    
    ; Drag & Drop
    EnableWindowDrop(window, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
    
    
    ; register mods module
    mods::register(window, gadget("modList"), gadget("modFilterString"), gadget("modFilterHidden"), gadget("modFilterVanilla"))
    
    
    ; register progress module
    ; queue::progressRegister(0, GadgetProgressBar, GadgetProgressText)
    
    
    ; register to repository module
    Protected json$, *json
    Protected Dim columns.repository::column(0)
    json$ = ReplaceString("[{'width':320,'name':'name'},"+
                          "{'width':100,'name':'author_name'}]", "'", #DQUOTE$)
    *json = ParseJSON(#PB_Any, json$)
    ExtractJSONArray(JSONValue(*json), columns())
    FreeJSON(*json)
    
    repository::registerWindow(window)
    repository::registerListGadget(gadget("repoList"), columns())
    repository::registerThumbGadget(gadget("repoPreviewImage"))
    repository::registerSourceGadget(gadget("repoFilterSources"))
    repository::registerTypeGadget(gadget("repoFilterTypes"))
    repository::registerFilterGadget(gadget("repoFilterString"))
    
    CreateThread(@loadRepositoryThread(), 0)
    
    
    ; apply sizes
    RefreshDialog(dialog)
    resize()
    
    
    ; init gui texts and button states
    updateGUI()
    
    
    UnuseModule locale
  EndProcedure
  
  Procedure stopGUIupdate(stop = #True)
    _noUpdate = stop
  EndProcedure
  
  Procedure setColumnWidths(Array widths(1))
    Protected i
    For i = 0 To ArraySize(widths())
      If widths(i)
        SetGadgetItemAttribute(gadget("modList"), #PB_Any, #PB_Explorer_ColumnWidth, ReadPreferenceInteger(Str(i), 0), i)
        ; Sorting
        ListIcon::SetColumnFlag(gadget("modList"), i, ListIcon::#String)
      EndIf
    Next
  EndProcedure
  
  Procedure getColumnWidth(column)
    ProcedureReturn GetGadgetItemAttribute(gadget("modList"), #PB_Any, #PB_Explorer_ColumnWidth, column)
  EndProcedure
  
  
  ; callbacks from mods module
  
  
  
  
EndModule