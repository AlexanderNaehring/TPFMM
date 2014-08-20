EnableExplicit

XIncludeFile "WindowMain.pbf"
XIncludeFile "WindowSettings.pbf"
XIncludeFile "WindowModProgress.pbf"
XIncludeFile "registry.pbi"

Global TimerSettingsGadgets = 100, TimerMainGadgets = 101
Global Event
Global TF$

Procedure exit(dummy)
  HideWindow(WindowMain, #True)
  
  End
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
    Dir$ = Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
    If Not FileSize(Dir$) = -2 ; -2 = directory
      Dir$ = Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
    EndIf
  CompilerEndIf
 
  If Dir$
    SetGadgetText(GadgetPath, Dir$)  
  EndIf
  
EndProcedure

Procedure GadgetButtonOpenPath(event)
  RunProgram(#DQUOTE$+GetGadgetText(GadgetPath)+#DQUOTE$)
EndProcedure

Procedure checkTFPath(Dir$)
  If Dir$
    If FileSize(Dir$) = -2
      ; is directory
      If (Not Right(Dir$, 1) = "\") And (Not Right(Dir$, 1) = "/")
        Dir$ = Dir$ + "\"
      EndIf
      ; path ends with a slash
      If FileSize(Dir$ + "TrainFever.exe") > 1
        ; TrainFever.exe is located in this path!
        ; seems to be valid
        
        ; check ifable to write to path
        If CreateFile(0, Dir$ + "TFMM.tmp")
          CloseFile(0)
          DeleteFile(Dir$ + "TFMM.tmp")
          ProcedureReturn #True
        EndIf
        ProcedureReturn -1
      EndIf
    EndIf
  EndIf
  ProcedureReturn #False
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
      SetGadgetText(GadgetRights, "Path is correct and TFMM is able to write to the game directory. Let's get started modding!")
      SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(0,100,0))
      DisableGadget(GadgetSaveSettings, #False)
    Else
      SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, #Red)
      DisableGadget(GadgetSaveSettings, #True)
      If ret = -1
        SetGadgetText(GadgetRights, "TFMM is not able to write to the game directory. Administrative privileges may be required.")
      Else
        SetGadgetText(GadgetRights, "Train Fever cannot be found at this path. Please specify the install path of Train Fever.")
      EndIf
    EndIf
  EndIf
EndProcedure

Procedure TimerMainGadgets()
  Static LastDir$ = ""
  
  If LastDir$ <> TF$
    LastDir$ = TF$
    If checkTFPath(TF$) <> #True 
      MenuItemSettings(0)
    EndIf
  EndIf
  
EndProcedure

Procedure MenuItemSettings(event) ; open settings window
  AddWindowTimer(WindowSettings, TimerSettingsGadgets, 100)
  HideWindow(WindowSettings, #False)
  DisableWindow(WindowMain, #True)
  SetActiveWindow(WindowSettings)
EndProcedure

Procedure GadgetCloseSettings(event) ; close settings window and apply settings
  RemoveWindowTimer(WindowSettings, TimerSettingsGadgets)
  HideWindow(WindowSettings, #True)
  DisableWindow(WindowMain, #False)
  SetActiveWindow(WindowMain)
  
  If checkTFPath(TF$) <> #True
    exit(0)
  EndIf
  
EndProcedure

Procedure GadgetSaveSettings(event)
  Protected Dir$
  Dir$ = GetGadgetText(GadgetPath)
  
  If (Not Right(Dir$, 1) = "\") And (Not Right(Dir$, 1) = "/")
    Dir$ = Dir$ + "\"
  EndIf
  TF$ = Dir$ ; save in global variable
  OpenPreferences("TFMM.ini")
  WritePreferenceString("path", TF$)
  ClosePreferences()
    
  StatusBarText(0, 1, TF$)
  StatusBarText(0, 0, "saved settings")
    
  GadgetCloseSettings(event)
EndProcedure

Procedure MenuItemNewMod(event)
  Protected File$
  File$ = OpenFileRequester("Select new modification to add", "", "File archives|*.zip|All files|*.*", 0)
  
  If File$
    
  EndIf
EndProcedure

Procedure MenuItemUpdate(event)
  RunProgram(#DQUOTE$+"http://www.train-fever.net/"+#DQUOTE$)
EndProcedure



OpenWindowMain()
OpenWindowSettings()
OpenWindowModProgress()
WindowBounds(WindowMain, 640, 300, #PB_Ignore, #PB_Ignore) 
AddWindowTimer(WindowMain, TimerMainGadgets, 100)

OpenPreferences("TFMM.ini")
TF$ = ReadPreferenceString("path", "")
ClosePreferences()
StatusBarText(0, 1, TF$)
SetGadgetText(GadgetPath, TF$)
If TF$ = ""
  ; no path specified upon program start -> open settings
  MenuItemSettings(0)
  GadgetButtonAutodetect(0)
EndIf
StatusBarText(0, 0, "settings loaded")

Repeat
  Event = WaitWindowEvent(100)
  If Event = #PB_Event_Timer
    Select EventTimer()
      Case TimerSettingsGadgets
        TimerSettingsGadgets()
      Case TimerMainGadgets
        TimerMainGadgets()
    EndSelect
  EndIf
  
  Select EventWindow()
    Case WindowMain
      If Not WindowMain_Events(Event)
        exit(0)
      EndIf
    Case WindowSettings
      If Not WindowSettings_Events(Event)
        GadgetCloseSettings(0)
      EndIf
    Case WindowSettings
      If Not WindowModProgress_Events(Event)
        ; progress window closed -> no action, just wait for progress to finish
      EndIf
  EndSelect
ForEver
End
; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 161
; FirstLine = 74
; Folding = I--
; EnableUnicode
; EnableXP