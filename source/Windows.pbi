EnableExplicit

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_mods.pbi"
XIncludeFile "WindowMain.pbf"
XIncludeFile "WindowSettings.pbf"
XIncludeFile "WindowModProgress.pbf"


Global TimerSettingsGadgets = 100, TimerMainGadgets = 101, TimerFinishUnInstall = 102, TimerUpdate = 103

; INIT

Procedure InitWindows()
  debugger::Add("init windows")
  
  ; Open Windows
  OpenWindowMain()
  OpenWindowSettings()
  OpenWindowModProgress()
  
  ; Set window boundaries, timers, events
  WindowBounds(WindowMain, 640, 360, #PB_Ignore, #PB_Ignore) 
  AddWindowTimer(WindowMain, TimerMainGadgets, 100)
  BindEvent(#PB_Event_SizeWindow, @ResizeGadgetsWindowMain(), WindowMain)
  
  ; Init OS specific tools (list icon gadget)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    UseModule ListIcon
    DefineListCallback(ListInstalled, #Edit)
    UnuseModule ListIcon
  CompilerEndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x64
      SetWindowTitle(WindowMain, GetWindowTitle(WindowMain) + " BETA for Linux64")
    CompilerElse
      SetWindowTitle(WindowMain, GetWindowTitle(WindowMain) + " BETA for Linux")
    CompilerEndIf
  CompilerEndIf
  
  ; load images
  SetGadgetState(ImageGadgetHeader, ImageID(images::Images("header")))
  SetGadgetState(ImageGadgetLogo, ImageID(images::Images("logo")))
  
  ; Drag & Drop
  EnableWindowDrop(WindowMain, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
EndProcedure

; TIMER

Procedure TimerMain()
  Static LastDir$ = ""
  Protected SelectedMod, i, selectedActive, selectedInactive, countActive, countInactive
  Protected *modinfo.mod, element.queue
  Protected text$
  
  If LastDir$ <> TF$
    LastDir$ = TF$
    If checkTFPath(TF$) <> #True
      Ready = #False  ; flag for mod management
      MenuItemSettings(0)
    EndIf
  EndIf
  
  selectedActive = 0
  selectedInactive = 0
  For i = 0 To CountGadgetItems(ListInstalled) - 1
    *modinfo = ListIcon::GetListItemData(ListInstalled, i)
    If *modinfo\active
      countActive + 1
    Else
      countInactive + 1
    EndIf
    If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected
      If *modinfo\active
        selectedActive + 1
      Else
        selectedInactive + 1
      EndIf
    EndIf
  Next
  
  Select (selectedActive + selectedInactive)
    Case 0 ; nothing selected
      Text$ = Str(countActive + countInactive) + " mods installed." + #CRLF$
      If (countActive + countInactive) = 0
        Text$ + "You can add mods to enrich your experience with Train Fever." + #CRLF$ +
                "Check out our website by clicking on the image above if you want to download new mods." + #CRLF$
      Else
        Text$ + Str(countActive) + " Mods active" + #CRLF$ +
                Str(countInactive) + " Mods not active" + #CRLF$ +
                "Select any mod to get more information" + #CRLF$
      EndIf
    Case 1 ; one mod selected
      *modinfo = ListIcon::GetListItemData(ListInstalled, GetGadgetState(ListInstalled))
      With *modinfo
        Text$ = \name$ + " v" + \version$ + " by " + \author$ + #CRLF$ +
                #CRLF$
        If \active
          Text$ + "mod is activated"
        Else
          Text$ + "mod is not activated"
        EndIf
      EndWith
    Default ; multiple mods selected
       Text$ = Str(selectedActive + selectedInactive) + " Mods selected" + #CRLF$ +
              #CRLF$ +
              Str(selectedActive) + " Mods active" + #CRLF$ +
              Str(selectedInactive) + " Mods not active"
  EndSelect
  If Text$ <> GetGadgetText(GadgetTextMain)
    SetGadgetText(GadgetTextMain, Text$)
  EndIf
  
  If InstallInProgress
    DisableGadget(GadgetActivate, #True)
    DisableGadget(GadgetDeactivate, #True)
    DisableGadget(GadgetUninstall, #True)
  Else
    SelectedMod =  GetGadgetState(ListInstalled)
    If SelectedMod = -1 ; if nothing is selected -> disable buttons
      DisableGadget(GadgetActivate, #True)
      DisableGadget(GadgetDeactivate, #True)
      DisableGadget(GadgetUninstall, #True)
    Else
      DisableGadget(GadgetUninstall, #False) ; uninstall is always possible!
      If selectedActive > 0 ; if at least one of the mods is active
        DisableGadget(GadgetDeactivate, #False)
      Else  ; if no mod is active 
        DisableGadget(GadgetDeactivate, #True)
      EndIf
      If selectedInactive > 0 ; if at least one of the mods is not active
        DisableGadget(GadgetActivate, #False)
      Else ; if none of the selected mods is inactive
        DisableGadget(GadgetActivate, #True)  ; disable activate button
      EndIf
      
      If selectedActive + selectedInactive > 1
        SetGadgetText(GadgetUninstall, "Uninstall Mods")
      Else
        SetGadgetText(GadgetUninstall, "Uninstall Mod")
      EndIf
      If selectedActive > 1
        SetGadgetText(GadgetDeactivate, "Deactivate Mods")
      Else
        SetGadgetText(GadgetDeactivate, "Deactivate Mod")
      EndIf
      If selectedInactive > 1
        SetGadgetText(GadgetActivate, "Activate Mods")
      Else
        SetGadgetText(GadgetActivate, "Activate Mod")
      EndIf
    EndIf
  EndIf
  
  ; queue handler
  If Not InstallInProgress And TF$
    If Not MutexQueue
      debugger::Add("MutexQueue = CreateMutex()")
      MutexQueue = CreateMutex()
    EndIf
    LockMutex(MutexQueue)
    If ListSize(queue()) > 0
      debugger::Add("Handle next element in queue")
      FirstElement(queue())
      element = queue()
      DeleteElement(queue(),1)
      
      Select element\action
        Case #QueueActionActivate
          debugger::Add("#QueueActionActivate")
          If element\modinfo
            ShowProgressWindow()
            CreateThread(@ActivateThread(), element\modinfo)
          EndIf
          
        Case #QueueActionDeactivate
          debugger::Add("#QueueActionDeactivate")
          If element\modinfo
            ShowProgressWindow()
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
      SetGadgetText(GadgetRights, "Path is correct and TFMM is able to write to the game directory. Let's mod!")
      SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(0,100,0))
      DisableGadget(GadgetSaveSettings, #False)
    Else
      SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(255,0,0))
      DisableGadget(GadgetSaveSettings, #True)
      If ret = -1
        SetGadgetText(GadgetRights, "TFMM is not able to write to the game directory. Administrative privileges may be required.")
      Else
        SetGadgetText(GadgetRights, "Train Fever cannot be found at this path. Administrative privileges may be required.")
      EndIf
    EndIf
  EndIf
EndProcedure

Procedure TimerUpdate()
  ; Linux Workaround: Can only open MessageRequester from Main Loop (not from update thread)
  RemoveWindowTimer(WindowMain, TimerUpdate)
  Select UpdateResult
    Case #UpdateNew
      MessageRequester("Update", "A new version of TFMM is available." + #CRLF$ + "Go To 'File' -> 'Homepage' To access the project page And access the new version.")
    Case #UpdateCurrent
      MessageRequester("Update", "You already have the newest version of TFMM.")
    Case #UpdateFailed
      MessageRequester("Update", "Failed to retrieve version info from server.")
  EndSelect
EndProcedure

; MENU

Procedure MenuItemHomepage(event)
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      RunProgram("http://goo.gl/utB3xn") ; Download Page TFMM (Train-Fever.net)
    CompilerCase #PB_OS_Linux
      RunProgram("xdg-open", "http://goo.gl/utB3xn", "")
  CompilerEndSelect
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
  OpenPreferences("TFMM.ini")
  SetGadgetText(GadgetPath, ReadPreferenceString("path", TF$))
  SetGadgetState(GadgetSettingsWindowLocation, ReadPreferenceInteger("windowlocation", 0))
  SetGadgetState(GadgetSettingsAutomaticUpdate, ReadPreferenceInteger("update", 1))
  ClosePreferences()
  
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
  Protected Dir$
  Dir$ = GetGadgetText(GadgetPath)
  Dir$ = misc::Path(Dir$)
  
  TF$ = Dir$ ; store in global variable
  OpenPreferences("TFMM.ini")
  WritePreferenceString("path", TF$)
  WritePreferenceInteger("windowlocation", GetGadgetState(GadgetSettingsWindowLocation))
  If Not GetGadgetState(GadgetSettingsWindowLocation)
    RemovePreferenceGroup("window")
  EndIf
  WritePreferenceInteger("update", GetGadgetState(GadgetSettingsAutomaticUpdate))
  ClosePreferences()
  FreeModList()
  LoadModList()
  
  GadgetCloseSettings(event)
EndProcedure

Procedure GadgetButtonActivate(event)
  debugger::Add("GadgetButtonActivate")
  Protected *modinfo.mod, *last.mod
  Protected i, count, result
  
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
      result = MessageRequester("Activate Modification", "Do you want to activate '" + *last\name$ + "'?", #PB_MessageRequester_YesNo)
    Else
      result = MessageRequester("Activate Modifications", "Do you want to activate " + Str(count) + " modifications?", #PB_MessageRequester_YesNo)
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
      result = MessageRequester("Deactivate Modification", "Do you want to deactivate '" + *last\name$ + "'?", #PB_MessageRequester_YesNo)
    Else
      result = MessageRequester("Deactivate Modifications", "Do you want to deactivate " + Str(count) + " modifications?", #PB_MessageRequester_YesNo)
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
  
  For i = 0 To CountGadgetItems(ListInstalled) - 1
    If GetGadgetItemState(ListInstalled, i) & #PB_ListIcon_Selected 
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      *last = *modinfo
      count + 1
    EndIf
  Next i
  If count > 0
    If count = 1
      result = MessageRequester("Uninstall Modification", "Do you want to uninstall '" + *last\name$ + "'?", #PB_MessageRequester_YesNo)
    Else
      result = MessageRequester("Uninstall Modifications", "Do you want to uninstall " + Str(count) + " modifications?", #PB_MessageRequester_YesNo)
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
  File$ = OpenFileRequester("Select new modification to add", "", "File archives|*.zip;*.rar|All files|*.*", 0)
  
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
  If event = #PB_EventType_LeftDoubleClick
    position = GetGadgetState(ListInstalled)
    If position >= 0 And position < CountGadgetItems(ListInstalled)
      *modinfo = ListIcon::GetListItemData(ListInstalled, position)
      If *modinfo\active
        GadgetButtonDeactivate(#PB_EventType_LeftClick)
      Else
        GadgetButtonActivate(#PB_EventType_LeftClick)
      EndIf
    EndIf
    
  EndIf
EndProcedure

Procedure GadgetButtonStartGame(event)
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      RunProgram("steam://run/304730/")
    CompilerCase #PB_OS_Linux
      RunProgram("xdg-open", "steam://run/304730/", "")
  CompilerEndSelect
EndProcedure

Procedure GadgetButtonTrainFeverNet(event)
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      RunProgram("http://goo.gl/8Dsb40") ; Homepage (Train-Fever.net)
    CompilerCase #PB_OS_Linux
      RunProgram("xdg-open", "http://goo.gl/8Dsb40", "")
  CompilerEndSelect
EndProcedure

Procedure GadgetImageMain(event)
  If event = #PB_EventType_LeftClick
    GadgetButtonTrainFeverNet(event)
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
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows 
    Dir$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
    If Not FileSize(Dir$) = -2 ; -2 = directory
      Dir$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
    EndIf
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    Dir$ = misc::Path(GetHomeDirectory() + "/.local/share/Steam/SteamApps/common/Train Fever/")
  CompilerEndIf
  
  If Dir$
    SetGadgetText(GadgetPath, Dir$)  
  EndIf
  
EndProcedure

Procedure GadgetButtonOpenPath(event)
  RunProgram(#DQUOTE$+GetGadgetText(GadgetPath)+#DQUOTE$)
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
; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 425
; FirstLine = 193
; Folding = eAgAA6
; EnableUnicode
; EnableXP