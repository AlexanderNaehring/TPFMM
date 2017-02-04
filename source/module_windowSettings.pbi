DeclareModule windowSettings
  EnableExplicit
  
  Global window
  
  Declare create(parentWindow)
  Declare show()
  
EndDeclareModule

XIncludeFile "module_misc.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_queue.pbi"


Module windowSettings
  
  Global parentW
  Global timerSettings = 100
  Global GadgetPath, GadgetButtonAutodetect, GadgetButtonBrowse, GadgetFrame, GadgetRights, GadgetSettingsInfo, GadgetOpenPath, GadgetSaveSettings, GadgetCancelSettings, GadgetSettingsWindowLocation, GadgetSettingsAutomaticBackup, GadgetFrame, GadgetFrame, GadgetSettingsLocale
  
  
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
  
  Procedure GadgetCloseSettings() ; close settings window and apply settings
    RemoveWindowTimer(window, timerSettings)
    HideWindow(window, #True)
    DisableWindow(parentW, #False)
    SetActiveWindow(parentW)
    
    If misc::checkGameDirectory(main::gameDirectory$) <> 0
      main::ready = #False
      End
      ; TODO  - call exit routine (not available currently)
      ; exit()
    EndIf
    
  EndProcedure
  
  Procedure GadgetButtonAutodetect()
    debugger::add("windowSettings::GadgetButtonAutodetect()")
    Protected path$
    
    CompilerSelect #PB_Compiler_OS
      
      CompilerCase #PB_OS_Windows 
        ; try to get Steam install location                         SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800
        path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,  "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800", "InstallLocation")
        Debug "registry: "+path$
        Debug ""
        Debug ""
        Debug ""
        Debug "filesize("+path$+") = "+FileSize(path$)
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,  "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800", "InstallLocation")
        EndIf
        ; try to get GOG install location
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE, "SOFTWARE\GOG.com\Games\1720767912", "PATH")
        EndIf
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE, "SOFTWARE\WOW6432Node\GOG.com\Games\1720767912", "PATH")
        EndIf
        
      CompilerCase #PB_OS_Linux
        path$ = misc::Path(GetHomeDirectory() + "/.local/share/Steam/SteamApps/common/Transport Fever/")
        
      CompilerCase #PB_OS_MacOS
        path$ = misc::Path(GetHomeDirectory() + "/Library/Application Support/Steam/SteamApps/common/Transport Fever/")
    CompilerEndSelect
    
    If path$ And FileSize(path$) = -2
      debugger::add("windowSettings::GadgetButtonAutodetect() - found {"+path$+"}")
      SetGadgetText(GadgetPath, path$)
      ProcedureReturn #True
    EndIf
    
    debugger::add("windowSettings::GadgetButtonAutodetect() - did not found any TF installation")
    ProcedureReturn #False
  EndProcedure
  
  Procedure GadgetButtonBrowse()
    Protected Dir$
    Dir$ = GetGadgetText(GadgetPath)
    Dir$ = PathRequester("Transport Fever Installation Path", Dir$)
    If Dir$
      SetGadgetText(GadgetPath, Dir$)
    EndIf
  EndProcedure
  
  Procedure GadgetButtonOpenPath()
    misc::openLink(GetGadgetText(GadgetPath))
  EndProcedure
  
  Procedure GadgetSaveSettings()
    Protected Dir$, locale$, restart.i = #False
    Dir$ = GetGadgetText(GadgetPath)
    Dir$ = misc::Path(Dir$)
    
    If misc::checkGameDirectory(Dir$) = 0
      ; 0   = path okay, executable found and writing possible
      ; 1   = path okay, executable found but cannot write
      ; 2   = path not okay
      
      main::gameDirectory$ = Dir$ ; store in global variable
    EndIf
    
    
    locale$ = StringField(StringField(GetGadgetText(GadgetSettingsLocale), 1, ">"), 2, "<") ; extract string between < and >
    If locale$ = ""
      locale$ = "en"
    EndIf
    
    
    OpenPreferences(main::settingsFile$)
    WritePreferenceString("path", main::gameDirectory$)
    WritePreferenceInteger("windowlocation", GetGadgetState(GadgetSettingsWindowLocation))
    If Not GetGadgetState(GadgetSettingsWindowLocation)
      RemovePreferenceGroup("window")
    EndIf
    WritePreferenceInteger("autobackup", GetGadgetState(GadgetSettingsAutomaticBackup))
    If locale$ <> ReadPreferenceString("locale", "en")
      restart = #True
    EndIf
    WritePreferenceString("locale", locale$)
    ClosePreferences()
    
    If restart
      MessageRequester("Restart TPFMM", "TPFMM will now restart to display the selected locale")
      RunProgram(ProgramFilename())
      End
    EndIf
    
    mods::freeAll()
    
    ; load library
    queue::add(queue::#QueueActionLoad)
      
    GadgetCloseSettings()
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
      
      ret = misc::checkGameDirectory(LastDir$)
      ; 0   = path okay, executable found and writing possible
      ; 1   = path okay, executable found but cannot write
      ; 2   = path not okay
      If ret = 0
        SetGadgetText(GadgetRights, locale::l("settings","success"))
        SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(0,100,0))
        DisableGadget(GadgetSaveSettings, #False)
      Else
        SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(255,0,0))
        DisableGadget(GadgetSaveSettings, #True)
        If ret = 1
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
    GadgetSettingsAutomaticBackup = CheckBoxGadget(#PB_Any, 20, 200, 280, 25, locale::l("settings","backup"))
    GadgetToolTip(GadgetSettingsAutomaticBackup, locale::l("settings","backup_tip"))
    
    GadgetFrame = FrameGadget(#PB_Any, 10, 150, 300, 80, locale::l("settings","other"))
    GadgetFrame = FrameGadget(#PB_Any, 320, 150, 250, 50, locale::l("settings","locale"))
    GadgetSettingsLocale = ComboBoxGadget(#PB_Any, 330, 170, 230, 25, #PB_ComboBox_Image)
    
    BindGadgetEvent(GadgetButtonAutodetect, @GadgetButtonAutodetect())
    BindGadgetEvent(GadgetButtonBrowse, @GadgetButtonBrowse())
    BindGadgetEvent(GadgetOpenPath, @GadgetButtonOpenPath())
    BindGadgetEvent(GadgetSaveSettings, @GadgetSaveSettings())
    BindGadgetEvent(GadgetCancelSettings, @GadgetCloseSettings())
    
    BindEvent(#PB_Event_Timer, @TimerSettingsGadgets(), window)
    BindEvent(#PB_Event_CloseWindow, @GadgetCloseSettings(), window)
    BindEvent(#PB_Event_SizeWindow, @resize(), window)
    
  EndProcedure
  
  Procedure show()
    Protected locale$
    
    OpenPreferences(main::settingsFile$)
    SetGadgetText(GadgetPath, ReadPreferenceString("path", main::gameDirectory$))
    SetGadgetState(GadgetSettingsWindowLocation, ReadPreferenceInteger("windowlocation", 0))
    SetGadgetState(GadgetSettingsAutomaticBackup, ReadPreferenceInteger("autobackup", 1))
    locale$ = ReadPreferenceString("locale", "en")
    ClosePreferences()
    
    If GetGadgetText(GadgetPath) = ""
      GadgetButtonAutodetect()
    EndIf
    
    Protected NewMap locale$(), count.i = 0
    locale::listAvailable(GadgetSettingsLocale, locale$)
    
    AddWindowTimer(window, timerSettings, 100)
    HideWindow(window, #False, #PB_Window_WindowCentered)
    DisableWindow(parentW, #True)
    SetActiveWindow(window)
  EndProcedure
  
EndModule
