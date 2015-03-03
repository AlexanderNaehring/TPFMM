EnableExplicit

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_mods.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_queue.pbi"
XIncludeFile "WindowMain.pbf"
XIncludeFile "WindowSettings.pbf"
XIncludeFile "WindowModProgress.pbf"
XIncludeFile "WindowModInformation.pbf"

;{ -------------------------------------------------------------------------------- TEMPORARY

Global UpdateResult


Enumeration
  #AnswerNone
  #AnswerYes
  #AnswerNo
  #AnswerYesAll
  #AnswerNoAll
  #AnswerOk
EndEnumeration


Global GadgetModNo, GadgetModNoAll, GadgetModOK, GadgetModProgress, GadgetModText, GadgetModYes, GadgetModYesAll
Global WindowMain, WindowModProgress
Global TimerFinishUnInstall, TimerUpdate
Global Library

Global ModProgressAnswer = #AnswerNone


Procedure checkTFPath(Dir$)
  If Dir$
    If FileSize(Dir$) = -2
      Dir$ = misc::Path(Dir$)
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        If FileSize(Dir$ + "TrainFever.exe") > 1
          ; TrainFever.exe is located in this path!
          ; seems to be valid
          
          ; check if able to write to path
          If CreateFile(0, Dir$ + "TFMM.tmp")
            CloseFile(0)
            DeleteFile(Dir$ + "TFMM.tmp")
            ProcedureReturn #True
          EndIf
          ProcedureReturn -1
        EndIf
      CompilerElse
        If FileSize(Dir$ + "TrainFever") > 1
          If CreateFile(0, Dir$ + "TFMM.tmp")
            CloseFile(0)
            DeleteFile(Dir$ + "TFMM.tmp")
            ProcedureReturn #True
          EndIf
          ProcedureReturn -1
        EndIf
      CompilerEndIf
    EndIf
  EndIf
  ProcedureReturn #False
EndProcedure


Procedure ShowProgressWindow(*mod.mods::mod)
  
EndProcedure

Procedure ActivateThread(*dummy)
  
EndProcedure

Procedure DeactivateThread(*dummy)
  
EndProcedure

Procedure RemoveModFromList(*mod.mods::mod)
  
EndProcedure

Procedure ExportModList(dummy=0)
  
EndProcedure

Procedure FreeModList()
  
EndProcedure

Procedure FinishDeActivate()
  
EndProcedure




;} --------------------------------------------------------------------------------

Global TimerSettingsGadgets = 100, TimerMainGadgets = 101, TimerFinishUnInstall = 102, TimerUpdate = 103

Global NewMap PreviewImages.i()


Structure authorGadget
  display.i
  changeName.i
  changeID.i
EndStructure
Global NewList InformationGadgetAuthor.authorGadget() ; list of Gadget IDs for Author links

Global MenuLibrary
Enumeration 100
  #MenuItem_Install
  #MenuItem_Remove
  #MenuItem_Delete
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
    DefineListCallback(Library, #Edit)
    UnuseModule ListIcon
  CompilerEndIf
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      SetWindowTitle(WindowMain, GetWindowTitle(WindowMain) + " for Windows")
    CompilerCase #PB_OS_Linux
      SetWindowTitle(WindowMain, GetWindowTitle(WindowMain) + " for Linux")
    CompilerCase #PB_OS_MacOS
      SetWindowTitle(WindowMain, GetWindowTitle(WindowMain) + " for MacOS")
  CompilerEndSelect
  
  ; load images
  ResizeImage(images::Images("headermain"), GadgetWidth(ImageGadgetHeader), GadgetHeight(ImageGadgetHeader), #PB_Image_Raw)
  SetGadgetState(ImageGadgetHeader, ImageID(images::Images("headermain")))
  SetGadgetState(ImageGadgetLogo, ImageID(images::Images("logo")))
;   SetGadgetState(ImageGadgetInformationheader, ImageID(images::Images("header")))
  
  ; right click menu
  MenuLibrary = CreatePopupImageMenu(#PB_Any)
  MenuItem(#MenuItem_Information, l("main","information"))
  MenuBar()
  MenuItem(#MenuItem_Install, l("main","install"), ImageID(images::Images("yes")))
  MenuItem(#MenuItem_Remove, l("main","remove"), ImageID(images::Images("no")))
  MenuItem(#MenuItem_Delete, l("main","delete"))
  
  ; Drag & Drop
  EnableWindowDrop(WindowMain, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
  
  ; library
  mods::registerLibraryGadget(Library)
  
  ; init gui
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
  Protected *mod.mods::mod
  Protected text$, author$
  Static LastSelect
  
  selectedActive = 0
  selectedInactive = 0
  
  For i = 0 To CountGadgetItems(Library) - 1
    *mod = ListIcon::GetListItemData(Library, i)
    If Not *mod
      Continue
    EndIf
    If *mod\aux\installed
      countActive + 1
    Else
      countInactive + 1
    EndIf
    If GetGadgetItemState(Library, i) & #PB_ListIcon_Selected
      SelectedMod = i
      If *mod\aux\installed
        selectedActive + 1
      Else
        selectedInactive + 1
      EndIf
    EndIf
  Next
  
  SelectedMod =  GetGadgetState(Library)
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
      SetGadgetText(GadgetDelete, l("main","delete_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_delete, l("main","delete_pl"))
    Else
      SetGadgetText(Gadgetdelete, l("main","delete"))
      SetMenuItemText(MenuLibrary, #MenuItem_delete, l("main","delete"))
    EndIf
    If selectedActive > 1
      SetGadgetText(GadgetRemove, l("main","remove_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_Remove, l("main","remove_pl"))
    Else
      SetGadgetText(GadgetRemove, l("main","remove"))
      SetMenuItemText(MenuLibrary, #MenuItem_Remove, l("main","remove"))
    EndIf
    If selectedInactive > 1
      SetGadgetText(GadgetInstall, l("main","install_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_Install, l("main","install_pl"))
    Else
      SetGadgetText(GadgetInstall, l("main","install"))
      SetMenuItemText(MenuLibrary, #MenuItem_Install, l("main","install"))
    EndIf
  EndIf
  
  If selectedActive + selectedInactive = 1
    ; one mod selected
    ; display image
    *mod = ListIcon::GetListItemData(Library, SelectedMod)
    If Not IsImage(PreviewImages(*mod\id$)) ; if image is not yet loaded
      Protected im.i, image$
      image$ = misc::Path(TF$ + "TFMM/library/" + *mod\id$) + "image_00.tga"
      If FileSize(image$) > 0
        im = LoadImage(#PB_Any, image$)
      EndIf
      ; if load was successfull
      If IsImage(im)
        im = misc::ResizeCenterImage(im, GadgetWidth(ImageGadgetLogo), GadgetHeight(ImageGadgetLogo))
        If IsImage(im)
          PreviewImages(*mod\id$) = im
        EndIf
      EndIf
    EndIf
    ; if image is leaded now
    If IsImage(PreviewImages(*mod\id$))
      ; display image
      If GetGadgetState(ImageGadgetLogo) <> ImageID(PreviewImages(*mod\id$))
        debugger::Add("ImageLogo: Display custom image")
        SetGadgetState(ImageGadgetLogo, ImageID(PreviewImages(*mod\id$)))
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
  queue::update(TF$)
  
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
  Protected URL$, OS$
  
  DeleteFile("tfmm-update.ini")
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      OS$ = "win"
    CompilerCase #PB_OS_Linux
      OS$ = "lin"
    CompilerCase #PB_OS_MacOS
      OS$ = "mac"
  CompilerEndSelect
  URL$ = URLEncoder("http://update.alexandernaehring.eu/tfmm/?build="+Str(#PB_Editor_CompileCount)+"&os="+OS$+"&auto="+Str(auto))
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
  locale::listAvailable(GadgetSettingsLocale, locale$)
  
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
  
  locale$ = StringField(StringField(GetGadgetText(GadgetSettingsLocale), 1, ">"), 2, "<") ; extract string between < and >
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
  ;LoadModList()
  GadgetCloseSettings(event)
EndProcedure

Procedure GadgetButtonInstall(event)
  debugger::Add("GadgetButtonInstall")
  Protected *mod.mods::mod, *last.mods::mod
  Protected i, count, result
  Protected NewMap strings$()
  
  For i = 0 To CountGadgetItems(Library) - 1
    If GetGadgetItemState(Library, i) & #PB_ListIcon_Selected 
      *mod = ListIcon::GetListItemData(Library, i)
      If Not *mod\aux\installed
        *last = *mod
        count + 1
      EndIf
    EndIf
  Next i
  If count > 0
    If count = 1
      ClearMap(strings$())
      strings$("name") = *last\name$
      result = MessageRequester(l("main","install"), locale::getEx("management", "install1", strings$()), #PB_MessageRequester_YesNo)
    Else
      ClearMap(strings$())
      strings$("count") = Str(count)
      result = MessageRequester(l("main","install_pl"), locale::getEx("management", "isntall2", strings$()), #PB_MessageRequester_YesNo)
    EndIf
    
    If result = #PB_MessageRequester_Yes
      For i = 0 To CountGadgetItems(Library) - 1
        If GetGadgetItemState(Library, i) & #PB_ListIcon_Selected
          *mod = ListIcon::GetListItemData(Library, i)
          If Not *mod\aux\installed
            queue::add(queue::#QueueActionInstall, *mod\id$)
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
  
  For i = 0 To CountGadgetItems(Library) - 1
    If GetGadgetItemState(Library, i) & #PB_ListIcon_Selected 
      *mod = ListIcon::GetListItemData(Library, i)
      With *mod
        If \aux\installed
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
      result = MessageRequester(l("main","remove"), locale::getEx("management", "remove1", strings$()), #PB_MessageRequester_YesNo)
    Else
      ClearMap(strings$())
      strings$("count") = Str(count)
      result = MessageRequester(l("main","remove_pl"), locale::getEx("management", "remove2", strings$()), #PB_MessageRequester_YesNo)
    EndIf
    
    If result = #PB_MessageRequester_Yes
      For i = 0 To CountGadgetItems(Library) - 1
        If GetGadgetItemState(Library, i) & #PB_ListIcon_Selected 
          *mod = ListIcon::GetListItemData(Library, i)
          With *mod
            If \aux\installed
              queue::add(queue::#QueueActionRemove, *mod\id$)
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
  
  For i = 0 To CountGadgetItems(Library) - 1
    If GetGadgetItemState(Library, i) & #PB_ListIcon_Selected 
      *mod = ListIcon::GetListItemData(Library, i)
      *last = *mod
      count + 1
    EndIf
  Next i
  If count > 0
    If count = 1
      ClearMap(strings$())
      strings$("name") = *last\name$
      result = MessageRequester(l("main","delete"), locale::getEx("management", "delete1", strings$()), #PB_MessageRequester_YesNo)
    Else
      ClearMap(strings$())
      strings$("count") = Str(count)
      result = MessageRequester(l("main","delete_pl"), locale::getEx("management", "delete2", strings$()), #PB_MessageRequester_YesNo)
    EndIf
    
    If result = #PB_MessageRequester_Yes
      For i = 0 To CountGadgetItems(Library) - 1
        If GetGadgetItemState(Library, i) & #PB_ListIcon_Selected
          *mod = ListIcon::GetListItemData(Library, i)
          If *mod\aux\installed
            queue::add(queue::#QueueActionRemove, *mod\id$)
          EndIf
          queue::add(queue::#QueueActionDelete, *mod\id$)
        EndIf
      Next i
    EndIf
  EndIf
EndProcedure

Procedure GadgetNewMod(event)
  Protected file$
  If FileSize(TF$) <> -2
    ProcedureReturn #False
  EndIf
  file$ = OpenFileRequester(l("management","select_mod"), "", l("management","files_archive")+"|*.zip;*.rar|"+l("management","files_all")+"|*.*", 0, #PB_Requester_MultiSelection)
  While file$
    If FileSize(file$) > 0
      queue::add(queue::#QueueActionNew, file$)
    EndIf
    file$ = NextSelectedFileName()
  Wend
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

Procedure GadgetLibrary(event)
  Protected *mod.mods::mod
  Protected position
  updateGUI()
  If event = #PB_EventType_LeftDoubleClick
    GadgetButtonInformation(#PB_EventType_LeftClick)
  ElseIf event = #PB_EventType_RightClick
    DisplayPopupMenu(MenuLibrary, WindowID(WindowMain))
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
  Protected file$
  
  debugger::Add("dropped files:")
  count  = CountString(files$, Chr(10)) + 1
  For i = 1 To count
    file$ = StringField(files$, i, Chr(10))
    queue::add(queue::#QueueActionNew, file$)
  Next i
EndProcedure

; - Information Window

Procedure ModInformationShowChangeGadgets(show = #True) ; #true = show change gadgets, #false = show display gadgets
  debugger::Add("Show Change Gadgets = "+Str(show))
  show = Bool(show)
  
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
  
  ForEach InformationGadgetAuthor()
    HideGadget(InformationGadgetAuthor()\changeName, 1-show)
    HideGadget(InformationGadgetAuthor()\changeID, 1-show)
    HideGadget(InformationGadgetAuthor()\display, show)
  Next
EndProcedure

Procedure GadgetButtonInformation(event)
  Protected *mod.mods::mod
  Protected SelectedMod, i, Gadget
  Protected tfnet_mod_url$
  
  ; init
  SelectedMod = GetGadgetState(Library)
  If SelectedMod = -1
    ProcedureReturn #False
  EndIf
  *mod = ListIcon::GetListItemData(Library, SelectedMod)
  If Not *mod
    ProcedureReturn #False
  EndIf
  
  OpenWindowModInformation()
  BindEvent(#PB_Event_SizeWindow, @ResizeGadgetsWindowModInformation(), WindowModInformation)
  SetGadgetState(ImageGadgetInformationheader, ImageID(images::Images("headerinfo")))
  
  ; fill in values for mod
  With *mod
    If \tfnetId
      tfnet_mod_url$ = "train-fever.net/filebase/index.php/Entry/"+Str(\tfnetId)
    EndIf
    
    SetWindowTitle(WindowModInformation, \name$)
    
    SetGadgetText(ModInformationChangeName, \name$)
    SetGadgetText(ModInformationChangeVersion, \aux\version$)
;     SetGadgetText(ModInformationChangeCategory, \categoryDisplay$)
    SetGadgetText(ModInformationChangeDownload, \url$)
    
    SetGadgetText(ModInformationDisplayName, \name$)
    SetGadgetText(ModInformationDisplayVersion, \aux\version$)
;     SetGadgetText(ModInformationDisplayCategory, \categoryDisplay$)
    SetGadgetText(ModInformationDisplayDownload, tfnet_mod_url$)
    
    i = 0
    ResetList(\authors())
    ForEach \authors()
      i + 1
      UseGadgetList(WindowID(WindowModInformation))
      If \authors()\tfnetId
        AddElement(InformationGadgetAuthor())
        InformationGadgetAuthor()\changeName  = StringGadget(#PB_Any, 90, 50 + i*30, 200, 20, \authors()\name$)
        InformationGadgetAuthor()\changeID    = StringGadget(#PB_Any, 300, 50 + i*30, 50, 20, Str(\authors()\tfnetId), #PB_String_Numeric)
        InformationGadgetAuthor()\display     = HyperLinkGadget(#PB_Any, 90, 50 + i*30, 260, 20, \authors()\name$, 0, #PB_HyperLink_Underline)
        SetGadgetData(InformationGadgetAuthor()\display, \authors()\tfnetId)
        SetGadgetColor(InformationGadgetAuthor()\display, #PB_Gadget_FrontColor, RGB(131,21,85))
      Else
        TextGadget(#PB_Any, 90, 50 + i*30, 260, 20, \authors()\name$)
      EndIf
      If i > 1
        ResizeWindow(WindowModInformation, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowHeight(WindowModInformation) + 30)
      EndIf
    Next
    
    StatusBarText(0, 0, \aux\file$ + " " + "(" + misc::Bytes(0) + ")")
    
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
; CursorPosition = 583
; FirstLine = 118
; Folding = FgAAIAAA9
; EnableUnicode
; EnableXP