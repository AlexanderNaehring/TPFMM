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
EndDeclareModule

XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowInformation.pbi"
XIncludeFile "module_windowSettings.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_updater.pbi"

Module windowMain

  ; rightclick menu on library gadget
  Global MenuLibrary
  Enumeration 100
    #MenuItem_Install
    #MenuItem_Remove
    #MenuItem_Delete
    #MenuItem_Information
  EndEnumeration
  
  ; gadgets
  Global GadgetNewMod, GadgetHomepage, GadgetStartGame, GadgetImageLogo, GadgetDelete, GadgetInstall, GadgetRemove, GadgetImageHeader, TextGadgetVersion, GadgetButtonInformation, FrameGadget, FrameGadget2, GadgetMainPanel
  Global LibraryMods, LibraryDLCs
  
  ; timer
  Global TimerMainGadgets = 101
  
  ; other stuff
  Global NewMap PreviewImages.i()
  Global _noUpdate
  
  Declare resize()
  Declare updateGUI()
  
  
  Declare MenuItemHomepage(Event)
  Declare MenuItemSettings(Event)
  Declare MenuItemLicense(Event)
  Declare GadgetNewMod(Event)
  Declare MenuItemExportAll(Event)
  Declare MenuItemUpdate(Event)
  Declare MenuItemExportActivated(Event)
  Declare GadgetButtonDelete(EventType)
  Declare GadgetLibrary(EventType)
  Declare GadgetImageMain(EventType)
  Declare GadgetButtonInformation(EventType)
  Declare GadgetNewMod(EventType)
  Declare GadgetButtonStartGame(EventType)
  Declare GadgetButtonTrainFeverNetDownloads(EventType)
  Declare GadgetButtonInstall(EventType)
  Declare GadgetButtonRemove(EventType)
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  
  Procedure resize()
    Protected width, height
    width = WindowWidth(id)
    height = WindowHeight(id)
    ResizeGadget(GadgetNewMod, 10, height - 55, 120, 25)
    ResizeGadget(GadgetHomepage, 140, height - 55, 120, 25)
    ResizeGadget(GadgetStartGame, 270, height - 55, width - 500, 25)
    ResizeGadget(GadgetImageLogo, width - 220, 15, 210, 118)
    ResizeGadget(GadgetDelete, width - 210, 240, 190, 30)
    ResizeGadget(GadgetInstall, width - 210, 160, 190, 30)
    ResizeGadget(GadgetMainPanel, 10, 10, width - 240, height - misc::max(MenuHeight(), 20) - 50) ; height - MenuHeight() - 50
    ResizeGadget(LibraryMods, 0, 0, GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemWidth), GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemHeight))
    ResizeGadget(GadgetRemove, width - 210, 200, 190, 30)
    ResizeGadget(GadgetImageHeader, 0, 0, width - 0, 8)
    ResizeGadget(TextGadgetVersion, width - 220, height - 50, 210, 20)
    ResizeGadget(GadgetButtonInformation, width - 210, 310, 190, 30)
    ResizeGadget(FrameGadget, width - 220, 140, 210, 140)
    ResizeGadget(FrameGadget2, width - 220, 290, 210, 60)
    
    ResizeImage(images::Images("headermain"), GadgetWidth(GadgetImageHeader), GadgetHeight(GadgetImageHeader), #PB_Image_Raw)
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
    
    For i = 0 To CountGadgetItems(LibraryMods) - 1
      *mod = ListIcon::GetListItemData(LibraryMods, i)
      If Not *mod
        Continue
      EndIf
      If *mod\aux\active
        countActive + 1
      Else
        countInactive + 1
      EndIf
      If GetGadgetItemState(LibraryMods, i) & #PB_ListIcon_Selected
        SelectedMod = i
        If *mod\aux\active
          selectedActive + 1
        Else
          selectedInactive + 1
        EndIf
      EndIf
    Next
    
    SelectedMod =  GetGadgetState(LibraryMods)
    If SelectedMod = -1 ; if nothing is selected -> disable buttons
      DisableGadget(GadgetInstall, #True)
      DisableGadget(GadgetRemove, #True)
      DisableGadget(GadgetDelete, #True)
      DisableGadget(GadgetButtonInformation, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Install, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Remove, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_delete, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Information, #True)
    Else
      DisableGadget(GadgetDelete, #False) ; delete is always possible!
      DisableMenuItem(MenuLibrary, #MenuItem_delete, #False)
      If selectedActive > 0 ; if at least one of the mods is active
        DisableGadget(GadgetRemove, #False)
        DisableMenuItem(MenuLibrary, #MenuItem_Remove, #False)
      Else  ; if no mod is active 
        DisableGadget(GadgetRemove, #True)
        DisableMenuItem(MenuLibrary, #MenuItem_Remove, #True)
      EndIf
      If selectedInactive > 0 ; if at least one of the mods is not active
        DisableGadget(GadgetInstall, #False)
        DisableMenuItem(MenuLibrary, #MenuItem_Install, #False)
      Else ; if none of the selected mods is inactive
        DisableGadget(GadgetInstall, #True)  ; disable activate button
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
        SetGadgetText(GadgetDelete, locale::l("main","delete_pl"))
        SetMenuItemText(MenuLibrary, #MenuItem_delete, locale::l("main","delete_pl"))
      Else
        SetGadgetText(Gadgetdelete, locale::l("main","delete"))
        SetMenuItemText(MenuLibrary, #MenuItem_delete, locale::l("main","delete"))
      EndIf
      If selectedActive > 1
        SetGadgetText(GadgetRemove, locale::l("main","remove_pl"))
        SetMenuItemText(MenuLibrary, #MenuItem_Remove, locale::l("main","remove_pl"))
      Else
        SetGadgetText(GadgetRemove, locale::l("main","remove"))
        SetMenuItemText(MenuLibrary, #MenuItem_Remove, locale::l("main","remove"))
      EndIf
      If selectedInactive > 1
        SetGadgetText(GadgetInstall, locale::l("main","install_pl"))
        SetMenuItemText(MenuLibrary, #MenuItem_Install, locale::l("main","install_pl"))
      Else
        SetGadgetText(GadgetInstall, locale::l("main","install"))
        SetMenuItemText(MenuLibrary, #MenuItem_Install, locale::l("main","install"))
      EndIf
    EndIf
    
    If selectedActive + selectedInactive = 1
      ; one mod selected
      ; display image
      *mod = ListIcon::GetListItemData(LibraryMods, SelectedMod)
      If Not IsImage(PreviewImages(*mod\tf_id$)) ; if image is not yet loaded
        Protected im.i, image$
        
        If *mod\aux\active
          image$ = misc::Path(main::TF$ + "mods/" + *mod\tf_id$) + "image_00.tga"
          If FileSize(image$) > 0
            im = LoadImage(#PB_Any, image$)
          EndIf
        ElseIf *mod\aux\inLibrary
          image$ = misc::Path(main::TF$ + "TFMM/library/" + *mod\tf_id$) + "preview.png"
          If FileSize(image$) > 0
            im = LoadImage(#PB_Any, image$)
          EndIf
        EndIf
        
        ; if load was successfull
        If IsImage(im)
          im = misc::ResizeCenterImage(im, GadgetWidth(GadgetImageLogo), GadgetHeight(GadgetImageLogo), #PB_Image_Smooth)
          If IsImage(im)
            PreviewImages(*mod\tf_id$) = im
          EndIf
        EndIf
      EndIf
      ; if image is loaded now
      If IsImage(PreviewImages(*mod\tf_id$))
        ; display image
        If GetGadgetState(GadgetImageLogo) <> ImageID(PreviewImages(*mod\tf_id$))
          debugger::Add("ImageLogo: Display custom image")
          SetGadgetState(GadgetImageLogo, ImageID(PreviewImages(*mod\tf_id$)))
        EndIf
      Else
        ; else: display normal logo
        If GetGadgetState(GadgetImageLogo) <> ImageID(images::Images("logo"))
          debugger::Add("ImageLogo: Display tf|net logo instead of custom image")
          SetGadgetState(GadgetImageLogo, ImageID(images::Images("logo")))
        EndIf
      EndIf
    Else
      If GetGadgetState(GadgetImageLogo) <> ImageID(images::Images("logo"))
        debugger::Add("ImageLogo: Display tf|net logo")
        SetGadgetState(GadgetImageLogo, ImageID(images::Images("logo")))
      EndIf
    EndIf
  EndProcedure
  
  ;-------------------------------------------------
  ; TIMER
  
  Procedure TimerMain()
    Static LastDir$ = ""
    
    If LastDir$ <> main::TF$
      LastDir$ = main::TF$
      If misc::checkTFPath(main::TF$) <> #True
        main::ready = #False  ; flag for mod management
        MenuItemSettings(0)
      EndIf
    EndIf
    
    queue::update()
    
  EndProcedure
  
  ; MENU
  
  Procedure MenuItemHomepage(event)
    misc::openLink("http://goo.gl/utB3xn") ; Download Page TFMM (Train-Fever.net)
  EndProcedure
  
  Procedure MenuItemUpdate(event)
    CreateThread(updater::@checkUpdate(), 0)
  EndProcedure
  
  Procedure MenuItemLicense(event)
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      MessageRequester("License",
                       "Train Fever Mod Manager" + #CRLF$ +
                       updater::VERSION$ + #CRLF$ +
                       "© 2014 – 2015 Alexander Nähring / Xanos" + #CRLF$ +
                       "Distributed on http://tfmm.xanos.eu/" +  #CRLF$ +
                       "unrar © Alexander L. Roshal")
    CompilerElse
      MessageRequester("License",
                       "Train Fever Mod Manager" + #CRLF$ +
                       updater::#VERSION$ + #CRLF$ +
                       "© 2014 – 2015 Alexander Nähring / Xanos" + #CRLF$ +
                       "Distributed on http://tfmm.xanos.eu/")
    CompilerEndIf
  EndProcedure
  
  Procedure MenuItemSettings(event) ; open settings window
    Protected locale$
    windowSettings::show()
  EndProcedure
  
  Procedure MenuItemExportAll(event)
    mods::exportList(#True)
  EndProcedure
  
  Procedure MenuItemExportActivated(event)
    mods::exportList()
  EndProcedure

  ; GADGETS
      
  Procedure GadgetNewMod(event)
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

  Procedure GadgetButtonInstall(event)
    debugger::Add("GadgetButtonInstall")
    Protected *mod.mods::mod, *last.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(LibraryMods) - 1
      If GetGadgetItemState(LibraryMods, i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(LibraryMods, i)
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
        For i = 0 To CountGadgetItems(LibraryMods) - 1
          If GetGadgetItemState(LibraryMods, i) & #PB_ListIcon_Selected
            *mod = ListIcon::GetListItemData(LibraryMods, i)
            If Not *mod\aux\active
              queue::add(queue::#QueueActionInstall, *mod\tf_id$)
            EndIf
          EndIf
        Next i
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetButtonRemove(event)
    debugger::Add("GadgetButtonRemove")
    Protected *mod.mods::mod, *last.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(LibraryMods) - 1
      If GetGadgetItemState(LibraryMods, i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(LibraryMods, i)
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
        For i = 0 To CountGadgetItems(LibraryMods) - 1
          If GetGadgetItemState(LibraryMods, i) & #PB_ListIcon_Selected 
            *mod = ListIcon::GetListItemData(LibraryMods, i)
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
  
  Procedure GadgetButtonDelete(event)
    debugger::Add("GadgetButtonDelete")
    Protected *mod.mods::mod, *last.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(LibraryMods) - 1
      If GetGadgetItemState(LibraryMods, i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(LibraryMods, i)
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
        For i = 0 To CountGadgetItems(LibraryMods) - 1
          If GetGadgetItemState(LibraryMods, i) & #PB_ListIcon_Selected
            *mod = ListIcon::GetListItemData(LibraryMods, i)
            If *mod\aux\active
              queue::add(queue::#QueueActionRemove, *mod\tf_id$)
            EndIf
            queue::add(queue::#QueueActionDelete, *mod\tf_id$)
          EndIf
        Next i
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetLibrary(event)
    Protected *mod.mods::mod
    Protected position
    
    updateGUI()
    
    If event = #PB_EventType_LeftDoubleClick
      GadgetButtonInformation(#PB_EventType_LeftClick)
    ElseIf event = #PB_EventType_RightClick
      DisplayPopupMenu(MenuLibrary, WindowID(windowMain::id))
    EndIf
  EndProcedure
  
  Procedure GadgetButtonStartGame(event)
    misc::openLink("steam://run/304730/")
  EndProcedure
  
  Procedure GadgetButtonTrainFeverNet(event)
    misc::openLink("http://goo.gl/8Dsb40") ; Homepage (Train-Fever.net)
  EndProcedure
  
  Procedure GadgetButtonTrainFeverNetDownloads(event)
    misc::openLink("http://goo.gl/Q75VIM") ; Downloads / Filebase (Train-Fever.net)
  EndProcedure
  
  Procedure GadgetImageMain(event)
    If event = #PB_EventType_LeftClick
      If GetGadgetState(GadgetImageLogo) = ImageID(images::Images("logo"))
        GadgetButtonTrainFeverNet(event)
      EndIf
    EndIf
  EndProcedure
  
  ; TODO move information handler to information module, only call this module from here
  Procedure GadgetButtonInformation(event)
    Protected *mod.mods::mod
    Protected SelectedMod, i, Gadget
    Protected tfnet_mod_url$
    
    ; init
    SelectedMod = GetGadgetState(LibraryMods)
    If SelectedMod = -1
      ProcedureReturn #False
    EndIf
    *mod = ListIcon::GetListItemData(LibraryMods, SelectedMod)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    windowInformation::create(windowMain::id)
    windowInformation::setMod(*mod)
    ProcedureReturn #True
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
    AddKeyboardShortcut(id, #PB_Shortcut_Control | #PB_Shortcut_H, #MenuItem_Homepage)
    AddKeyboardShortcut(id, #PB_Shortcut_Control | #PB_Shortcut_U, #MenuItem_Update)
    
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
    MenuItem(#MenuItem_Homepage, l("menu","homepage") + Chr(9) + "Ctrl + H")
    MenuItem(#MenuItem_Update, l("menu","update") + Chr(9) + "Ctrl + U")
    MenuItem(#PB_Menu_About, l("menu","license") + Chr(9) + "Ctrl + L")
    
    GadgetMainPanel = PanelGadget(#PB_Any, 10, 10, 510, 410)
    AddGadgetItem(GadgetMainPanel, -1, l("menu","mods"))
    LibraryMods = ListIconGadget(#PB_Any, 0, 0, GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemWidth), GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemHeight), l("main","name"), 240, #PB_ListIcon_MultiSelect | #PB_ListIcon_GridLines | #PB_ListIcon_FullRowSelect | #PB_ListIcon_AlwaysShowSelection)
    AddGadgetColumn(LibraryMods, 1, l("main","author"), 90)
    AddGadgetColumn(LibraryMods, 2, l("main","category"), 90)
    AddGadgetColumn(LibraryMods, 3, l("main","version"), 60)
    
    AddGadgetItem(GadgetMainPanel, -1, l("menu","dlcs"))
    LibraryDLCs = ListIconGadget(#PB_Any, 0, 0, GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemWidth), GetGadgetAttribute(GadgetMainPanel, #PB_Panel_ItemHeight), l("main","name"), 240, #PB_ListIcon_MultiSelect | #PB_ListIcon_GridLines | #PB_ListIcon_FullRowSelect | #PB_ListIcon_AlwaysShowSelection)
    AddGadgetColumn(LibraryDLCs, 1, l("main","author"), 90)
    AddGadgetColumn(LibraryDLCs, 3, l("main","version"), 60)
    
    ; AddGadgetItem(GadgetMainPanel, -1, "Savegames")
    CloseGadgetList()
    
    GadgetNewMod = ButtonGadget(#PB_Any, 10, 425, 120, 25, l("main","new_mod"))
    GadgetHomepage = ButtonGadget(#PB_Any, 140, 425, 120, 25, l("main","download"))
    GadgetStartGame = ButtonGadget(#PB_Any, 270, 425, 250, 25, l("main","start_tf"), #PB_Button_Default)
    GadgetImageLogo = ImageGadget(#PB_Any, 530, 15, 210, 118, 0)
    GadgetDelete = ButtonGadget(#PB_Any, 540, 240, 190, 30, l("main","delete"))
    GadgetInstall = ButtonGadget(#PB_Any, 540, 160, 190, 30, l("main","install"))
    
    GadgetRemove = ButtonGadget(#PB_Any, 540, 200, 190, 30, l("main","remove"))
    GadgetImageHeader = ImageGadget(#PB_Any, 0, 0, 750, 8, 0)
    TextGadgetVersion = TextGadget(#PB_Any, 530, 430, 210, 20, updater::VERSION$, #PB_Text_Right)
    GadgetButtonInformation = ButtonGadget(#PB_Any, 540, 310, 190, 30, l("main","information"))
    FrameGadget = FrameGadget(#PB_Any, 530, 140, 210, 140, l("main","management"))
    FrameGadget2 = FrameGadget(#PB_Any, 530, 290, 210, 60, l("main","information"))
    
    ; Set window boundaries, timers, events
    WindowBounds(id, 700, 400, #PB_Ignore, #PB_Ignore) 
    AddWindowTimer(id, TimerMainGadgets, 100)
    BindEvent(#PB_Event_SizeWindow, @resize(), id)
    
    ; OS specific
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        SetWindowTitle(id, GetWindowTitle(id) + " for Windows")
        ListIcon::DefineListCallback(LibraryMods, ListIcon::#Edit)
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
    
    ; Drag & Drop
    EnableWindowDrop(id, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
    
    ; library
    mods::registerModGadget(LibraryMods)
    
    ; init gui
    updateGUI()
    
    UnuseModule locale
  EndProcedure
  
  Procedure events(event)
    Select event
      Case #PB_Event_SizeWindow
        ;resize() ; already bound to window, no handling required
      Case #PB_Event_CloseWindow
        main::exit()
  
      Case #PB_Event_Menu
        Select EventMenu()
          Case #PB_Menu_Preferences
            MenuItemSettings(EventMenu())
          Case #PB_Menu_Quit
            main::exit()
          Case #MenuItem_AddMod
            GadgetNewMod(EventMenu())
          Case #MenuItem_ExportListActivated
            MenuItemExportActivated(EventMenu())
          Case #MenuItem_ExportListAll
            MenuItemExportAll(EventMenu())
          Case #MenuItem_Homepage
            MenuItemHomepage(EventMenu())
          Case #MenuItem_Update
            MenuItemUpdate(EventMenu())
          Case #PB_Menu_About
            MenuItemLicense(EventMenu())
          Case #MenuItem_Install
            GadgetButtonInstall(#PB_EventType_LeftClick)
          Case #MenuItem_Remove
            GadgetButtonRemove(#PB_EventType_LeftClick)
          Case #MenuItem_Delete
            GadgetButtonDelete(#PB_EventType_LeftClick)
          Case #MenuItem_Information
            GadgetButtonInformation(#PB_EventType_LeftClick)
        EndSelect
  
      Case #PB_Event_Gadget
        Select EventGadget()
          Case GadgetNewMod
            GadgetNewMod(EventType())
          Case GadgetHomepage
            GadgetButtonTrainFeverNetDownloads(EventType())
          Case GadgetStartGame
            GadgetButtonStartGame(EventType())
          Case GadgetImageLogo
            GadgetImageMain(EventType())
          Case GadgetDelete
            GadgetButtonDelete(EventType())
          Case GadgetInstall
            GadgetButtonInstall(EventType())
          Case LibraryMods
            GadgetLibrary(EventType())
          Case GadgetRemove
            GadgetButtonRemove(EventType())
          Case GadgetButtonInformation
            GadgetButtonInformation(EventType())
        EndSelect
        
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
        SetGadgetItemAttribute(LibraryMods, #PB_Any, #PB_Explorer_ColumnWidth, ReadPreferenceInteger(Str(i), 0), i)
        ; Sorting
        ListIcon::SetColumnFlag(LibraryMods, i, ListIcon::#String)
      EndIf
    Next
  EndProcedure
  
  Procedure getColumnWidth(column)
    ProcedureReturn GetGadgetItemAttribute(LibraryMods, #PB_Any, #PB_Explorer_ColumnWidth, column)
  EndProcedure
  
EndModule
