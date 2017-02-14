
XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowSettings.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_updater.pbi"
XIncludeFile "module_mods.h.pbi"
XIncludeFile "module_repository.pbi"

DeclareModule windowMain
  EnableExplicit
  
  Global window
  
  Enumeration FormMenu
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      #PB_Menu_Quit
      #PB_Menu_Preferences
      #PB_Menu_About
    CompilerEndIf
    #MenuItem_AddMod
    #MenuItem_ExportList
    #MenuItem_Homepage
    #MenuItem_Update
    #MenuItem_License
  EndEnumeration
  
  Declare create()
  
  Declare stopGUIupdate(stop = #True)
  Declare setColumnWidths(Array widths(1))
  Declare getColumnWidth(column)
  
  Declare displayMods()
  
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
  Global GadgetImageHeader
  Global GadgetNewMod, GadgetHomepage, GadgetButtonStartGame, GadgetVersionText
  Global GadgetMainPanel, GadgetLibraryMods, GadgetLibraryDLCs
  Global GadgetFrameManagement, GadgetFrameFilter
  Global GadgetFilterMods, GadgetResetFilterMods, GadgetImageLogo, GadgetButtonDelete, GadgetButtonUninstall, GadgetButtonBackup, GadgetButtonInfomation
  Global GadgetDLCLogo, GadgetDLCToggle, GadgetDLCScrollAreaList, GadgetDLCName, GadgetDLCScrollAreaAuthors
  Global GadgetRepositoryList, GadgetRepositoryThumbnail, GadgetRepositoryFrameFilter, GadgetRepositoryFilterType, GadgetRepositoryFilterString, GadgetRepositoryFilterReset
  Global GadgetProgressText, GadgetProgressBar
  
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
  Declare MenuItemUpdate()
  
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
    Protected width, height, iwidth, iheight
    width = WindowWidth(window)
    height = WindowHeight(window)
    ; height - MenuHeight() ; may be needed for OSX?
    
    ; top gadgets
    ResizeGadget(GadgetImageHeader, 0, 0, width, 8)
    ResizeImage(images::Images("headermain"), width, 8, #PB_Image_Raw)
    SetGadgetState(GadgetImageHeader, ImageID(images::Images("headermain")))
    
    ; main panel
    ResizeGadget(GadgetMainPanel, 5, 10, width-10, height - 45 - 50)
    iwidth = GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemWidth)
    iheight = GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemHeight)
    
    ; mod gadgets
    ResizeGadget(GadgetLibraryMods, 0, 0, iwidth-220, iheight)
    
    ResizeGadget(GadgetFrameFilter, iwidth-215, 0, 210, 40)
    ResizeGadget(GadgetFilterMods, iwidth-210, 15, 175, 20)
    ResizeGadget(GadgetResetFilterMods, iwidth-30, 15, 20, 20)
    
    ResizeGadget(GadgetImageLogo, iwidth - 215, 45, 210, 118)
    
    ResizeGadget(GadgetFrameManagement, iwidth - 215, 165, 210, 120)
    ResizeGadget(GadgetButtonInfomation, iwidth -210, 180, 200, 30)
    ResizeGadget(GadgetButtonBackup, iwidth - 210, 215, 200, 30)
    ResizeGadget(GadgetButtonUninstall, iwidth - 210, 250, 200, 30)
    
    ; repository gadgets
    ResizeGadget(GadgetRepositoryList, 0, 0, iwidth-220, iheight)
    ResizeGadget(GadgetRepositoryFrameFilter, iwidth-215, 0, 210, 75)
    ResizeGadget(GadgetRepositoryFilterType, iwidth-210, 15, 200, 25)
    ResizeGadget(GadgetRepositoryFilterString, iwidth-210, 45, 170, 25)
    ResizeGadget(GadgetRepositoryFilterReset, iwidth-35, 45, 25, 25)
    ResizeGadget(GadgetRepositoryThumbnail, iwidth - 215, 80, 210, 118)
    
    
    ; bottom gadgets
    ResizeGadget(GadgetProgressBar, 10, height - 55 - 25, width - 240, 20)
    ResizeGadget(GadgetProgressText, width - 220, height - 55 - 25, 210, 20)
    ResizeGadget(GadgetNewMod, 10, height - 55, 120, 25)
    ResizeGadget(GadgetHomepage, 140, height - 55, 120, 25)
    ResizeGadget(GadgetButtonStartGame, 270, height - 55, width - 500, 25)
    ResizeGadget(GadgetVersionText, width - 220, height - 50, 210, 20)
    
    
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
    
    For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
      *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
      If Not *mod
        Continue
      EndIf
      
      If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected
        numSelected + 1
        If mods::canUninstall(*mod)
          numCanUninstall + 1
        EndIf
        If mods::canBackup(*mod)
          numCanBackup + 1
        EndIf
      EndIf
    Next
    
    DisableGadget(GadgetButtonInfomation, #True) ;- not yet implemented
;     If numSelected = 0
;       DisableGadget(GadgetButtonInfomation, #True)
;     Else
;       DisableGadget(GadgetButtonInfomation, #False)
;     EndIf
    
    If numCanBackup = 0
      DisableGadget(GadgetButtonBackup,     #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Backup,    #True)
    Else
      DisableGadget(GadgetButtonBackup,     #False)
      DisableMenuItem(MenuLibrary, #MenuItem_Backup,    #False)
    EndIf
    
    If numCanUninstall = 0
      DisableGadget(GadgetButtonUninstall,  #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Uninstall, #True)
    Else
      DisableGadget(GadgetButtonUninstall,  #False)
      DisableMenuItem(MenuLibrary, #MenuItem_Uninstall, #False)
    EndIf
    
    If numCanBackup > 1
      SetGadgetText(GadgetButtonBackup,     locale::l("main","backup_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_Backup,    locale::l("main","backup_pl"))
    Else
      SetGadgetText(GadgetButtonBackup,     locale::l("main","backup"))
      SetMenuItemText(MenuLibrary, #MenuItem_Backup,    locale::l("main","backup"))
    EndIf
    
    If numCanUninstall > 1
      SetGadgetText(GadgetButtonUninstall,  locale::l("main","uninstall_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_Uninstall, locale::l("main","uninstall_pl"))
    Else
      SetGadgetText(GadgetButtonUninstall,  locale::l("main","uninstall"))
      SetMenuItemText(MenuLibrary, #MenuItem_Uninstall, locale::l("main","uninstall"))
    EndIf
    
    If numSelected = 1
      ; one mod selected
      ; display image
      *mod = ListIcon::GetListItemData(GadgetLibraryMods, GetGadgetState(GadgetLibraryMods))
      
      Protected im
      im = mods::getPreviewImage(*mod)
      If IsImage(im)
        ; display image
        If GetGadgetState(GadgetImageLogo) <> ImageID(im)
          SetGadgetState(GadgetImageLogo, ImageID(im))
        EndIf
      Else
        ; else: display normal logo
        If GetGadgetState(GadgetImageLogo) <> ImageID(images::Images("logo"))
          SetGadgetState(GadgetImageLogo, ImageID(images::Images("logo")))
        EndIf
      EndIf
    Else
      If GetGadgetState(GadgetImageLogo) <> ImageID(images::Images("logo"))
        SetGadgetState(GadgetImageLogo, ImageID(images::Images("logo")))
      EndIf
    EndIf
    
  EndProcedure
  
  Procedure close()
    HideWindow(window, #True)
    main::exit()
  EndProcedure
  
  Procedure loadRepositoryThread(*dummy)
    repository::loadRepositoryList()
    repository::filterMods("", "") ; initially fill list
    
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
  
  Procedure MenuItemUpdate()
    CreateThread(updater::@checkUpdate(), 0)
  EndProcedure
  
  Procedure MenuItemLicense()
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      MessageRequester("License",
                       "Transport Fever Mod Manager" + #CRLF$ +
                       updater::VERSION$ + #CRLF$ +
                       "© "+FormatDate("%yyyy", Date())+" Alexander Nähring" + #CRLF$ +
                       "Distributed on https://www.transportfevermods.com/" +  #CRLF$ +
                       "unrar © Alexander L. Roshal")
    CompilerElse
      MessageRequester("License",
                       "Transport Fever Mod Manager" + #CRLF$ +
                       updater::VERSION$ + #CRLF$ +
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
    
    For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
      If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
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
        For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
          If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected
            *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
            If mods::canUninstall(*mod)
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
    
    For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
      If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
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
      
      For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
        If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected
          *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
          If mods::canBackup(*mod)
            queue::add(queue::#QueueActionBackup, *mod\tpf_id$, backupFolder$)
          EndIf
        EndIf
      Next i
      
    EndIf
  EndProcedure
  
  Procedure GadgetButtonInfomation()
    Protected *mod.mods::mod
    
    *mod = ListIcon::GetListItemData(GadgetLibraryMods, GetGadgetState(GadgetLibraryMods))
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
      If GetGadgetState(GadgetImageLogo) = ImageID(images::Images("logo"))
        GadgetButtonTrainFeverNet()
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetFilterMods()
    mods::displayMods(GetGadgetText(GadgetFilterMods))
  EndProcedure
  
  Procedure GadgetResetFilterMods()
    SetGadgetText(GadgetFilterMods, "")
    SetActiveGadget(GadgetFilterMods)
    mods::displayMods()
  EndProcedure
  
  Procedure GadgetResetFilterRepository()
    SetGadgetText(GadgetRepositoryFilterString, "")
    SetActiveGadget(GadgetRepositoryFilterString)
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
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create()
    Protected width, height
    width = 750
    height = 480
    
    window = OpenWindow(#PB_Any, 0, 0, width, height, "Transport Fever Mod Manager", #PB_Window_SystemMenu | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget | #PB_Window_SizeGadget | #PB_Window_TitleBar | #PB_Window_ScreenCentered)
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      ; Mac OS X has predefined shortcuts
      AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_S, #PB_Menu_Preferences)
      AddKeyboardShortcut(window, #PB_Shortcut_Alt | #PB_Shortcut_F4, #PB_Menu_Quit)
      AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_L, #PB_Menu_About)
    CompilerEndIf
    
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_O, #MenuItem_AddMod)
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_E, #MenuItem_ExportList)
    AddKeyboardShortcut(window, #PB_Shortcut_F1, #MenuItem_Homepage)
    AddKeyboardShortcut(window, #PB_Shortcut_F5, #MenuItem_Update)
    
    UseModule locale ; import namespace "locale" for shorthand "l()" access
    
    ; Menu
    CreateMenu(0, WindowID(window))
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      MenuTitle(l("menu","file"))
    CompilerEndIf
    MenuItem(#PB_Menu_Preferences, l("menu","settings") + Chr(9) + "Ctrl + S")
    MenuItem(#PB_Menu_Quit, l("menu","close") + Chr(9) + "Alt + F4")
    MenuTitle(l("menu","mods"))
    MenuItem(#MenuItem_AddMod, l("menu","mod_add") + Chr(9) + "Ctrl + O")
;     OpenSubMenu(l("menu","mod_export"))
    MenuItem(#MenuItem_ExportList, l("menu","mod_export") + Chr(9) + "Ctrl + E")
    CloseSubMenu()
    MenuTitle(l("menu","about"))
    MenuItem(#MenuItem_Homepage, l("menu","homepage") + Chr(9) + "F1")
    ; MenuItem(#MenuItem_Update, l("menu","update") + Chr(9) + "F5")
    MenuItem(#PB_Menu_About, l("menu","license") + Chr(9) + "Ctrl + L")
    
    ; Menu Events
    BindMenuEvent(0, #PB_Menu_Preferences, @MenuItemSettings())
    BindMenuEvent(0, #PB_Menu_Quit, main::@exit())
    BindMenuEvent(0, #MenuItem_AddMod, @MenuItemNewMod())
    BindMenuEvent(0, #MenuItem_ExportList, @MenuItemExport())
    BindMenuEvent(0, #MenuItem_Homepage, @MenuItemHomepage())
    BindMenuEvent(0, #MenuItem_Update, @MenuItemUpdate())
    BindMenuEvent(0, #PB_Menu_About, @MenuItemLicense())
    
    ; Gagets
    GadgetMainPanel = PanelGadget(#PB_Any, 5, 10, 740, 410)
    
    ; Gadgets: MODs
    AddGadgetItem(GadgetMainPanel, -1, l("main","mods"))
    
    GadgetImageLogo         = ImageGadget(#PB_Any, 0, 0, 0, 0, 0)
    GadgetFrameFilter       = FrameGadget(#PB_Any, 0, 0, 0, 0, l("main","filter"))
    GadgetFilterMods        = StringGadget(#PB_Any, 0, 0, 0, 0, "")
    GadgetResetFilterMods   = ButtonGadget(#PB_Any, 0, 0, 0, 0, "X")
    GadgetFrameManagement   = FrameGadget(#PB_Any, 0, 0, 0, 0, l("main","management"))
    GadgetButtonInfomation  = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main", "information"))
    GadgetButtonBackup      = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main","backup"))
    GadgetButtonUninstall   = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main","uninstall"))
    
    GadgetLibraryMods = ListIconGadget(#PB_Any, 0, 0, 0, 0, l("main","name"), 240, #PB_ListIcon_MultiSelect | #PB_ListIcon_GridLines | #PB_ListIcon_FullRowSelect | #PB_ListIcon_AlwaysShowSelection)
    AddGadgetColumn(GadgetLibraryMods, 1, l("main","author"), 90)
    AddGadgetColumn(GadgetLibraryMods, 2, l("main","category"), 90)
    AddGadgetColumn(GadgetLibraryMods, 3, l("main","version"), 60)
    
    ; Gadgtes: DLCs
;     AddGadgetItem(GadgetMainPanel, -1, l("main", "dlcs"))
    
    ; Gadgets: Repository
    AddGadgetItem(GadgetMainPanel, -1, l("main","repository"))
    GadgetRepositoryList          = ListIconGadget(#PB_Any, 0, 0, 0, 0, "", 0, #PB_ListIcon_FullRowSelect)
    GadgetRepositoryThumbnail     = ImageGadget(#PB_Any, 0, 0, 0, 0, 0)
    GadgetRepositoryFrameFilter   = FrameGadget(#PB_Any, 0, 0, 0, 0, l("main","filter"))
    GadgetRepositoryFilterType    = ComboBoxGadget(#PB_Any, 0, 0, 0, 0)
    GadgetRepositoryFilterString  = StringGadget(#PB_Any, 0, 0, 0, 0, "")
    GadgetRepositoryFilterReset   = ButtonGadget(#PB_Any, 0, 0, 0, 0, "X")
    
    ; Gadgets: Maps
;     AddGadgetItem(GadgetMainPanel, -1, l("main", "maps"))
    
    ; Gadgets: Savegames
;     AddGadgetItem(GadgetMainPanel, -1, l("main", "savegames"))
    
    CloseGadgetList()
    
    ; Bottom Gadgets
    GadgetImageHeader = ImageGadget(#PB_Any, 0, 0, 750, 8, 0)
    GadgetNewMod = ButtonGadget(#PB_Any, 10, 425, 120, 25, l("main","new_mod"))
    GadgetHomepage = ButtonGadget(#PB_Any, 140, 425, 120, 25, l("main","download"))
    GadgetButtonStartGame = ButtonGadget(#PB_Any, 270, 425, 250, 25, l("main","start_tf"), #PB_Button_Default)
    GadgetVersionText = TextGadget(#PB_Any, 530, 430, 210, 20, updater::VERSION$, #PB_Text_Right)
    GadgetProgressText = TextGadget(#PB_Any, 0, 0, 0, 0, "")
    GadgetProgressBar = ProgressBarGadget(#PB_Any, 0, 0, 0, 0, 0, 100, #PB_ProgressBar_Smooth)
    
    
    ; Bind Gadget Events
    BindGadgetEvent(GadgetNewMod, @GadgetNewMod())
    BindGadgetEvent(GadgetButtonInfomation, @GadgetButtonInfomation())
    BindGadgetEvent(GadgetButtonBackup, @GadgetButtonBackup())
    BindGadgetEvent(GadgetButtonUninstall, @GadgetButtonUninstall())
    BindGadgetEvent(GadgetLibraryMods, @GadgetLibraryMods())
    BindGadgetEvent(GadgetButtonStartGame, @GadgetButtonStartGame())
    BindGadgetEvent(GadgetHomepage, @GadgetButtonTrainFeverNetDownloads())
    BindGadgetEvent(GadgetImageLogo, @GadgetImageMain())
    BindGadgetEvent(GadgetFilterMods, @GadgetFilterMods(), #PB_EventType_Change)
    BindGadgetEvent(GadgetResetFilterMods, @GadgetResetFilterMods(), #PB_EventType_LeftClick)
    ;
;     BindGadgetEvent(GadgetDLCToggle, @GadgetDLCToggle())
    ;
    BindGadgetEvent(GadgetRepositoryFilterReset, @GadgetResetFilterRepository())
    
    ; Set window boundaries, timers, events
    WindowBounds(window, 700, 400, #PB_Ignore, #PB_Ignore) 
    AddWindowTimer(window, TimerMainGadgets, 100)
    BindEvent(#PB_Event_SizeWindow, @resize(), window)
    BindEvent(#PB_Event_MaximizeWindow, @resize(), window)
    BindEvent(#PB_Event_RestoreWindow, @resize(), window)
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    BindEvent(#PB_Event_Timer, @TimerMain(), window)
    BindEvent(#PB_Event_WindowDrop, @HandleDroppedFiles(), window)
    
    ; OS specific
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        SetWindowTitle(window, GetWindowTitle(window) + " for Windows")
        ListIcon::DefineListCallback(GadgetLibraryMods)
      CompilerCase #PB_OS_Linux
        SetWindowTitle(window, GetWindowTitle(window) + " for Linux")
      CompilerCase #PB_OS_MacOS
        SetWindowTitle(window, GetWindowTitle(window) + " for MacOS")
    CompilerEndSelect
    
    
    ; indicate testmode in window title
    If main::_TESTMODE
      SetWindowTitle(window, GetWindowTitle(window) + " (Test Mode Enabled)")
    EndIf
    
    ; Colors
    ; SetWindowColor(window, RGB(42,51,66))
    
    ; load images
    ResizeImage(images::Images("headermain"), GadgetWidth(GadgetImageHeader), GadgetHeight(GadgetImageHeader), #PB_Image_Raw)
    SetGadgetState(GadgetImageHeader, ImageID(images::Images("headermain")))
    SetGadgetState(GadgetImageLogo, ImageID(images::Images("logo")))
    
    ; right click menu on mod item
    MenuLibrary = CreatePopupImageMenu(#PB_Any)
    MenuItem(#MenuItem_Backup, l("main","backup"), ImageID(images::Images("icon_backup")))
    MenuItem(#MenuItem_Uninstall, l("main","uninstall"), ImageID(images::Images("no")))
    
    BindMenuEvent(MenuLibrary, #MenuItem_Backup, @GadgetButtonBackup())
    BindMenuEvent(MenuLibrary, #MenuItem_Uninstall, @GadgetButtonUninstall())
    
    ; Drag & Drop
    EnableWindowDrop(window, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
    
    ; register to mods module
    mods::registerMainWindow(window)
    mods::registerModGadget(GadgetLibraryMods)
    
    ; register to progress
    queue::progressRegister(0, GadgetProgressBar, GadgetProgressText)
    
    ; register to repository module
    Protected json$, *json
    Protected Dim columns.repository::column(0)
    json$ = ReplaceString("[{'width':240,'name':'name'},"+
                          "{'width':60,'name':'version'},"+
                          "{'width':100,'name':'author_name'},"+
                          "{'width':60,'name':'state'},"+
                          "{'width':100,'name':'tags_string'},"+
                          "{'width':60,'name':'downloads'},"+
                          "{'width':40,'name':'likes'}]", "'", #DQUOTE$)
    *json = ParseJSON(#PB_Any, json$)
    ExtractJSONArray(JSONValue(*json), columns())
    FreeJSON(*json)
    
    repository::registerWindow(window)
    repository::registerListGadget(GadgetRepositoryList, columns())
    repository::registerThumbGadget(GadgetRepositoryThumbnail)
    repository::registerTypeGadget(GadgetRepositoryFilterType)
    repository::registerFilterGadget(GadgetRepositoryFilterString)
    ;- disabled until online features are finished
    ;CreateThread(@loadRepositoryThread(), 0) 
    ;TODO change this!
    
    
    ; apply sizes
    resize()
    
    ; init gui
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
        SetGadgetItemAttribute(GadgetLibraryMods, #PB_Any, #PB_Explorer_ColumnWidth, ReadPreferenceInteger(Str(i), 0), i)
        ; Sorting
        ListIcon::SetColumnFlag(GadgetLibraryMods, i, ListIcon::#String)
      EndIf
    Next
  EndProcedure
  
  Procedure getColumnWidth(column)
    ProcedureReturn GetGadgetItemAttribute(GadgetLibraryMods, #PB_Any, #PB_Explorer_ColumnWidth, column)
  EndProcedure
  
  
  ; callbacks from mods module
  
  
  Procedure displayMods()
    
  EndProcedure
  
  
  
  
EndModule
