
XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowInformation.pbi"
XIncludeFile "module_windowSettings.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_updater.pbi"
XIncludeFile "module_mods.h.pbi"

DeclareModule windowMain
  EnableExplicit
  
  Global id
  
  Enumeration FormMenu
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      #PB_Menu_Quit
      #PB_Menu_Preferences
      #PB_Menu_About
    CompilerEndIf
    #MenuItem_AddMod
    #MenuItem_ExportListActivated
    #MenuItem_ExportListAll
    #MenuItem_Homepage
    #MenuItem_Update
    #MenuItem_License
  EndEnumeration
  
  Declare create()
  Declare events(event)
  
  Declare stopGUIupdate(stop = #True)
  Declare setColumnWidths(Array widths(1))
  Declare getColumnWidth(column)
  
  
  Declare displayDLCs(Map *dlcs.mods::Mod())
  Declare displayMods()
  
EndDeclareModule

Module windowMain

  ; rightclick menu on library gadget
  Global MenuLibrary
  Enumeration 100
    #MenuItem_Install
    #MenuItem_Remove
    #MenuItem_Delete
    #MenuItem_Information
  EndEnumeration
  
  ;- Gadgets
  Global NewMap gadgets()
  Global GadgetImageHeader
  Global GadgetNewMod, GadgetHomepage, GadgetButtonStartGame, GadgetVersionText
  Global GadgetMainPanel, GadgetLibraryMods, GadgetLibraryDLCs
  Global GadgetFrameManagement, GadgetFrameInformation, GadgetFrameFilter
  Global GadgetFilterMods, GadgetResetFilterMods, GadgetImageLogo, GadgetButtonInstall, GadgetButtonDelete, GadgetButtonRemove, GadgetButtonInformation
  Global GadgetDLCLogo, GadgetDLCToggle, GadgetDLCScrollAreaList, GadgetDLCName, GadgetDLCScrollAreaAuthors
  
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
  Declare MenuItemExportAll()
  Declare MenuItemUpdate()
  Declare MenuItemExportActivated()
  
  Declare GadgetNewMod()
  Declare GadgetButtonDelete()
  Declare GadgetLibraryMods()
  Declare GadgetImageMain()
  Declare GadgetButtonInformation()
  Declare GadgetNewMod()
  Declare GadgetButtonStartGame()
  Declare GadgetButtonTrainFeverNetDownloads()
  Declare GadgetButtonInstall()
  Declare GadgetButtonRemove()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  
  Procedure resize()
    Protected width, height, iwidth, iheight
    width = WindowWidth(id)
    height = WindowHeight(id)
    ; height - MenuHeight()?
    
    ResizeGadget(GadgetNewMod, 10, height - 55, 120, 25)
    ResizeGadget(GadgetHomepage, 140, height - 55, 120, 25)
    ResizeGadget(GadgetButtonStartGame, 270, height - 55, width - 500, 25)
    ResizeGadget(GadgetVersionText, width - 220, height - 50, 210, 20)
    
    iwidth = GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemWidth)
    iheight = GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemHeight)
    ResizeGadget(GadgetMainPanel, 5, 10, width-10, height - 20 - 50)
    ResizeGadget(GadgetLibraryMods, 0, 0, iwidth-220, iheight)
    
    ResizeGadget(GadgetFrameFilter, iwidth-215, 0, 210, 40)
    ResizeGadget(GadgetFilterMods, iwidth-210, 15, 175, 20)
    ResizeGadget(GadgetResetFilterMods, iwidth-30, 15, 20, 20)
    
    ResizeGadget(GadgetImageLogo, iwidth - 215, 45, 210, 118)
    
    ResizeGadget(GadgetFrameManagement, iwidth - 215, 165, 210, 120)
    ResizeGadget(GadgetButtonInstall, iwidth - 210, 180, 200, 30)
    ResizeGadget(GadgetButtonRemove, iwidth - 210, 215, 200, 30)
    ResizeGadget(GadgetButtonDelete, iwidth - 210, 250, 200, 30)
    
    ResizeGadget(GadgetFrameInformation, iwidth - 215, 290, 210, 50)
    ResizeGadget(GadgetButtonInformation, iwidth - 210, 305, 200, 30)
    
    ; ResizeGadget(GadgetLibraryDLCs, 0, 0, iwidth-400, 80)
    ResizeGadget(GadgetDLCScrollAreaList, 0, 0, 140, iheight)
    ResizeGadget(GadgetDLCName, 150, 5, iwidth-160, 40)
    ; ResizeGadget(GadgetDLCInstall, iwidth-420, iheight-30, 200, 25)
    ResizeGadget(GadgetDLCToggle, iwidth-210, iheight-30, 200, 25)
    ResizeGadget(GadgetDLCScrollAreaAuthors, 150, 40, iwidth-160, iheight-40-40)
    
    ResizeGadget(GadgetImageHeader, 0, 0, width, 8)
    ResizeImage(images::Images("headermain"), width, 8, #PB_Image_Raw)
    SetGadgetState(GadgetImageHeader, ImageID(images::Images("headermain")))
  EndProcedure
  
  Procedure updateGUI()
    Protected SelectedMod, i, selectedActive, selectedInactive, countActive, countInactive
    Protected *mod.mods::mod
    Protected text$, author$
    
    If _noUpdate
      ProcedureReturn #False
    EndIf
    
    selectedActive = 0
    selectedInactive = 0
    
    For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
      *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
      If Not *mod
        Continue
      EndIf
      If *mod\aux\active
        countActive + 1
      Else
        countInactive + 1
      EndIf
      If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected
        SelectedMod = i
        If *mod\aux\active
          selectedActive + 1
        Else
          selectedInactive + 1
        EndIf
      EndIf
    Next
    
    SelectedMod =  GetGadgetState(GadgetLibraryMods)
    If SelectedMod = -1 ; if nothing is selected -> disable buttons
      DisableGadget(GadgetButtonInstall, #True)
      DisableGadget(GadgetButtonRemove, #True)
      DisableGadget(GadgetButtonDelete, #True)
      DisableGadget(GadgetButtonInformation, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Install, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Remove, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_delete, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Information, #True)
    Else
      DisableGadget(GadgetButtonDelete, #False) ; delete is always possible!
      DisableMenuItem(MenuLibrary, #MenuItem_delete, #False)
      If selectedActive > 0 ; if at least one of the mods is active
        DisableGadget(GadgetButtonRemove, #False)
        DisableMenuItem(MenuLibrary, #MenuItem_Remove, #False)
      Else  ; if no mod is active 
        DisableGadget(GadgetButtonRemove, #True)
        DisableMenuItem(MenuLibrary, #MenuItem_Remove, #True)
      EndIf
      If selectedInactive > 0 ; if at least one of the mods is not active
        DisableGadget(GadgetButtonInstall, #False)
        DisableMenuItem(MenuLibrary, #MenuItem_Install, #False)
      Else ; if none of the selected mods is inactive
        DisableGadget(GadgetButtonInstall, #True)  ; disable activate button
        DisableMenuItem(MenuLibrary, #MenuItem_Install, #True)
      EndIf
      
      If selectedActive + selectedInactive > 1
        DisableGadget(GadgetButtonInformation, #True)
        DisableMenuItem(MenuLibrary, #MenuItem_Information, #True)
      Else
        DisableGadget(GadgetButtonInformation, #False)
        DisableMenuItem(MenuLibrary, #MenuItem_Information, #False)
      EndIf
      
      If selectedActive + selectedInactive > 1
        SetGadgetText(GadgetButtonDelete, locale::l("main","delete_pl"))
        SetMenuItemText(MenuLibrary, #MenuItem_delete, locale::l("main","delete_pl"))
      Else
        SetGadgetText(GadgetButtonDelete, locale::l("main","delete"))
        SetMenuItemText(MenuLibrary, #MenuItem_delete, locale::l("main","delete"))
      EndIf
      If selectedActive > 1
        SetGadgetText(GadgetButtonRemove, locale::l("main","remove_pl"))
        SetMenuItemText(MenuLibrary, #MenuItem_Remove, locale::l("main","remove_pl"))
      Else
        SetGadgetText(GadgetButtonRemove, locale::l("main","remove"))
        SetMenuItemText(MenuLibrary, #MenuItem_Remove, locale::l("main","remove"))
      EndIf
      If selectedInactive > 1
        SetGadgetText(GadgetButtonInstall, locale::l("main","install_pl"))
        SetMenuItemText(MenuLibrary, #MenuItem_Install, locale::l("main","install_pl"))
      Else
        SetGadgetText(GadgetButtonInstall, locale::l("main","install"))
        SetMenuItemText(MenuLibrary, #MenuItem_Install, locale::l("main","install"))
      EndIf
    EndIf
    
    If selectedActive + selectedInactive = 1
      ; one mod selected
      ; display image
      *mod = ListIcon::GetListItemData(GadgetLibraryMods, SelectedMod)
      
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
  
  ;-------------------------------------------------
  ;- TIMER
  
  Procedure TimerMain()
    Static LastDir$ = ""
    
    If LastDir$ <> main::TF$
      LastDir$ = main::TF$
      If misc::checkTFPath(main::TF$) <> #True
        main::ready = #False  ; flag for mod management
        MenuItemSettings()
      EndIf
    EndIf
    
    queue::update()
    
  EndProcedure
  
  ;- MENU
  
  Procedure MenuItemHomepage()
    misc::openLink("http://goo.gl/utB3xn") ; Download Page TFMM (Train-Fever.net)
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
                       "Train Fever Mod Manager" + #CRLF$ +
                       updater::VERSION$ + #CRLF$ +
                       "© 2014 – 2016 Alexander Nähring / Xanos" + #CRLF$ +
                       "Distributed on http://tfmm.xanos.eu/" +  #CRLF$ +
                       "unrar © Alexander L. Roshal")
    CompilerElse
      MessageRequester("License",
                       "Train Fever Mod Manager" + #CRLF$ +
                       updater::VERSION$ + #CRLF$ +
                       "© 2014 – 2016 Alexander Nähring / Xanos" + #CRLF$ +
                       "Distributed on http://tfmm.xanos.eu/")
    CompilerEndIf
  EndProcedure
  
  Procedure MenuItemSettings() ; open settings window
    Protected locale$
    windowSettings::show()
  EndProcedure
  
  Procedure MenuItemExportAll()
    mods::exportList(#True)
  EndProcedure
  
  Procedure MenuItemExportActivated()
    mods::exportList()
  EndProcedure
  
  
  ;- GADGETS
      
  Procedure GadgetNewMod()
    Protected file$
    If FileSize(main::TF$) <> -2
      ProcedureReturn #False
    EndIf
    file$ = OpenFileRequester(locale::l("management","select_mod"), "", locale::l("management","files_archive")+"|*.zip;*.rar|"+locale::l("management","files_all")+"|*.*", 0, #PB_Requester_MultiSelection)
    While file$
      If FileSize(file$) > 0
        queue::add(queue::#QueueActionNew, file$)
      EndIf
      file$ = NextSelectedFileName()
    Wend
  EndProcedure

  Procedure GadgetButtonInstall()
    debugger::Add("GadgetButtonInstall")
    Protected *mod.mods::mod, *last.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
      If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
        If Not *mod\aux\active
          *last = *mod
          count + 1
        EndIf
      EndIf
    Next i
    If count > 0
      If count = 1
        ClearMap(strings$())
        strings$("name") = *last\name$
        result = MessageRequester(locale::l("main","install"), locale::getEx("management", "install1", strings$()), #PB_MessageRequester_YesNo)
      Else
        ClearMap(strings$())
        strings$("count") = Str(count)
        result = MessageRequester(locale::l("main","install_pl"), locale::getEx("management", "install2", strings$()), #PB_MessageRequester_YesNo)
      EndIf
      
      If result = #PB_MessageRequester_Yes
        For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
          If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected
            *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
            If Not *mod\aux\active
              queue::add(queue::#QueueActionInstall, *mod\tf_id$)
            EndIf
          EndIf
        Next i
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetButtonRemove()
    debugger::Add("GadgetButtonRemove")
    Protected *mod.mods::mod, *last.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
      If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
        With *mod
          If \aux\active
            *last = *mod
            count + 1
          EndIf
        EndWith
      EndIf
    Next i
    If count > 0
      If count = 1
        ClearMap(strings$())
        strings$("name") = *last\name$
        result = MessageRequester(locale::l("main","remove"), locale::getEx("management", "remove1", strings$()), #PB_MessageRequester_YesNo)
      Else
        ClearMap(strings$())
        strings$("count") = Str(count)
        result = MessageRequester(locale::l("main","remove_pl"), locale::getEx("management", "remove2", strings$()), #PB_MessageRequester_YesNo)
      EndIf
      
      If result = #PB_MessageRequester_Yes
        For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
          If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected 
            *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
            With *mod
              If \aux\active
                queue::add(queue::#QueueActionRemove, *mod\tf_id$)
              EndIf
            EndWith
          EndIf
        Next i
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetButtonDelete()
    debugger::Add("GadgetButtonDelete")
    Protected *mod.mods::mod, *last.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
      If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
        *last = *mod
        count + 1
      EndIf
    Next i
    If count > 0
      If count = 1
        ClearMap(strings$())
        strings$("name") = *last\name$
        result = MessageRequester(locale::l("main","delete"), locale::getEx("management", "delete1", strings$()), #PB_MessageRequester_YesNo)
      Else
        ClearMap(strings$())
        strings$("count") = Str(count)
        result = MessageRequester(locale::l("main","delete_pl"), locale::getEx("management", "delete2", strings$()), #PB_MessageRequester_YesNo)
      EndIf
      
      If result = #PB_MessageRequester_Yes
        For i = 0 To CountGadgetItems(GadgetLibraryMods) - 1
          If GetGadgetItemState(GadgetLibraryMods, i) & #PB_ListIcon_Selected
            *mod = ListIcon::GetListItemData(GadgetLibraryMods, i)
            If *mod\aux\active
              queue::add(queue::#QueueActionRemove, *mod\tf_id$)
            EndIf
            queue::add(queue::#QueueActionDelete, *mod\tf_id$)
          EndIf
        Next i
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetLibraryMods()
    Protected *mod.mods::mod
    Protected position, event
    
    updateGUI()
    
    Select EventType()
      Case #PB_EventType_LeftDoubleClick
        GadgetButtonInformation()
      Case #PB_EventType_RightClick
        DisplayPopupMenu(MenuLibrary, WindowID(windowMain::id))
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
  
  Procedure GadgetButtonInformation()
    Protected *mod.mods::mod
    Protected SelectedMod, i, Gadget
    Protected tfnet_mod_url$
    
    ; init
    SelectedMod = GetGadgetState(GadgetLibraryMods)
    If SelectedMod = -1
      ProcedureReturn #False
    EndIf
    *mod = ListIcon::GetListItemData(GadgetLibraryMods, SelectedMod)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    windowInformation::create(windowMain::id)
    windowInformation::setMod(*mod)
    ProcedureReturn #True
  EndProcedure
  
  Procedure GadgetFilterMods()
    mods::displayMods(GetGadgetText(GadgetFilterMods))
  EndProcedure
  
  Procedure GadgetResetFilterMods()
    SetGadgetText(GadgetFilterMods, "")
    SetActiveGadget(GadgetFilterMods)
  EndProcedure
  
  Procedure GadgetDLCToggle()
    Protected *mod.mods::mod
    *mod = GetGadgetData(GadgetDLCToggle)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    If *mod\aux\active
      queue::add(queue::#QueueActionRemove, *mod\tf_id$)
    Else
      queue::add(queue::#QueueActionInstall, *mod\tf_id$)
    EndIf
  EndProcedure
  
  ; DRAG & DROP
  
  Procedure HandleDroppedFiles(Files$)
    Protected count, i
    Protected file$
    
    debugger::Add("dropped files:")
    count  = CountString(files$, Chr(10)) + 1
    For i = 1 To count
      file$ = StringField(files$, i, Chr(10))
      queue::add(queue::#QueueActionNew, file$)
    Next i
  EndProcedure
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create()
    Protected width, height
    width = 750
    height = 480
    
    id = OpenWindow(#PB_Any, 0, 0, width, height, "Train Fever Mod Manager", #PB_Window_SystemMenu | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget | #PB_Window_SizeGadget | #PB_Window_TitleBar | #PB_Window_ScreenCentered)
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      ; Mac OS X has predefined shortcuts
      AddKeyboardShortcut(id, #PB_Shortcut_Control | #PB_Shortcut_S, #PB_Menu_Preferences)
      AddKeyboardShortcut(id, #PB_Shortcut_Alt | #PB_Shortcut_F4, #PB_Menu_Quit)
      AddKeyboardShortcut(id, #PB_Shortcut_Control | #PB_Shortcut_L, #PB_Menu_About)
    CompilerEndIf
    AddKeyboardShortcut(id, #PB_Shortcut_Control | #PB_Shortcut_O, #MenuItem_AddMod)
    AddKeyboardShortcut(id, #PB_Shortcut_Control | #PB_Shortcut_E, #MenuItem_ExportListActivated)
    AddKeyboardShortcut(id, #PB_Shortcut_Alt | #PB_Shortcut_E, #MenuItem_ExportListAll)
    AddKeyboardShortcut(id, #PB_Shortcut_F1, #MenuItem_Homepage)
    AddKeyboardShortcut(id, #PB_Shortcut_F5, #MenuItem_Update)
    
    UseModule locale ; import locale namespace for shorthand "l()" access
    
    CreateMenu(0, WindowID(id))
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      MenuTitle(l("menu","file"))
    CompilerEndIf
    MenuItem(#PB_Menu_Preferences, l("menu","settings") + Chr(9) + "Ctrl + S")
    MenuItem(#PB_Menu_Quit, l("menu","close") + Chr(9) + "Alt + F4")
    MenuTitle(l("menu","mods"))
    MenuItem(#MenuItem_AddMod, l("menu","mod_add") + Chr(9) + "Ctrl + O")
    OpenSubMenu(l("menu","mod_export"))
    MenuItem(#MenuItem_ExportListActivated, l("menu","mod_export_active") + Chr(9) + "Ctrl + E")
    MenuItem(#MenuItem_ExportListAll, l("menu","mod_export_all") + Chr(9) + "Alt + E")
    CloseSubMenu()
    MenuTitle(l("menu","about"))
    MenuItem(#MenuItem_Homepage, l("menu","homepage") + Chr(9) + "F1")
    MenuItem(#MenuItem_Update, l("menu","update") + Chr(9) + "F5")
    MenuItem(#PB_Menu_About, l("menu","license") + Chr(9) + "Ctrl + L")
    
    BindMenuEvent(0, #PB_Menu_Preferences, @MenuItemSettings())
    BindMenuEvent(0, #PB_Menu_Quit, main::@exit())
    BindMenuEvent(0, #MenuItem_AddMod, @MenuItemNewMod())
    BindMenuEvent(0, #MenuItem_ExportListActivated, @MenuItemExportActivated())
    BindMenuEvent(0, #MenuItem_ExportListAll, @MenuItemExportAll())
    BindMenuEvent(0, #MenuItem_Homepage, @MenuItemHomepage())
    BindMenuEvent(0, #MenuItem_Update, @MenuItemUpdate())
    BindMenuEvent(0, #PB_Menu_About, @MenuItemLicense())
    
    GadgetMainPanel = PanelGadget(#PB_Any, 5, 10, 740, 410)
    ; MODs
    AddGadgetItem(GadgetMainPanel, -1, l("main","mods"))
    
    GadgetImageLogo = ImageGadget(#PB_Any, 0, 0, 0, 0, 0)
    GadgetFrameFilter = FrameGadget(#PB_Any, 0, 0, 0, 0, l("main","filter"))
    GadgetFilterMods = StringGadget(#PB_Any, 0, 0, 0, 0, "")
    GadgetResetFilterMods = ButtonGadget(#PB_Any, 0, 0, 0, 0, "X")
    GadgetFrameManagement = FrameGadget(#PB_Any, 0, 0, 0, 0, l("main","management"))
    GadgetButtonDelete = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main","delete"))
    GadgetButtonInstall = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main","install"))
    GadgetButtonRemove = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main","remove"))
    GadgetFrameInformation = FrameGadget(#PB_Any, 0, 0, 0, 0, l("main","information"))
    GadgetButtonInformation = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main","information"))
    
    GadgetLibraryMods = ListIconGadget(#PB_Any, 0, 0, 0, 0, l("main","name"), 240, #PB_ListIcon_MultiSelect | #PB_ListIcon_GridLines | #PB_ListIcon_FullRowSelect | #PB_ListIcon_AlwaysShowSelection)
    AddGadgetColumn(GadgetLibraryMods, 1, l("main","author"), 90)
    AddGadgetColumn(GadgetLibraryMods, 2, l("main","category"), 90)
    AddGadgetColumn(GadgetLibraryMods, 3, l("main","version"), 60)
    
    ; DLCs
    AddGadgetItem(GadgetMainPanel, -1, l("main","dlcs"))
    
    GadgetDLCScrollAreaList = ScrollAreaGadget(#PB_Any, 0, 0, 0, 0, 0, 0, 10, #PB_ScrollArea_Center|#PB_ScrollArea_Flat)
    SetGadgetColor(GadgetDLCScrollAreaList, #PB_Gadget_BackColor, RGB(255,255,255))
    CloseGadgetList()
    GadgetDLCName = TextGadget(#PB_Any, 0, 0, 0, 0, "", #PB_Text_Center)
    LoadFont(0, "", 18)
    SetGadgetColor(GadgetDLCName, #PB_Gadget_FrontColor, RGB(131, 21, 85))
    SetGadgetFont(GadgetDLCName, FontID(0))
    ; GadgetLibraryDLCs = ListViewGadget(#PB_Any, 0, 0, 0, 0)
    ; GadgetDLCInstall = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main","install_dlc"))
    GadgetDLCToggle = ButtonGadget(#PB_Any, 0, 0, 0, 0, l("main","remove_dlc"))
    GadgetDLCScrollAreaAuthors = ScrollAreaGadget(#PB_Any, 0, 0, 0, 0, 0, 0, 10, #PB_ScrollArea_Center|#PB_ScrollArea_BorderLess)
    SetGadgetColor(GadgetDLCScrollAreaAuthors, #PB_Gadget_BackColor, RGB(255,255,255))
    TextGadget(#PB_Any, 0, 0, 0, 0, "") ; not used, just for "offset/padding" of gadgets inside of scroll area
    CloseGadgetList()
    HideGadget(GadgetDLCToggle, #True)
    HideGadget(GadgetDLCName, #True)
    HideGadget(GadgetDLCScrollAreaAuthors, #True)
    
    ; AddGadgetItem(GadgetMainPanel, -1, "Savegames")
    
    ; Maps
    AddGadgetItem(GadgetMainPanel, -1, l("main","maps"))
    
    
    CloseGadgetList()
    
    GadgetImageHeader = ImageGadget(#PB_Any, 0, 0, 750, 8, 0)
    GadgetNewMod = ButtonGadget(#PB_Any, 10, 425, 120, 25, l("main","new_mod"))
    GadgetHomepage = ButtonGadget(#PB_Any, 140, 425, 120, 25, l("main","download"))
    GadgetButtonStartGame = ButtonGadget(#PB_Any, 270, 425, 250, 25, l("main","start_tf"), #PB_Button_Default)
    GadgetVersionText = TextGadget(#PB_Any, 530, 430, 210, 20, updater::VERSION$, #PB_Text_Right)
    
    ; Bind Gadget Events
    BindGadgetEvent(GadgetNewMod, @GadgetNewMod())
    BindGadgetEvent(GadgetButtonInstall, @GadgetButtonInstall())
    BindGadgetEvent(GadgetButtonRemove, @GadgetButtonRemove())
    BindGadgetEvent(GadgetButtonDelete, @GadgetButtonDelete())
    BindGadgetEvent(GadgetLibraryMods, @GadgetLibraryMods())
    BindGadgetEvent(GadgetButtonStartGame, @GadgetButtonStartGame())
;     BindGadgetEvent(GadgetHomepage, @GadgetButtonTrainFeverNet())
    BindGadgetEvent(GadgetHomepage, @GadgetButtonTrainFeverNetDownloads())
    BindGadgetEvent(GadgetImageLogo, @GadgetImageMain())
    BindGadgetEvent(GadgetButtonInformation, @GadgetButtonInformation())
    BindGadgetEvent(GadgetFilterMods, @GadgetFilterMods(), #PB_EventType_Change)
    BindGadgetEvent(GadgetResetFilterMods, @GadgetResetFilterMods(), #PB_EventType_LeftClick)
    ;
    BindGadgetEvent(GadgetDLCToggle, @GadgetDLCToggle())
    
    ; Set window boundaries, timers, events
    WindowBounds(id, 700, 400, #PB_Ignore, #PB_Ignore) 
    AddWindowTimer(id, TimerMainGadgets, 100)
    BindEvent(#PB_Event_SizeWindow, @resize(), id)
    BindEvent(#PB_Event_MaximizeWindow, @resize(), id)
    BindEvent(#PB_Event_RestoreWindow, @resize(), id)
    
    
    ; OS specific
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        SetWindowTitle(id, GetWindowTitle(id) + " for Windows")
        ListIcon::DefineListCallback(GadgetLibraryMods)
      CompilerCase #PB_OS_Linux
        SetWindowTitle(id, GetWindowTitle(id) + " for Linux")
      CompilerCase #PB_OS_MacOS
        SetWindowTitle(id, GetWindowTitle(id) + " for MacOS")
    CompilerEndSelect
    
    
    ; indicate testmode in window title
    If main::_TESTMODE
      SetWindowTitle(id, GetWindowTitle(id) + " (Test Mode Enabled)")
    EndIf
    
    ; load images
    ResizeImage(images::Images("headermain"), GadgetWidth(GadgetImageHeader), GadgetHeight(GadgetImageHeader), #PB_Image_Raw)
    SetGadgetState(GadgetImageHeader, ImageID(images::Images("headermain")))
    SetGadgetState(GadgetImageLogo, ImageID(images::Images("logo")))
;     SetGadgetState(ImageGadgetInformationheader, ImageID(images::Images("header")))
    
    ; right click menu
    MenuLibrary = CreatePopupImageMenu(#PB_Any)
    MenuItem(#MenuItem_Information, l("main","information"))
    MenuBar()
    MenuItem(#MenuItem_Install, l("main","install"), ImageID(images::Images("yes")))
    MenuItem(#MenuItem_Remove, l("main","remove"), ImageID(images::Images("no")))
    MenuItem(#MenuItem_Delete, l("main","delete"))
    
    BindMenuEvent(MenuLibrary, #MenuItem_Information, @GadgetButtonInformation())
    BindMenuEvent(MenuLibrary, #MenuItem_Install, @GadgetButtonInstall())
    BindMenuEvent(MenuLibrary, #MenuItem_Remove, @GadgetButtonRemove())
    BindMenuEvent(MenuLibrary, #MenuItem_Delete, @GadgetButtonDelete())
    
    ; Drag & Drop
    EnableWindowDrop(id, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
    
    ; register to mods module
    mods::registerMainWindow(id)
    mods::registerModGadget(GadgetLibraryMods)
    mods::registerDLCGadget(GadgetDLCScrollAreaList)
    
    ; apply sizes
    resize()
    
    ; init gui
    updateGUI()
    
    UnuseModule locale
  EndProcedure
  
  Procedure events(event)
    Select event
      Case #PB_Event_SizeWindow
        ; already bound to window, no handling required
      Case #PB_Event_CloseWindow
        main::exit()
      Case #PB_Event_Menu
        ;bound
        
      Case #PB_Event_Gadget
        ;bound
        
      Case #PB_Event_Timer
        Select EventTimer()
          Case TimerMainGadgets
            TimerMain()
        EndSelect
        
      Case #PB_Event_WindowDrop
        HandleDroppedFiles(EventDropFiles())
        
    EndSelect
    ProcedureReturn #True
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
  
  Procedure dlcGadgetEvent()
    Protected *mod.mods::mod
    Protected i, count, string$
    Protected y
    *mod = GetGadgetData(EventGadget())
    debugger::add("windowMain::dlcGadgetEvent() - show mod info for mod "+*mod)
    
    Static NewList gadgetsDLCAuthors()
    
    SetGadgetData(GadgetDLCToggle, 0)
    HideGadget(GadgetDLCToggle, #True)
    HideGadget(GadgetDLCName, #True)
    HideGadget(GadgetDLCScrollAreaAuthors, #True)
    ForEach gadgetsDLCAuthors()
      If IsGadget(gadgetsDLCAuthors())
        FreeGadget(gadgetsDLCAuthors())
      EndIf
    Next
    ClearList(gadgetsDLCAuthors())
    SetGadgetAttribute(GadgetDLCScrollAreaAuthors, #PB_ScrollArea_InnerWidth, 0)
    SetGadgetAttribute(GadgetDLCScrollAreaAuthors, #PB_ScrollArea_InnerHeight, 0)
    
    If *mod
      If Not *mod\isDLC
        ProcedureReturn #False
      EndIf
      Select *mod\tf_id$
        Case "usa_1"
        Case "nordic_1"
        Default
          ProcedureReturn #False
      EndSelect
      
      If *mod\tf_id$ = "usa_1"
        SetGadgetText(GadgetDLCName, "USA DLC")
        OpenGadgetList(GadgetDLCScrollAreaAuthors)
        AddElement(gadgetsDLCAuthors())
        gadgetsDLCAuthors() = TextGadget(#PB_Any, 10, 10, 440, 20, "Official DLC by Urban Games")
        SetGadgetColor(gadgetsDLCAuthors(), #PB_Gadget_FrontColor, RGB(131, 21, 85))
        SetGadgetColor(gadgetsDLCAuthors(), #PB_Gadget_BackColor, RGB(255, 255, 255))
        CloseGadgetList()
        SetGadgetAttribute(GadgetDLCScrollAreaAuthors, #PB_ScrollArea_InnerWidth, 460)
        SetGadgetAttribute(GadgetDLCScrollAreaAuthors, #PB_ScrollArea_InnerHeight, 40)
        
        SetGadgetData(GadgetDLCToggle, 0)
        HideGadget(GadgetDLCToggle, #False)
        DisableGadget(GadgetDLCToggle, #True)
      Else
        SetGadgetText(GadgetDLCName, *mod\name$+" DLC")
        y = 10
        OpenGadgetList(GadgetDLCScrollAreaAuthors)
        ForEach *mod\authors()
          AddElement(gadgetsDLCAuthors())
          If *mod\authors()\tfnetId
            gadgetsDLCAuthors() = HyperLinkGadget(#PB_Any, 10, y, 90, 20, *mod\authors()\name$, RGB(131, 21, 85))
          Else
            gadgetsDLCAuthors() = TextGadget(#PB_Any, 10, y, 90, 20, *mod\authors()\name$)
          EndIf
          SetGadgetColor(gadgetsDLCAuthors(), #PB_Gadget_FrontColor, RGB(131, 21, 85))
          SetGadgetColor(gadgetsDLCAuthors(), #PB_Gadget_BackColor, RGB(255, 255, 255))
          count = CountString(*mod\authors()\text$, ",")
          For i = 1 To count+1
            ; image element of author description
;             AddElement(gadgetsDLCAuthors())
;             gadgetsDLCAuthors() = ImageGadget(#PB_Any, 110, y, 330, 20, Trim(StringField(*mod\authors()\text$, i, ",")))
            ; text element of author description
            AddElement(gadgetsDLCAuthors())
            gadgetsDLCAuthors() = TextGadget(#PB_Any, 110, y, 330, 20, Trim(StringField(*mod\authors()\text$, i, ",")))
            SetGadgetColor(gadgetsDLCAuthors(), #PB_Gadget_BackColor, RGB(255, 255, 255))
            y + 25
          Next
          
          AddElement(gadgetsDLCAuthors())
          gadgetsDLCAuthors() = CanvasGadget(#PB_Any, 0, y, 460, 1)
          StartDrawing(CanvasOutput(gadgetsDLCAuthors()))
          Box(0, 0, 460, 1, RGB(65, 62, 57)) ; dark grey
          StopDrawing()
          
          SetGadgetAttribute(GadgetDLCScrollAreaAuthors, #PB_ScrollArea_InnerWidth, 460)
          SetGadgetAttribute(GadgetDLCScrollAreaAuthors, #PB_ScrollArea_InnerHeight, y)
          y + 15
        Next
        CloseGadgetList()
        
        SetGadgetData(GadgetDLCToggle, *mod)
        HideGadget(GadgetDLCToggle, #False)
        DisableGadget(GadgetDLCToggle, #False)
      EndIf
      
      If *mod\aux\active
        SetGadgetText(GadgetDLCToggle, locale::l("main","remove_dlc"))
      Else
        SetGadgetText(GadgetDLCToggle, locale::l("main","install_dlc"))
      EndIf
      HideGadget(GadgetDLCName, #False)
      HideGadget(GadgetDLCScrollAreaAuthors, #False)
    EndIf
  EndProcedure
  
  Procedure displayDLCs(Map *dlcs.mods::Mod())
    ; remove all old gadgets
    Static NewList gadgetsSelectDLC()
    Protected count, im
    
    ForEach gadgetsSelectDLC()
      UnbindGadgetEvent(gadgetsSelectDLC(), @dlcGadgetEvent(), #PB_Event_LeftClick)
      FreeGadget(gadgetsSelectDLC())
    Next
    ; display all DLCs
    debugger::add("          Open gadgetlist "+GadgetDLCScrollAreaList)
    OpenGadgetList(GadgetDLCScrollAreaList)
    ForEach *dlcs()
      If *dlcs()\isDLC
        ; container gadgets unfortunately do not throw events :(
        ; cannot use the container gadget as replacement for a complex button
;         AddElement(gadgetsSelectDLC())
;         gadgetsSelectDLC() = ContainerGadget(#PB_Any, count*160, 0, 150, 120, #PB_Container_Raised)
;         SetGadgetData(gadgetsSelectDLC(), *dlcs())
        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
          AddElement(gadgetsSelectDLC())
          gadgetsSelectDLC() = FrameGadget(#PB_Any, 0, count*130, 130, 120, "", #PB_Frame_Flat)
        CompilerEndIf
        ; Image
        AddElement(gadgetsSelectDLC())
        im = mods::getPreviewImage(*dlcs())
        If IsImage(im)
          im = ImageID(im)
        Else
          im = 0
        EndIf
        gadgetsSelectDLC() = ImageGadget(#PB_Any, 5, count*130+5, 120, 80, im)
        SetGadgetData(gadgetsSelectDLC(), *dlcs())
        BindGadgetEvent(gadgetsSelectDLC(), @dlcGadgetEvent())
        ; Text
        AddElement(gadgetsSelectDLC())
        gadgetsSelectDLC() = ButtonGadget(#PB_Any, 5, count*130+90, 120, 25, *dlcs()\name$)
        SetGadgetData(gadgetsSelectDLC(), *dlcs())
        BindGadgetEvent(gadgetsSelectDLC(), @dlcGadgetEvent())
        
        count + 1
;         CloseGadgetList()
        ; Size of scrollarea
        SetGadgetAttribute(GadgetDLCScrollAreaList, #PB_ScrollArea_InnerWidth, 130)
        SetGadgetAttribute(GadgetDLCScrollAreaList, #PB_ScrollArea_InnerHeight, count*130)
      EndIf
    Next
    CloseGadgetList()
  EndProcedure
  
  
  Procedure displayMods()
    
  EndProcedure
  
  
EndModule
