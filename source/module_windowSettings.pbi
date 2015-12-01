DeclareModule windowSettings
  EnableExplicit
  
  Global window
  
  Declare create(parentWindow)
  Declare show()
  Declare events(event)
  
EndDeclareModule

XIncludeFile "module_misc.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_queue.pbi"


Module windowSettings
  
  Global parentW
  Global timerSettings = 100
  Global GadgetPath, GadgetButtonAutodetect, GadgetButtonBrowse, GadgetFrame, GadgetRights, GadgetSettingsInfo, GadgetOpenPath, GadgetSaveSettings, GadgetCancelSettings, GadgetSettingsWindowLocation, GadgetSettingsAutomaticUpdate, GadgetFrame, GadgetFrame, GadgetSettingsLocale
  
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure resize()
    Protected width, height
    width = WindowWidth(window)
    height = WindowHeight(window)
    ResizeGadget(GadgetPath, 20, 70, width - 150, 25)
    ResizeGadget(GadgetButtonAutodetect, width - 120, 30, 100, 30)
    ResizeGadget(GadgetButtonBrowse, width - 120, 70, 100, 25)
  EndProcedure
  
  Procedure GadgetCloseSettings(event) ; close settings window and apply settings
    RemoveWindowTimer(window, timerSettings)
    HideWindow(window, #True)
    DisableWindow(parentW, #False)
    SetActiveWindow(parentW)
    
    If misc::checkTFPath(main::TF$) <> #True
      main::ready = #False
      End
      ; TODO  - call exit routine (not available currently)
      ; exit()
    EndIf
    
  EndProcedure
  
  Procedure GadgetButtonAutodetect(event)
    debugger::add("windowSettings::GadgetButtonAutodetect()")
    Protected path$
    
    CompilerSelect #PB_Compiler_OS
      
      CompilerCase #PB_OS_Windows 
        ; try to get Steam install location
        path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,  "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,  "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
        EndIf
        ; try to get GOG install location
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE, "SOFTWARE\GOG.com\Games\1424258777", "PATH")
        EndIf
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE, "SOFTWARE\Wow6432Node\GOG.com\Games\1424258777", "PATH")
        EndIf
        
      CompilerCase #PB_OS_Linux
        path$ = misc::Path(GetHomeDirectory() + "/.local/share/Steam/SteamApps/common/Train Fever/")
        
      CompilerCase #PB_OS_MacOS
        path$ = misc::Path(GetHomeDirectory() + "/Library/Application Support/Steam/SteamApps/common/Train Fever/")
    CompilerEndSelect
    
    If path$ And FileSize(path$) = -2
      debugger::add("windowSettings::GadgetButtonAutodetect() - found {"+path$+"}")
      SetGadgetText(GadgetPath, path$)
      ProcedureReturn #True
    EndIf
    
    debugger::add("windowSettings::GadgetButtonAutodetect() - did not found any TF installation")
    ProcedureReturn #False
  EndProcedure
  
  Procedure GadgetButtonBrowse(event)
    Protected Dir$
    Dir$ = GetGadgetText(GadgetPath)
    Dir$ = PathRequester("Train Fever installation path", Dir$)
    If Dir$
      SetGadgetText(GadgetPath, Dir$)
    EndIf
  EndProcedure
  
  Procedure GadgetButtonOpenPath(event)
    misc::openLink(GetGadgetText(GadgetPath))
  EndProcedure
  
  Procedure GadgetSaveSettings(event)
    Protected Dir$, locale$, restart.i = #False
    Dir$ = GetGadgetText(GadgetPath)
    Dir$ = misc::Path(Dir$)
    
    main::TF$ = Dir$ ; store in global variable
    
    locale$ = StringField(StringField(GetGadgetText(GadgetSettingsLocale), 1, ">"), 2, "<") ; extract string between < and >
    If locale$ = ""
      locale$ = "en"
    EndIf
    
    
    OpenPreferences("TFMM.ini")
    WritePreferenceString("path", main::TF$)
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
    
    mods::freeAll()
    
    ; load library
    queue::add(queue::#QueueActionLoad)
    ; check for old TFMM configuration, trigger conversion if found
    If FileSize(misc::Path(main::TF$ + "/TFMM/") + "mods.ini") >= 0
      queue::add(queue::#QueueActionConvert)
    EndIf
      
    GadgetCloseSettings(event)
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
      
      ret = misc::checkTFPath(LastDir$)
      If ret = #True
        SetGadgetText(GadgetRights, locale::l("settings","success"))
        SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(0,100,0))
        DisableGadget(GadgetSaveSettings, #False)
      Else
        SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(255,0,0))
        DisableGadget(GadgetSaveSettings, #True)
        If ret = -1
          SetGadgetText(GadgetRights, locale::l("settings","failed"))
        Else
          SetGadgetText(GadgetRights, locale::l("settings","not_found"))
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(parentWindow)
    parentW = parentWindow
    window = OpenWindow(#PB_Any, #PB_Ignore, #PB_Ignore, 580, 240, locale::l("settings","title"), #PB_Window_SystemMenu | #PB_Window_Invisible | #PB_Window_WindowCentered, WindowID(parentWindow))
    GadgetPath = StringGadget(#PB_Any, 20, 70, 430, 25, "[Train Fever Path]")
    GadgetButtonAutodetect = ButtonGadget(#PB_Any, 460, 30, 100, 30, locale::l("settings","autodetect"))
    GadgetToolTip(GadgetButtonAutodetect, locale::l("settings","autodetect_tip"))
    GadgetButtonBrowse = ButtonGadget(#PB_Any, 460, 70, 100, 25, locale::l("settings","browse"))
    GadgetToolTip(GadgetButtonBrowse, locale::l("settings","browse_tip"))
    GadgetFrame = FrameGadget(#PB_Any, 10, 10, 560, 135, locale::l("settings","path"))
    GadgetRights = TextGadget(#PB_Any, 20, 105, 430, 30, "")
    GadgetSettingsInfo = TextGadget(#PB_Any, 20, 30, 430, 35, locale::l("settings","text"))
    GadgetOpenPath = ButtonGadget(#PB_Any, 460, 105, 100, 30, locale::l("settings","open"))
    GadgetToolTip(GadgetOpenPath, locale::l("settings","open_tip"))
    GadgetSaveSettings = ButtonGadget(#PB_Any, 450, 210, 120, 25, locale::l("settings","save"))
    GadgetToolTip(GadgetSaveSettings, locale::l("settings","save_tip"))
    GadgetCancelSettings = ButtonGadget(#PB_Any, 320, 210, 120, 25, locale::l("settings","cancel"))
    GadgetToolTip(GadgetCancelSettings, locale::l("settings","cancel_tip"))
    GadgetSettingsWindowLocation = CheckBoxGadget(#PB_Any, 20, 170, 280, 25, locale::l("settings","restore"))
    GadgetToolTip(GadgetSettingsWindowLocation, locale::l("settings","restore_tip"))
    GadgetSettingsAutomaticUpdate = CheckBoxGadget(#PB_Any, 20, 200, 280, 25, locale::l("settings","update"))
    GadgetToolTip(GadgetSettingsAutomaticUpdate, locale::l("settings","update_tip"))
    GadgetFrame = FrameGadget(#PB_Any, 10, 150, 300, 80, locale::l("settings","other"))
    GadgetFrame = FrameGadget(#PB_Any, 320, 150, 250, 50, locale::l("settings","locale"))
    GadgetSettingsLocale = ComboBoxGadget(#PB_Any, 330, 170, 230, 25, #PB_ComboBox_Image)
  EndProcedure
  
  Procedure show()
    Protected locale$
    
    OpenPreferences("TFMM.ini")
    SetGadgetText(GadgetPath, ReadPreferenceString("path", main::TF$))
    SetGadgetState(GadgetSettingsWindowLocation, ReadPreferenceInteger("windowlocation", 0))
    SetGadgetState(GadgetSettingsAutomaticUpdate, ReadPreferenceInteger("update", 1))
    locale$ = ReadPreferenceString("locale", "en")
    ClosePreferences()
    
    If GetGadgetText(GadgetPath) = ""
      GadgetButtonAutodetect(0)
    EndIf
    
    Protected NewMap locale$(), count.i = 0
    locale::listAvailable(GadgetSettingsLocale, locale$)
    
    AddWindowTimer(window, timerSettings, 100)
    HideWindow(window, #False, #PB_Window_WindowCentered)
    DisableWindow(parentW, #True)
    SetActiveWindow(window)
  EndProcedure
  
  Procedure events(event)
    Select event
      Case #PB_Event_SizeWindow
        resize()
      Case #PB_Event_CloseWindow
        GadgetCloseSettings(0)
  
      Case #PB_Event_Menu
        Select EventMenu()
        EndSelect
        
      Case #PB_Event_Timer
        Select EventTimer()
          Case timerSettings
            TimerSettingsGadgets()
        EndSelect
        
      Case #PB_Event_Gadget
        Select EventGadget()
          Case GadgetButtonAutodetect
            GadgetButtonAutodetect(EventType())
          Case GadgetButtonBrowse
            GadgetButtonBrowse(EventType())
          Case GadgetOpenPath
            GadgetButtonOpenPath(EventType())
          Case GadgetSaveSettings
            GadgetSaveSettings(EventType())
          Case GadgetCancelSettings
            GadgetCloseSettings(EventType())
        EndSelect
    EndSelect
    ProcedureReturn #True
  EndProcedure
  
EndModule
