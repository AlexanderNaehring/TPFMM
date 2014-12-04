EnableExplicit

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_mods.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "WindowMain.pbf"
XIncludeFile "WindowSettings.pbf"
XIncludeFile "WindowModProgress.pbf"
XIncludeFile "WindowModInformation.pbf"


Global TimerSettingsGadgets = 100, TimerMainGadgets = 101, TimerFinishUnInstall = 102, TimerUpdate = 103

Global NewMap PreviewImages.i()
Global NewList InformationGadgetAuthor() ; list of Gadget IDs for Author links

Global MenuListInstalled
Enumeration 100
  #MenuItem_Activate
  #MenuItem_Deactivate
  #MenuItem_Uninstall
  #MenuItem_Information
EndEnumeration

Declare updateGUI()
Declare ResizeUpdate()

; INIT

Procedure InitWindows()
  debugger::Add("init windows")
  
  ; Open Windows
  OpenWindowMain()
  OpenWindowSettings()
  OpenWindowModProgress()
  
  ; Set window boundaries, timers, events
  WindowBounds(WindowMain, 700, 400, #PB_Ignore, #PB_Ignore) 
  AddWindowTimer(WindowMain, TimerMainGadgets, 100)
  BindEvent(#PB_Event_SizeWindow, @ResizeUpdate(), WindowMain)
  
  ; Init OS specific tools (list icon gadget)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    UseModule ListIcon
    DefineListCallback(ListInstalled, #Edit)
    UnuseModule ListIcon
  CompilerEndIf
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Linux
      SetWindowTitle(WindowMain, GetWindowTitle(WindowMain) + " for Linux")
    CompilerCase #PB_OS_MacOS
      SetWindowTitle(WindowMain, GetWindowTitle(WindowMain) + " for MacOS ALPHA")
  CompilerEndSelect
  
  ; load images
  ResizeImage(images::Images("headermain"), GadgetWidth(ImageGadgetHeader), GadgetHeight(ImageGadgetHeader), #PB_Image_Raw)
  SetGadgetState(ImageGadgetHeader, ImageID(images::Images("headermain")))
  SetGadgetState(ImageGadgetLogo, ImageID(images::Images("logo")))
;   SetGadgetState(ImageGadgetInformationheader, ImageID(images::Images("header")))
  
  ; right click menu
  MenuListInstalled = CreatePopupImageMenu(#PB_Any)
  MenuItem(#MenuItem_Information, l("main","information"))
  MenuBar()
  MenuItem(#MenuItem_Activate, l("main","activate"), ImageID(images::Images("yes")))
  MenuItem(#MenuItem_Deactivate, l("main","deactivate"), ImageID(images::Images("no")))
  MenuItem(#MenuItem_Uninstall, l("main","uninstall"))
  
  ; Drag & Drop
  EnableWindowDrop(WindowMain, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
  
  updateGUI()
EndProcedure

Procedure ResizeUpdate()
  ResizeGadgetsWindowMain()
  ResizeImage(images::Images("headermain"), GadgetWidth(ImageGadgetHeader), GadgetHeight(ImageGadgetHeader), #PB_Image_Raw)
  SetGadgetState(ImageGadgetHeader, ImageID(images::Images("headermain")))
EndProcedure


; TIMER

Procedure updateGUI()
  Protected SelectedMod, i, selectedActive, selectedInactive, countActive, countInactive
  Protected *modinfo.mod
  Protected text$, author$
  Static LastSelect
  
  selectedActive = 0
  selectedInactive = 0
  For i = 0 To CountGadgetItems(ListInstalled) - 1
    *modinfo = ListIcon::GetListItemData(ListInstalled, i)
    If Not *modinfo
      Continue
    EndIf
    If *modinfo\active
      countActive + 1
    Else
      countInactive + 1
    EndIf
    If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected
      SelectedMod = i
      If *modinfo\active
        selectedActive + 1
      Else
        selectedInactive + 1
      EndIf
    EndIf
  Next
  
  If InstallInProgress
    DisableGadget(GadgetActivate, #True)
    DisableGadget(GadgetDeactivate, #True)
    DisableGadget(GadgetUninstall, #True)
    DisableGadget(GadgetButtonInformation, #True)
    DisableMenuItem(MenuListInstalled, #MenuItem_Activate, #True)
    DisableMenuItem(MenuListInstalled, #MenuItem_Deactivate, #True)
    DisableMenuItem(MenuListInstalled, #MenuItem_Uninstall, #True)
  Else
    ; no install in progress
    SelectedMod =  GetGadgetState(ListInstalled)
    If SelectedMod = -1 ; if nothing is selected -> disable buttons
      DisableGadget(GadgetActivate, #True)
      DisableGadget(GadgetDeactivate, #True)
      DisableGadget(GadgetUninstall, #True)
      DisableGadget(GadgetButtonInformation, #True)
      DisableMenuItem(MenuListInstalled, #MenuItem_Activate, #True)
      DisableMenuItem(MenuListInstalled, #MenuItem_Deactivate, #True)
      DisableMenuItem(MenuListInstalled, #MenuItem_Uninstall, #True)
      DisableMenuItem(MenuListInstalled, #MenuItem_Information, #True)
    Else
      DisableGadget(GadgetUninstall, #False) ; uninstall is always possible!
      DisableMenuItem(MenuListInstalled, #MenuItem_Uninstall, #False)
      If selectedActive > 0 ; if at least one of the mods is active
        DisableGadget(GadgetDeactivate, #False)
        DisableMenuItem(MenuListInstalled, #MenuItem_Deactivate, #False)
      Else  ; if no mod is active 
        DisableGadget(GadgetDeactivate, #True)
        DisableMenuItem(MenuListInstalled, #MenuItem_Deactivate, #True)
      EndIf
      If selectedInactive > 0 ; if at least one of the mods is not active
        DisableGadget(GadgetActivate, #False)
        DisableMenuItem(MenuListInstalled, #MenuItem_Activate, #False)
      Else ; if none of the selected mods is inactive
        DisableGadget(GadgetActivate, #True)  ; disable activate button
        DisableMenuItem(MenuListInstalled, #MenuItem_Activate, #True)
      EndIf
      
      If selectedActive + selectedInactive > 1
        DisableGadget(GadgetButtonInformation, #True)
        DisableMenuItem(MenuListInstalled, #MenuItem_Information, #True)
      Else
        DisableGadget(GadgetButtonInformation, #False)
        DisableMenuItem(MenuListInstalled, #MenuItem_Information, #False)
      EndIf
      
      If selectedActive + selectedInactive > 1
        SetGadgetText(GadgetUninstall, l("main","uninstall_pl"))
        SetMenuItemText(MenuListInstalled, #MenuItem_Uninstall, l("main","uninstall_pl"))
      Else
        SetGadgetText(GadgetUninstall, l("main","uninstall"))
        SetMenuItemText(MenuListInstalled, #MenuItem_Uninstall, l("main","uninstall"))
      EndIf
      If selectedActive > 1
        SetGadgetText(GadgetDeactivate, l("main","deactivate_pl"))
        SetMenuItemText(MenuListInstalled, #MenuItem_Deactivate, l("main","deactivate_pl"))
      Else
        SetGadgetText(GadgetDeactivate, l("main","deactivate"))
        SetMenuItemText(MenuListInstalled, #MenuItem_Deactivate, l("main","deactivate"))
      EndIf
      If selectedInactive > 1
        SetGadgetText(GadgetActivate, l("main","activate_pl"))
        SetMenuItemText(MenuListInstalled, #MenuItem_Activate, l("main","activate_pl"))
      Else
        SetGadgetText(GadgetActivate, l("main","activate"))
        SetMenuItemText(MenuListInstalled, #MenuItem_Activate, l("main","activate"))
      EndIf
    EndIf
    
    
    If selectedActive + selectedInactive = 1
      ; one mod selected
      ; display image
      *modinfo = ListIcon::GetListItemData(ListInstalled, SelectedMod)
      If Not IsImage(PreviewImages(*modinfo\id$)) ; if image is not yet loaded
        Protected im.i
        ; search for image
        If FileSize(misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$) + "preview.png") > 0
          im = LoadImage(#PB_Any, misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$) + "preview.png")
        ElseIf FileSize(misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$) + "header.jpg") > 0
          im = LoadImage(#PB_Any, misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$) + "header.jpg")
;           If im
;             If SaveImage(im, misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$) + "preview.png", #PB_ImagePlugin_PNG)
;               DeleteFile(misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$) + "header.jpg")
;             EndIf
;           EndIf
        EndIf
        ; if load was successfull
        If IsImage(im)
          Protected max_w.i, max_h.i, factor_w.d, factor_h.d, factor.d, im_w.i, im_h.i
          im_w = ImageWidth(im)
          im_h = ImageHeight(im)
          max_w = GadgetWidth(ImageGadgetLogo)
          max_h = GadgetHeight(ImageGadgetLogo)
          factor_w = max_w / im_w
          factor_h = max_h / im_h
          factor = Min(factor_w, factor_h)
          im_w * factor
          im_h * factor
          
          debugger::Add("Image: ("+Str(im_w)+", "+Str(im_h)+")")
          ResizeImage(im, im_w, im_h)
          
          PreviewImages(*modinfo\id$) = CreateImage(#PB_Any, max_w, max_h, 32, #PB_Image_Transparent)
          If StartDrawing(ImageOutput(PreviewImages(*modinfo\id$)))
            DrawingMode(#PB_2DDrawing_AlphaBlend)
            DrawAlphaImage(ImageID(im), (max_w - im_w)/2, (max_h - im_h)/2) ; center the image onto a new image
            StopDrawing()
          Else
            debugger::Add("Drawing Error")
            DeleteMapElement(PreviewImages())
          EndIf
        EndIf
      EndIf
      ; if image is leaded now
      If IsImage(PreviewImages(*modinfo\id$))
        ; display image
        If GetGadgetState(ImageGadgetLogo) <> ImageID(PreviewImages(*modinfo\id$))
          debugger::Add("ImageLogo: Display custom image")
          SetGadgetState(ImageGadgetLogo, ImageID(PreviewImages(*modinfo\id$)))
        EndIf
      Else
        ; else: display normal logo
        If GetGadgetState(ImageGadgetLogo) <> ImageID(images::Images("logo"))
          debugger::Add("ImageLogo: Display tf|net logo instead of custom image")
          SetGadgetState(ImageGadgetLogo, ImageID(images::Images("logo")))
        EndIf
      EndIf
    Else
      If GetGadgetState(ImageGadgetLogo) <> ImageID(images::Images("logo"))
        debugger::Add("ImageLogo: Display tf|net logo")
        SetGadgetState(ImageGadgetLogo, ImageID(images::Images("logo")))
      EndIf
    EndIf
  EndIf
;   EndIf
EndProcedure

Procedure updateQueue()
  Protected *modinfo.mod, element.queue
  Protected text$, author$
    
  
  If Not InstallInProgress And TF$
    If Not MutexQueue
      debugger::Add("MutexQueue = CreateMutex()")
      MutexQueue = CreateMutex()
    EndIf
    LockMutex(MutexQueue)
    If ListSize(queue()) > 0
      debugger::Add("QUEUE: Handle next element")
      FirstElement(queue())
      element = queue()
      DeleteElement(queue(),1)
      
      
      Select element\action
        Case #QueueActionActivate
          debugger::Add("#QueueActionActivate")
          If element\modinfo
            ShowProgressWindow(element\modinfo)
            CreateThread(@ActivateThread(), element\modinfo)
          EndIf
          
        Case #QueueActionDeactivate
          debugger::Add("#QueueActionDeactivate")
          If element\modinfo
            ShowProgressWindow(element\modinfo)
            CreateThread(@DeactivateThread(), element\modinfo)
          EndIf
          
        Case #QueueActionUninstall
          debugger::Add("#QueueActionUninstall")
          If element\modinfo
            RemoveModFromList(element\modinfo)
          EndIf
          
        Case #QueueActionNew
          debugger::Add("#QueueActionNew")
          If element\File$
            AddModToList(element\File$)
          EndIf
      EndSelect
      
    EndIf
    UnlockMutex(MutexQueue)
  EndIf
EndProcedure

Procedure TimerMain()
  Static LastDir$ = ""
  
  If LastDir$ <> TF$
    LastDir$ = TF$
    If checkTFPath(TF$) <> #True
      Ready = #False  ; flag for mod management
      MenuItemSettings(0)
    EndIf
  EndIf
  
  updateGUI()
  updateQueue()
  
EndProcedure

Procedure TimerSettingsGadgets()
  ; check gadgets etc
  Protected ret
  Static LastDir$
  
  If LastDir$ <> GetGadgetText(GadgetPath)
    LastDir$ = GetGadgetText(GadgetPath)
    
    If FileSize(LastDir$) = -2
      DisableGadget(GadgetOpenPath, #False)
    Else
      DisableGadget(GadgetOpenPath, #True)
    EndIf
    
    ret = checkTFPath(LastDir$)
    If ret = #True
      SetGadgetText(GadgetRights, l("settings","success"))
      SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(0,100,0))
      DisableGadget(GadgetSaveSettings, #False)
    Else
      SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(255,0,0))
      DisableGadget(GadgetSaveSettings, #True)
      If ret = -1
        SetGadgetText(GadgetRights, l("settings","failed"))
      Else
        SetGadgetText(GadgetRights, l("settings","not_found"))
      EndIf
    EndIf
  EndIf
EndProcedure

Procedure TimerUpdate()
  ; Linux Workaround: Can only open MessageRequester from Main Loop (not from update thread)
  RemoveWindowTimer(WindowMain, TimerUpdate)
  Select UpdateResult
    Case #UpdateNew
      If MessageRequester(l("update","title"), l("update","update"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
        misc::openLink("http://goo.gl/utB3xn") ; Download Page TFMM (Train-Fever.net)
      EndIf
    Case #UpdateCurrent
      MessageRequester(l("update","title"), l("update","current"))
    Case #UpdateFailed
      MessageRequester(l("update","title"), l("update","failed"))
  EndSelect
EndProcedure

Procedure checkUpdate(auto.i)
  debugger::Add("checkUpdate")
  Protected URL$
  
  DeleteFile("tfmm-update.ini")
  URL$ = URLEncoder("http://update.alexandernaehring.eu/tfmm/?build="+Str(#PB_Editor_CompileCount)+"&auto="+Str(auto))
  debugger::Add(URL$)
  If ReceiveHTTPFile(URL$, "tfmm-update.ini")
    OpenPreferences("tfmm-update.ini")
    If ReadPreferenceInteger("version", #PB_Editor_CompileCount) > #PB_Editor_CompileCount
      debugger::Add("Update: new version available")
      UpdateResult = #UpdateNew
      AddWindowTimer(WindowMain, TimerUpdate, 100)
    Else
      debugger::Add("Update: no new version")
      If Not auto
        UpdateResult = #UpdateCurrent
        AddWindowTimer(WindowMain, TimerUpdate, 100)
      EndIf
    EndIf
    ClosePreferences()
    DeleteFile("tfmm-update.ini")
  Else
    debugger::Add("ERROR: failed to download ini")
    If Not auto
      UpdateResult = #UpdateFailed
      AddWindowTimer(WindowMain, TimerUpdate, 100)
    EndIf
  EndIf
EndProcedure

; MENU

Procedure MenuItemHomepage(event)
  misc::openLink("http://goo.gl/utB3xn") ; Download Page TFMM (Train-Fever.net)
EndProcedure

Procedure MenuItemUpdate(event)
  CreateThread(@checkUpdate(), 0)
EndProcedure

Procedure MenuItemLicense(event)
  MessageRequester("License",
                   "Train Fever Mod Manager (" + #VERSION$ + ")" + #CRLF$ +
                   
                   "© 2014 Alexander Nähring / Xanos" + #CRLF$ +
                   "Distribution: www.train-fever.net" + #CRLF$ +
                   #CRLF$ +
                   "unrar © Alexander L. Roshal")
EndProcedure

Procedure MenuItemSettings(event) ; open settings window
  Protected locale$
  OpenPreferences("TFMM.ini")
  SetGadgetText(GadgetPath, ReadPreferenceString("path", TF$))
  SetGadgetState(GadgetSettingsWindowLocation, ReadPreferenceInteger("windowlocation", 0))
  SetGadgetState(GadgetSettingsAutomaticUpdate, ReadPreferenceInteger("update", 1))
  locale$ = ReadPreferenceString("locale", "en")
  ClosePreferences()
  
  Protected NewMap locale$(), count.i = 0
  locale::listAvailable(locale$())
  ClearGadgetItems(GadgetSettingsLocale)
  ForEach locale$()
    AddGadgetItem(GadgetSettingsLocale, -1, "<" + MapKey(locale$()) + ">" + " " + locale$())
    If locale$ = MapKey(locale$())
      SetGadgetState(GadgetSettingsLocale, count)
    EndIf
    count + 1
  Next
  
  AddWindowTimer(WindowSettings, TimerSettingsGadgets, 100)
  HideWindow(WindowSettings, #False, #PB_Window_WindowCentered)
  DisableWindow(WindowMain, #True)
  SetActiveWindow(WindowSettings)
EndProcedure

Procedure MenuItemExportAll(event)
  ExportModList(#True)
EndProcedure

Procedure MenuItemExportActivated(event)
  ExportModList()
EndProcedure

; GADGETS

Procedure GadgetCloseSettings(event) ; close settings window and apply settings
  RemoveWindowTimer(WindowSettings, TimerSettingsGadgets)
  HideWindow(WindowSettings, #True)
  DisableWindow(WindowMain, #False)
  SetActiveWindow(WindowMain)
  
  If checkTFPath(TF$) <> #True
    ready = #False
    exit(0)
  EndIf
  
EndProcedure

Procedure GadgetSaveSettings(event)
  Protected Dir$, locale$, restart.i = #False
  Dir$ = GetGadgetText(GadgetPath)
  Dir$ = misc::Path(Dir$)
  
  TF$ = Dir$ ; store in global variable
  
  locale$ = GetGadgetText(GadgetSettingsLocale)
  locale$ = StringField(StringField(locale$, 1, ">"), 2, "<") ; extract string between < and >
  If locale$ = ""
    locale$ = "en"
  EndIf
  
  
  OpenPreferences("TFMM.ini")
  WritePreferenceString("path", TF$)
  WritePreferenceInteger("windowlocation", GetGadgetState(GadgetSettingsWindowLocation))
  If Not GetGadgetState(GadgetSettingsWindowLocation)
    RemovePreferenceGroup("window")
  EndIf
  WritePreferenceInteger("update", GetGadgetState(GadgetSettingsAutomaticUpdate))
  If locale$ <> ReadPreferenceString("locale", "en")
    restart = #True
  EndIf
  WritePreferenceString("locale", locale$)
  ClosePreferences()
  
  If restart
    MessageRequester("Restart TFMM", "TFMM will now restart to display the selected locale")
    RunProgram(ProgramFilename())
    End
  EndIf
  
  FreeModList()
  LoadModList()
  GadgetCloseSettings(event)
EndProcedure

Procedure GadgetButtonActivate(event)
  debugger::Add("GadgetButtonActivate")
  Protected *modinfo.mod, *last.mod
  Protected i, count, result
  Protected NewMap strings$()
  
  For i = 0 To CountGadgetItems(ListInstalled) - 1
    If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected 
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      If Not *modinfo\active
        *last = *modinfo
        count + 1
      EndIf
    EndIf
  Next i
  If count > 0
    If count = 1
      ClearMap(strings$())
      strings$("name") = *last\name$
      result = MessageRequester(l("main","activate"), locale::getEx("management", "activate1", strings$()), #PB_MessageRequester_YesNo)
    Else
      ClearMap(strings$())
      strings$("count") = Str(count)
      result = MessageRequester(l("main","activate_pl"), locale::getEx("management", "activate2", strings$()), #PB_MessageRequester_YesNo)
    EndIf
    
    If result = #PB_MessageRequester_Yes
      For i = 0 To CountGadgetItems(ListInstalled) - 1
        If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected
          *modinfo = ListIcon::GetListItemData(ListInstalled, i)
          If Not *modinfo\active
            AddToQueue(#QueueActionActivate, *modinfo)
          EndIf
        EndIf
      Next i
    EndIf
  EndIf
EndProcedure

Procedure GadgetButtonDeactivate(event)
  Protected *modinfo.mod, *last.mod
  Protected i, count, result
  Protected NewMap strings$()
  
  For i = 0 To CountGadgetItems(ListInstalled) - 1
    If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected 
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      With *modinfo
        If \active
          *last = *modinfo
          count + 1
        EndIf
      EndWith
    EndIf
  Next i
  If count > 0
    If count = 1
      ClearMap(strings$())
      strings$("name") = *last\name$
      result = MessageRequester(l("main","deactivate"), locale::getEx("management", "deactivate1", strings$()), #PB_MessageRequester_YesNo)
    Else
      ClearMap(strings$())
      strings$("count") = Str(count)
      result = MessageRequester(l("main","deactivate_pl"), locale::getEx("management", "deactivate2", strings$()), #PB_MessageRequester_YesNo)
    EndIf
    
    If result = #PB_MessageRequester_Yes
      For i = 0 To CountGadgetItems(ListInstalled) - 1
        If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected 
          *modinfo = ListIcon::GetListItemData(ListInstalled, i)
          With *modinfo
            If \active
              AddToQueue(#QueueActionDeactivate, *modinfo)
            EndIf
          EndWith
        EndIf
      Next i
    EndIf
  EndIf
EndProcedure

Procedure GadgetButtonUninstall(event)
  debugger::Add("GadgetButtonUninstall")
  Protected *modinfo.mod, *last.mod
  Protected i, count, result
  Protected NewMap strings$()
  
  For i = 0 To CountGadgetItems(ListInstalled) - 1
    If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected 
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      *last = *modinfo
      count + 1
    EndIf
  Next i
  If count > 0
    If count = 1
      ClearMap(strings$())
      strings$("name") = *last\name$
      result = MessageRequester(l("main","uninstall"), locale::getEx("management", "uninstall1", strings$()), #PB_MessageRequester_YesNo)
    Else
      ClearMap(strings$())
      strings$("count") = Str(count)
      result = MessageRequester(l("main","uninstall_pl"), locale::getEx("management", "uninstall2", strings$()), #PB_MessageRequester_YesNo)
    EndIf
    
    If result = #PB_MessageRequester_Yes
      For i = 0 To CountGadgetItems(ListInstalled) - 1
        If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected
          *modinfo = ListIcon::GetListItemData(ListInstalled, i)
          If *modinfo\active
            AddToQueue(#QueueActionDeactivate, *modinfo)
          EndIf
          AddToQueue(#QueueActionUninstall, *modinfo)
        EndIf
      Next i
    EndIf
  EndIf
EndProcedure

Procedure GadgetNewMod(event)
  Protected File$
  File$ = OpenFileRequester(l("management","select_mod"), "", l("management","files_archive")+"|*.zip;*.rar|"+l("management","files_all")+"|*.*", 0)
  
  If FileSize(TF$) <> -2
    ProcedureReturn #False
  EndIf
  
  If File$
    AddToQueue(#QueueActionNew, 0, File$)
  EndIf
EndProcedure

Procedure GadgetModYes(event)
  ModProgressAnswer = #AnswerYes
EndProcedure

Procedure GadgetModNo(event)
  ModProgressAnswer = #AnswerNo
EndProcedure

Procedure GadgetModYesAll(event)
  ModProgressAnswer = #AnswerYesAll
EndProcedure

Procedure GadgetModNoAll(event)
  ModProgressAnswer = #AnswerNoAll
EndProcedure

Procedure GadgetModOk(event)
  ModProgressAnswer = #AnswerOk
EndProcedure

Procedure GadgetListInstalled(event)
  Protected *modinfo.mod
  Protected position
  updateGUI()
  If event = #PB_EventType_LeftDoubleClick
    GadgetButtonInformation(#PB_EventType_LeftClick)
  ElseIf event = #PB_EventType_RightClick
    DisplayPopupMenu(MenuListInstalled, WindowID(WindowMain))
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
    If GetGadgetState(ImageGadgetLogo) = ImageID(images::Images("logo"))
      GadgetButtonTrainFeverNet(event)
    EndIf
  EndIf
EndProcedure

Procedure GadgetButtonBrowse(event)
  Protected Dir$
  Dir$ = GetGadgetText(GadgetPath)
  Dir$ = PathRequester("Train Fever installation path", Dir$)
  If Dir$
    SetGadgetText(GadgetPath, Dir$)
  EndIf
EndProcedure

Procedure GadgetButtonAutodetect(event)
  Protected Dir$
  
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows 
      Dir$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
      If Not FileSize(Dir$) = -2 ; -2 = directory
        Dir$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
      EndIf
    CompilerCase #PB_OS_Linux
      Dir$ = misc::Path(GetHomeDirectory() + "/.local/share/Steam/SteamApps/common/Train Fever/")
    CompilerCase #PB_OS_MacOS
      Dir$ = misc::Path(GetHomeDirectory() + "/Library/Application Support/Steam/SteamApps/common/Train Fever/")
  CompilerEndSelect
  
  If Dir$
    SetGadgetText(GadgetPath, Dir$)  
  EndIf
  
EndProcedure

Procedure GadgetButtonOpenPath(event)
  misc::openLink(GetGadgetText(GadgetPath))
EndProcedure

Procedure HandleDroppedFiles(Files$)
  Protected count, i
  Protected File$
  
  debugger::Add("dropped files:")
  count  = CountString(Files$, Chr(10)) + 1
  For i = 1 To count
    File$ = StringField(Files$, i, Chr(10))
    AddToQueue(#QueueActionNew, 0, File$)
  Next i
EndProcedure

Procedure ModInformationShowChangeGadgets(show = #True) ; #true = show change gadgets, #false = show display gadgets
  debugger::Add("Show Change Gadgets = "+Str(show))
  HideGadget(ModInformationButtonSave, 1 - show)
  HideGadget(ModInformationChangeName, 1 - show)
  HideGadget(ModInformationChangeVersion, 1 - show)
  HideGadget(ModInformationChangeCategory, 1 - show)
  HideGadget(ModInformationChangeDownload, 1 - show)
  
  HideGadget(ModInformationButtonChange, show)
  HideGadget(ModInformationDisplayName, show)
  HideGadget(ModInformationDisplayVersion, show)
  HideGadget(ModInformationDisplayCategory, show)
  HideGadget(ModInformationDisplayDownload, show)
EndProcedure

Procedure GadgetButtonInformation(event)
  Protected *modinfo.mod
  Protected SelectedMod, i, Gadget
  Protected tfnet_mod_url$
  
  ; init
  SelectedMod = GetGadgetState(ListInstalled)
  If SelectedMod = -1
    ProcedureReturn #False
  EndIf
  *modinfo = ListIcon::GetListItemData(ListInstalled, SelectedMod)
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  
  OpenWindowModInformation()
  BindEvent(#PB_Event_SizeWindow, @ResizeGadgetsWindowModInformation(), WindowModInformation)
  SetGadgetState(ImageGadgetInformationheader, ImageID(images::Images("headerinfo")))
  
  ; fill in values for mod
  With *modinfo
    If \tfnet_mod_id
      tfnet_mod_url$ = "train-fever.net/filebase/index.php/Entry/"+Str(\tfnet_mod_id)
    EndIf
    
    SetWindowTitle(WindowModInformation, \name$)
    
    SetGadgetText(ModInformationChangeName, \name$)
    SetGadgetText(ModInformationChangeVersion, \version$)
    SetGadgetText(ModInformationChangeCategory, \categoryDisplay$)
    SetGadgetText(ModInformationChangeDownload, tfnet_mod_url$)
    
    SetGadgetText(ModInformationDisplayName, \name$)
    SetGadgetText(ModInformationDisplayVersion, \version$)
    SetGadgetText(ModInformationDisplayCategory, \categoryDisplay$)
    SetGadgetText(ModInformationDisplayDownload, tfnet_mod_url$)
    
    i = 0
    ResetList(\author())
    ForEach \author()
      i + 1
      UseGadgetList(WindowID(WindowModInformation))
      If \author()\tfnet_id
        Gadget = HyperLinkGadget(#PB_Any, 90, 50 + i*30, 260, 20, \author()\name$, 0, #PB_HyperLink_Underline)
        SetGadgetData(Gadget, \author()\tfnet_id)
        SetGadgetColor(Gadget, #PB_Gadget_FrontColor, RGB(131,21,85))
        AddElement(InformationGadgetAuthor())
        InformationGadgetAuthor() = Gadget
      Else
        TextGadget(#PB_Any, 90, 50 + i*30, 260, 20, \author()\name$)
      EndIf
      If i > 1
        ResizeWindow(WindowModInformation, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowHeight(WindowModInformation) + 30)
      EndIf
    Next
    
    StatusBarText(0, 0, \file$ + " " + "(" + misc::Bytes(\size) + ")")
    
  EndWith
  
  
  ; show correct gadgets
  ModInformationShowChangeGadgets(#False)
    
  DisableWindow(WindowMain, #True)
  HideWindow(WindowModInformation, #False, #PB_Window_WindowCentered)
EndProcedure

Procedure GadgetButtonInformationClose(event)
  ClearList(InformationGadgetAuthor())
  HideWindow(WindowModInformation, #True)
  DisableWindow(WindowMain, #False)
  CloseWindow(WindowModInformation)
EndProcedure

Procedure GadgetButtonInformationChange(event)
  ModInformationShowChangeGadgets()
EndProcedure

Procedure GadgetButtonInformationSave(event)
  ModInformationShowChangeGadgets(#False)
EndProcedure

Procedure GadgetInformationLinkTFNET(event)
  Protected link$
  link$ = GetGadgetText(ModInformationDisplayDownload)
  
  If link$ = ""
    ProcedureReturn #False
  EndIf
  
  If Left(LCase(link$), 6) <> "http://" And Left(LCase(link$), 7) <> "https://"
    link$ = URLEncoder("http://"+link$)
  EndIf
  
  misc::openLink(link$)
EndProcedure




; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 200
; FirstLine = 134
; Folding = OAAAAAg
; EnableUnicode
; EnableXP